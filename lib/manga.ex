defmodule Manga do
  @moduledoc """
  Batteries-included paged comic reader for Phoenix — manga-style
  page/spread reading on top of
  [`fresco`](https://hex.pm/packages/fresco)'s pan-zoom canvas.

  Ships the full paged experience: double-page spreads with wide-page
  detection, RTL/LTR reading direction, rotation, smart crop, tap-zone
  presets, per-page overrides (insert blank / force solo), in-place
  chapter swaps, progress persistence, and an optional annotation
  layer. Builds on [`manhwa`](https://hex.pm/packages/manhwa) for the
  shared reader core — so installing `manga` gives you both reading
  modes with a per-series (and per-device) mode switch: paged series
  render here, scroll series render the `manhwa` strip reader, on the
  same URL.

  ## Wiring

  Identical to `manhwa` (one `Manhwa.Store`, same config keys — see
  the `Manhwa` module docs); just mount the `manga` macro instead:

      import Manga.Router

      scope "/" do
        pipe_through [:browser, :require_auth]
        manga_reader "/reader/manga"
      end

  and add both packages to your Tailwind sources:

      @source "../../deps/manhwa";
      @source "../../deps/manga";
  """
end
