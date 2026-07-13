defmodule Manga.ReaderHTML do
  @moduledoc """
  View module for the paged reader page, plus the canvas/spread
  helpers the paged engine is built on.
  """

  use Phoenix.Component

  import Manhwa.ReaderHTML,
    only: [url_join: 2, series_slug: 1, clean_image_url: 1, proxied_url: 2]

  embed_templates "reader_html/*"

  @doc """
  Returns the canonical list of "spread start" page numbers for a
  chapter in double-page mode. Page 1 is always its own start (solo
  first spread). Subsequent pages pair up unless one of the pair is
  wide (>1.2 aspect) or user-marked solo, in which case that page goes
  solo and pairing resumes after it.
  """
  def fresco_spread_starts(images, solo_set \\ %MapSet{}) do
    total = length(images)

    if total == 0 do
      []
    else
      do_spread_starts(2, total, images, solo_set, [1])
    end
  end

  defp do_spread_starts(n, total, _images, _solo_set, acc) when n > total,
    do: Enum.reverse(acc)

  defp do_spread_starts(n, total, images, solo_set, acc) do
    step =
      cond do
        wide_page?(images, n) -> 1
        MapSet.member?(solo_set, n) -> 1
        n + 1 > total -> 1
        wide_page?(images, n + 1) -> 1
        MapSet.member?(solo_set, n + 1) -> 1
        true -> 2
      end

    do_spread_starts(n + step, total, images, solo_set, [n | acc])
  end

  @doc """
  True when the page at index `n` (1-based) is wider than it is tall
  (likely a glued-together spread that should be shown solo).
  """
  def wide_page?(images, n) do
    case Enum.at(images, n - 1) do
      %{width: w, height: h} when is_number(w) and is_number(h) and h > 0 -> w > h * 1.2
      _ -> false
    end
  end

  @doc """
  Fold a user's chapter page overrides into the natural image list.

  Returns `{new_images, solo_set, inserted_set}`:

    * `new_images` — image list with synthetic blanks spliced before
      each `insert_blank_before.page_index` (in natural coords). Each
      synthetic image carries `synthetic: true`.
    * `solo_set` — 1-based indices (in the new list) displayed alone in
      double-page mode (`kind = "solo"`).
    * `inserted_set` — 1-based indices (in the new list) of the
      synthetic blanks themselves, handed to the client for styling.

  Overrides with `page_index` outside `[1, length(images)]` are
  silently ignored — forgiving when a chapter's page count changes
  upstream.
  """
  def apply_overrides(images, overrides) when is_list(images) and is_list(overrides) do
    inserts =
      overrides
      |> Enum.filter(&(&1.kind == "insert_blank_before"))
      |> Enum.map(& &1.page_index)
      |> MapSet.new()

    solos_natural =
      overrides
      |> Enum.filter(&(&1.kind == "solo"))
      |> Enum.map(& &1.page_index)
      |> MapSet.new()

    total = length(images)

    {rev_new, solo_set, inserted_set, _final_offset} =
      Enum.reduce(1..total//1, {[], MapSet.new(), MapSet.new(), 0}, fn p,
                                                                       {acc, ss, ins, offset} ->
        img = Enum.at(images, p - 1)

        {acc, offset, ins} =
          if MapSet.member?(inserts, p) do
            new_pos_of_blank = p + offset
            {[blank_image_for(img) | acc], offset + 1, MapSet.put(ins, new_pos_of_blank)}
          else
            {acc, offset, ins}
          end

        new_pos_of_p = p + offset
        acc = [img | acc]

        ss =
          if MapSet.member?(solos_natural, p),
            do: MapSet.put(ss, new_pos_of_p),
            else: ss

        {acc, ss, ins, offset}
      end)

    {Enum.reverse(rev_new), solo_set, inserted_set}
  end

  # Synthetic blank matched to the neighbour's dimensions so the
  # canvas-height normalization keeps the spread at a uniform height.
  defp blank_image_for(neighbor) do
    w = (neighbor && Map.get(neighbor, :width)) || 1000
    h = (neighbor && Map.get(neighbor, :height)) || 1500

    svg =
      "<svg xmlns='http://www.w3.org/2000/svg' width='#{w}' height='#{h}'>" <>
        "<rect width='100%' height='100%' fill='white'/></svg>"

    %{
      url: "data:image/svg+xml;utf8," <> URI.encode(svg),
      width: w,
      height: h,
      synthetic: true
    }
  end

  # Synthetic blanks already carry a data: URL; only real fetched
  # images go through the proxy.
  defp image_src(%{synthetic: true, url: url}, _proxy_url), do: url
  defp image_src(img, proxy_url), do: proxied_url(img.url, proxy_url)

  @doc """
  Public delegate so the images API can build a JSON payload using the
  SAME proxied URL the server-rendered canvas placed in `data-src` —
  keeping the client's `applyImageWindow` swap-back a no-op identity
  match instead of a cross-origin re-fetch.
  """
  def proxied_image_src(img, proxy_url), do: image_src(img, proxy_url)

  @doc """
  JSON-encodes the chapter's image list for client-side use:
  `[{url, width, height}, ...]` with proxied URLs. JS uses this to
  build fresco sources for any page without re-hitting the server.
  """
  def fresco_images_json(images, proxy_url) do
    Jason.encode!(
      Enum.map(images, fn img ->
        base = %{url: image_src(img, proxy_url), width: img.width, height: img.height}
        if Map.get(img, :synthetic), do: Map.put(base, :synthetic, true), else: base
      end)
    )
  end

  # Image-loading window radius — units differ per mode:
  #   * Single-page: in *pages* — load current ± @window_pages.
  #   * Double-page: in *spreads* — load current spread ± @window_spreads.
  # Out-of-window pages render with an empty SVG data: URL so the
  # browser doesn't fetch them; the client's applyImageWindow performs
  # the same swap on every navigation.
  @window_pages 2
  @window_spreads 2

  @doc """
  Build a `%Fresco.Canvas{}` containing **every page** of the chapter
  laid out side-by-side on a virtual canvas, so the paged reader
  navigates purely by retargeting fresco's pan/zoom
  (`handle.fitImage("page-N")`) — no reload, no DOM mutation.

  Pages are ordered along X by reading direction (RTL: page 1
  rightmost). Each image carries `id = "page-N"`. Single vs double
  page is a *fit decision*, not a layout one. Existing annotations are
  stashed under the canvas `"etcher"` extension for hydration.
  """
  def fresco_canvas(
        images,
        direction,
        etcher_annotations,
        current_page,
        double_page,
        spread_starts,
        proxy_url
      ) do
    total = length(images)
    max_h = images |> Enum.map(&page_height/1) |> Enum.max(fn -> 1500 end)

    in_window = compute_in_window(total, current_page, double_page, spread_starts)

    ordered =
      if direction == "ltr" do
        images |> Enum.with_index(1)
      else
        images |> Enum.with_index(1) |> Enum.reverse()
      end

    total_w = images |> Enum.map(&page_width/1) |> Enum.sum()

    canvas = Fresco.Canvas.new(width: total_w, height: max_h, background: "#ffffff")

    {canvas, _x} =
      Enum.reduce(ordered, {canvas, 0}, fn {img, n}, {c, x} ->
        w = page_width(img)
        h = page_height(img)

        # natural_width/height make fresco emit explicit dims at
        # server-render time — without them `fitBounds` on mount bails
        # (imageBoundsFor returns height 0 until image load).
        src =
          if MapSet.member?(in_window, n),
            do: image_src(img, proxy_url),
            else: placeholder_src()

        c2 =
          Fresco.Canvas.add_image(c, %{
            id: "page-#{n}",
            src: src,
            x: x,
            y: div(max_h - h, 2),
            width: w,
            natural_width: w,
            natural_height: h
          })

        {c2, x + w}
      end)

    Fresco.Canvas.put_extension(canvas, "etcher", %{
      "version" => "1",
      "annotations" => etcher_annotations
    })
  end

  # Single-page mode → page-radius window centred on `current_page`.
  defp compute_in_window(total, current_page, false, _spread_starts) do
    lo = max(1, current_page - @window_pages)
    hi = min(total, current_page + @window_pages)
    MapSet.new(lo..hi)
  end

  # Double-page mode, no spread data — page-radius scaled for spreads.
  defp compute_in_window(total, current_page, true, []) do
    lo = max(1, current_page - 2 * @window_spreads)
    hi = min(total, current_page + 2 * @window_spreads + 1)
    MapSet.new(lo..hi)
  end

  defp compute_in_window(total, current_page, true, spread_starts) do
    current_anchor = spread_anchor_for_starts(spread_starts, current_page)
    idx = Enum.find_index(spread_starts, &(&1 == current_anchor)) || 0

    start_idx = max(0, idx - @window_spreads)
    end_idx = min(length(spread_starts) - 1, idx + @window_spreads)

    start_page = Enum.at(spread_starts, start_idx)

    end_page =
      case Enum.at(spread_starts, end_idx + 1) do
        nil -> total
        next_anchor -> next_anchor - 1
      end

    MapSet.new(start_page..end_page)
  end

  defp spread_anchor_for_starts([], _page), do: 1

  defp spread_anchor_for_starts(starts, page) do
    Enum.reduce_while(starts, hd(starts), fn s, acc ->
      if s <= page, do: {:cont, s}, else: {:halt, acc}
    end)
  end

  # Empty-SVG data URL — the browser keeps the img element at its
  # CSS-driven dimensions but doesn't issue any network request.
  defp placeholder_src do
    "data:image/svg+xml;utf8,%3Csvg%20xmlns='http://www.w3.org/2000/svg'%2F%3E"
  end

  defp page_width(%{width: w}) when is_number(w) and w > 0, do: trunc(w)
  defp page_width(_), do: 1000

  defp page_height(%{height: h}) when is_number(h) and h > 0, do: trunc(h)
  defp page_height(_), do: 1500

  @doc """
  URL for the same chapter+page with overridden flags — used by the
  settings toggles (direction, double-page) that require a server-side
  re-render (the canvas's page-X layout differs by direction).
  """
  def paged_self_url(assigns, overrides) do
    double = Map.get(overrides, :double, assigns.double_page)
    dir = Map.get(overrides, :dir, assigns.direction)

    qs =
      [{"page", Integer.to_string(assigns.page)}]
      |> then(fn list -> if double, do: [{"double", "1"} | list], else: list end)
      |> then(fn list -> if dir == "ltr", do: [{"dir", "ltr"} | list], else: list end)

    base = url_join(assigns.series_base, assigns.chapter)
    if qs == [], do: base, else: base <> "?" <> URI.encode_query(qs)
  end

  @doc "daisyUI button class string for active/inactive switcher buttons."
  def paged_btn_class(true),
    do: "btn btn-sm btn-outline btn-active no-animation pointer-events-none"

  def paged_btn_class(false), do: "btn btn-sm btn-outline"
end
