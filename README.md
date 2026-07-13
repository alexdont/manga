# Manga

Batteries-included **paged comic reader** for Phoenix — manga-style
page/spread reading on top of [fresco](https://hex.pm/packages/fresco)'s
pan-zoom canvas.

Every page of a chapter is laid out on one virtual canvas (RTL or LTR), so
page navigation is a pan/zoom retarget — no reloads, no DOM churn. Ships
double-page spreads with wide-page detection, per-page overrides (insert
blank / force solo), reading direction, rotation, smart crop, tap-zone
presets, skip-blank, in-place chapter swaps, progress persistence, an image
proxy, and an optional annotation layer via
[etcher](https://hex.pm/packages/etcher).

Builds on [`manhwa`](https://hex.pm/packages/manhwa) for the shared reader
core and long-strip mode — **installing `manga` gives you both reading
modes** with a per-series (and per-device) mode switch on the same URL:
paged series render here, scroll series render the manhwa strip reader.

---

## Install

```elixir
def deps do
  [
    {:manga, "~> 0.1"}
  ]
end
```

## Wire it up

Identical to [`manhwa`](https://hexdocs.pm/manhwa) — one `Manhwa.Store`
implementation and the same `config :manhwa` keys serve both modes. Just
mount the `manga` macro instead:

```elixir
# router.ex
import Manga.Router

scope "/" do
  pipe_through [:browser, :require_auth]
  manga_reader "/reader/manga"           # → /reader/manga/:source/:slug/:chapter
end
```

JS — import both viewers' hooks in `assets/js/app.js`:

```js
import "../../deps/fresco/priv/static/fresco.js"
import "../../deps/fresco_strip/priv/static/fresco_strip.js"
```

CSS — add both packages to your Tailwind v4 sources (daisyUI v5 required):

```css
@source "../../deps/manhwa";
@source "../../deps/manga";
```

See the [manhwa README](https://hexdocs.pm/manhwa) for the Store contract
and the optional adapters (annotations, GIF picker, etcher host).

## License

MIT
