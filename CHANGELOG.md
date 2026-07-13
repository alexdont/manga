# Changelog

## 0.1.0 (2026-07-13)

Initial extraction from the Greenoak reader:

* `Manga.Router.manga_reader/2` — the full manhwa route surface with
  paged-mode dispatch: paged/double-page series render the fresco
  canvas reader, scroll series render the manhwa strip reader.
* Paged engine: all-pages-on-one-canvas layout with image-window
  loading, double-page spread pairing with wide-page detection,
  per-page overrides (insert blank / force solo), RTL/LTR, rotation,
  smart crop, skip-blank, tap-zone presets, in-place chapter swap via
  the images API, cursor-hide gesture mode.
