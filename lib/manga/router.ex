defmodule Manga.Router do
  @moduledoc """
  Mounts the full (paged + strip) reader — the same route surface as
  `Manhwa.Router.manhwa_reader/2`, dispatched through
  `Manga.ReaderController` so each series renders in its saved reading
  mode (paged/double-page via fresco, scroll via the manhwa strip).

      import Manga.Router

      scope "/" do
        pipe_through [:browser, :require_auth]
        manga_reader "/reader/manga"
      end

  Accepts the same options as `manhwa_reader/2` (`:series_segments`).
  """

  defmacro manga_reader(path, opts \\ []) do
    opts = Keyword.put(opts, :controller, Manga.ReaderController)

    quote do
      require Manhwa.Router
      Manhwa.Router.manhwa_reader(unquote(path), unquote(opts))
    end
  end
end
