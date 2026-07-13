defmodule Manga.ReaderController do
  @moduledoc """
  Reader controller for the combined paged + strip surface. `show/2`
  dispatches by the series' saved reading mode (per device): paged /
  double-page renders the fresco canvas reader here; scroll delegates
  to `Manhwa.ReaderController.strip/2`. Everything else on the route
  surface is shared and delegates to the `manhwa` core.
  """

  use Phoenix.Controller, formats: [:html, :json]

  import Plug.Conn

  alias Manhwa.{Config, ReaderState}
  alias Manhwa.ReaderController, as: Shared

  # ── Dispatch ─────────────────────────────────────────────────────

  def show(conn, params) do
    Shared.with_series(conn, params, fn series, user ->
      state = user && Config.store().reader_state(user, series)
      device = ReaderState.device_kind(conn, params)
      mode = ReaderState.effective_reading_mode(state, device) || "paged"

      if mode == "scroll" do
        # strip/2 re-validates and applies its own from_max snap.
        Shared.strip(conn, params)
      else
        if user && params["from_max"] == "1" do
          Shared.optional_store(:snap_to_chapter, [user, series, params["chapter"]])
        end

        render_paged(conn, params, series, user, state, device)
      end
    end)
  end

  # ── Paged reader page ────────────────────────────────────────────

  defp render_paged(conn, params, series, user, state, device) do
    store = Config.store()
    chapter = params["chapter"]

    chapters = store.list_chapters(user, series)
    idx = Enum.find_index(chapters, &(&1 == chapter))
    prev_chapter = if idx && idx > 0, do: Enum.at(chapters, idx - 1)
    next_chapter = if idx, do: Enum.at(chapters, idx + 1)

    case store.fetch_pages(user, series, chapter, dims: :precise) do
      {:ok, images} ->
        # User-applied chapter page overrides — splice synthetic blanks
        # before flagged natural indices, accumulate solo indices in
        # post-insert coordinates. Anonymous users get the natural list.
        overrides =
          if user,
            do: Shared.optional_store(:list_page_overrides, [user, series, chapter], []),
            else: []

        {images, solo_set, inserted_set} = Manga.ReaderHTML.apply_overrides(images, overrides)

        title = ReaderState.get(state, :title) || List.last(series)
        total = length(images)

        page =
          case Integer.parse(params["page"] || "") do
            {n, ""} when n >= 1 and n <= total ->
              n

            _ ->
              if state && ReaderState.get(state, :last_chapter) == chapter &&
                   ReaderState.get(state, :last_page) do
                ReaderState.get(state, :last_page) |> max(1) |> min(total)
              else
                1
              end
          end

        # `?double=` / `?dir=` URL overrides win over saved prefs so the
        # user can flip per-session without touching them.
        double? =
          cond do
            params["double"] in ["1", "true"] -> true
            params["double"] in ["0", "false"] -> false
            true -> ReaderState.effective_reading_mode(state, device) == "double_page"
          end

        direction =
          cond do
            params["dir"] == "ltr" -> "ltr"
            params["dir"] == "rtl" -> "rtl"
            state && ReaderState.get(state, :reading_direction) -> ReaderState.get(state, :reading_direction)
            true -> "rtl"
          end

        spread_starts =
          if double?, do: Manga.ReaderHTML.fresco_spread_starts(images, solo_set), else: []

        urls = Shared.url_assigns(conn, series, chapter)

        conn
        |> put_view(html: Manga.ReaderHTML)
        |> render(
          :paged,
          [
            series: series,
            chapter: chapter,
            images: images,
            total_pages: total,
            page: page,
            double_page: double?,
            direction: direction,
            spread_starts: spread_starts,
            solo_pages: MapSet.to_list(solo_set),
            inserted_pages: MapSet.to_list(inserted_set),
            chapters: chapters,
            prev_chapter: prev_chapter,
            next_chapter: next_chapter,
            manga_title: title,
            current_user: user,
            etcher_annotations: Shared.list_shapes(user, series, chapter),
            reading_rotation: ReaderState.get(state, :reading_rotation) || 0,
            # `?ann=` means the user landed here from a comment deep-link —
            # JS gates progress saves until they prove they're rereading.
            transient_mode: params["ann"] != nil,
            page_title: "#{title} — Ch. #{chapter} (p.#{page})"
          ] ++ urls ++ Shared.etcher_assigns(conn, user, series, chapter, "fresco-reader")
        )

      {:error, reason} ->
        conn
        |> put_flash(:error, "Failed to load chapter: #{inspect(reason)}")
        |> redirect(to: Config.series_url(series))
    end
  end

  # ── Chapter images API — shared payload + the paged canvas layout ─

  def chapter_images(conn, params) do
    Shared.with_series(conn, params, fn series, user ->
      case Shared.chapter_images_data(user, series, params["chapter"], dims: :precise) do
        {:ok, data} ->
          direction =
            case conn.query_params["direction"] do
              d when d in ["rtl", "ltr"] -> d
              _ -> "rtl"
            end

          double_page = conn.query_params["double_page"] in ["true", "1"]

          # Base recovered from .../api/:series.../:chapter/images —
          # `api` + series segments + chapter + `images` trailing parts.
          base = Shared.reader_base(conn, Shared.seg_count(conn) + 3)
          proxy_url = "#{base}/proxy/image"

          paged_canvas =
            Manga.ReaderHTML.fresco_canvas(
              data.images,
              direction,
              data.etcher_shapes,
              1,
              double_page,
              [],
              proxy_url
            )

          # Fresco's `setSources` reads `width`/`height` per source, but
          # `Fresco.Canvas` images carry `width` + `natural_width` +
          # `natural_height` — fold `natural_height` into `height` so the
          # swap path lines up with what fresco expects.
          sources =
            Enum.map(paged_canvas.images, fn img ->
              Map.put(img, :height, img[:natural_height] || img[:height] || 0)
            end)

          # Pre-proxied URLs so the paged swap's applyImageWindow
          # "real src" swap-back is a no-op identity match. (Strip mode
          # consumes the RAW `images` list and proxies client-side.)
          paged_window_images =
            Enum.map(data.images, fn img ->
              base_img = %{
                url: Manga.ReaderHTML.proxied_image_src(img, proxy_url),
                width: img.width,
                height: img.height
              }

              if Map.get(img, :synthetic), do: Map.put(base_img, :synthetic, true), else: base_img
            end)

          json(
            conn,
            Map.merge(data, %{
              paged_window_images: paged_window_images,
              sources: sources,
              canvas_width: paged_canvas.canvas.width,
              canvas_height: paged_canvas.canvas.height
            })
          )

        {:error, _reason} ->
          conn |> put_status(404) |> json(%{error: "Chapter not found"})
      end
    end)
  end

  # ── Shared surface — delegates to the manhwa core ────────────────

  defdelegate strip(conn, params), to: Shared
  defdelegate update_reading_mode(conn, params), to: Shared
  defdelegate update_reading_direction(conn, params), to: Shared
  defdelegate update_comments_visible(conn, params), to: Shared
  defdelegate update_reading_rotation(conn, params), to: Shared
  defdelegate update_smart_crop(conn, params), to: Shared
  defdelegate update_tap_zone_preset(conn, params), to: Shared
  defdelegate update_progress(conn, params), to: Shared
  defdelegate toggle_page_override(conn, params), to: Shared
  defdelegate proxy_image(conn, params), to: Shared
  defdelegate debug_log(conn, params), to: Shared
  defdelegate gif_search(conn, params), to: Shared
  defdelegate gif_trending(conn, params), to: Shared
  defdelegate list_marks(conn, params), to: Shared
  defdelegate create_mark_annotation(conn, params), to: Shared
  defdelegate attach_etcher_comment(conn, params), to: Shared
  defdelegate delete_mark(conn, params), to: Shared
end
