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

**Reading vertical-scroll comics?** That's the sibling package —
[`manhwa`](https://hex.pm/packages/manhwa) — a long-strip reader for
webtoons/manhwa/manhua with panel snap, auto-reader, and infinite
chapter scrolling.

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

`manga` is built on the `manhwa` core, so the plumbing is the same
contract: one `Manhwa.Store` implementation and the same `config :manhwa`
keys (see the [manhwa docs](https://hexdocs.pm/manhwa)). Mount the `manga`
macro:

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

The reader never fetches content itself — your store supplies page URLs,
ideally **with dimensions** (the paged reader's double-page spread
pairing needs exact per-page sizes). If your source only yields URLs,
[`dims`](https://hex.pm/packages/dims) probes width × height from a
~128 KB Range fetch — `Dims.probe_all/2` for the paged `:precise` hint,
`Dims.probe_sampled/2` for strip-length lists.

One behavior worth knowing: since the core tracks a per-series (and
per-device) reading mode, a series whose saved mode is `"scroll"` renders
through the strip reader on the same route — so mixed libraries read
correctly without extra wiring.

## License

MIT
