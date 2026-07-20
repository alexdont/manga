# Changelog

## 0.1.4 (2026-07-17)

* Read checkmark in the progress pill: once the host confirms a
  chapter counts as read, the bottom-center indicator shows a green ✓
  over the chapter's last 5% of pages — and latches for that chapter,
  so paging back keeps showing it was read to completion. Confirmed
  via manhwa 0.1.9's `save_progress` →
  `{:ok, %{chapter_read: boolean}}` contract — hence the bumped
  `{:manhwa, "~> 0.1.9"}` requirement. Stores that keep returning
  `:ok` see no change; a `false` verdict clears a stale mark (rereads
  restart their time bar). Shares manhwa's config:
  `read_check_percent` (display gate, default 95) and
  `read_check_mark` (default "✓").

## 0.1.3 (2026-07-15)

* Reading-time fix: the in-place chapter swap now flushes accumulated
  reading time against the *outgoing* chapter before rolling its
  closure state forward — previously a quickly-read chapter's whole
  time could be attributed to the next chapter at page 1, so short
  chapters never crossed the host app's chapter-counting bar.
* The currently-focused page's dwell (which only lands on `view-blur`)
  is now captured directly on every boundary flush — chapter swap,
  `beforeunload`, tab-hide — so the last page's reading time isn't
  lost. For a one-page extra, that dwell is the whole chapter.

## 0.1.2 (2026-07-14)

* Docs: recommend the [`dims`](https://hex.pm/packages/dims) package
  for the Store's page-dimensions contract (exact per-page sizes drive
  double-page spread pairing).
* Fix a compile warning (unused import).

## 0.1.1 (2026-07-14)

* The mouse-gesture button (bottom-right) now shows a 4-directional
  move icon instead of a right arrow, matching the OS auto-scroll
  affordance it provides.
* Middle-click (scroll-wheel button) anywhere in the reader now
  toggles mouse-gesture mode — the same gesture as OS auto-scroll.
  Middle-clicks on links/controls keep their native behavior.
* Fix: the nav's "Ch. N" labels and prev/next arrow anchors now track
  in-place chapter swaps — they were server-rendered once and went
  stale as reading chained across chapters (label stuck on the
  starting chapter, arrows navigating relative to it). Arrows hide at
  the ends instead of keeping a stale target.

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
