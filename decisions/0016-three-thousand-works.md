# 0016 — Three thousand works: the pool widens before it swaps

Date: 2026-08-20
Trigger: `user-research/0008-recognizable-themes.md` + its §3.7 mirror-stock addendum.
Owner decision, recorded under R4 before any feature commit depends on it (R2/R4).

## Position

`Pool::Curator::TARGET` rises **2,000 → 3,000**, additively: the committed 2,000 works
are pinned (published days and favorites reference them — Jordan's contract), and the
curator fills 1,000 more under the same bars, with a new theme-quota stage aimed at the
0008 demand gaps. **Swap-based re-curation is the fallback, not the plan**: it fires
only for theme floors the additive fill cannot meet with bars green.

This overrides the researcher-recommended default ("swap, don't grow" — 0008
Consequences, and 0019's wrong-if named "fill only by growing TARGET" as a failure
smell). Recorded as the owner's explicit call, hybrid shape: findability first
(0024, 0025), then additive expansion (0026), swaps last. The 0019 smell was written
against *quota-dodging* growth — growing TARGET to avoid honest range math. This
growth is theme-directed and keeps every bar as a share, so the floors rise with it
(non-Western 900 → 1,350, text 1,400 → 2,100). If that distinction turns out to be
self-serving, the falsification below catches it.

Not reopened: the 10–20K aggregation trap stays parked. 3,000 is a curation, not a
crawl. `MAX_PER_ARTIST = 5` holds (0.25% → 0.17% of pool).

## Falsifiable predictions

1. **By 0026's ship date:** `verify!` holds every 0013 bar at 3,000 with zero swaps.
   **Falsified if** `Unmeetable` at every viable configuration — then the fallback
   (swap within whatever total the bars allow) executes, and this entry's "additive
   is enough" position is dead on arrival, on the record.
2. **By Sep 20 (the 0015 binding-read date):** every 0008 top-theme facet the mirrors
   can stock (Persian miniature, thangka, ukiyo-e, Madhubani, still life/flowers,
   marine) clears `MIN_FACET_WORKS = 5` from the expansion alone. **Falsified if** any
   needs a swap after all — partial falsification per theme, logged in the pool report.
3. **Tripwire, next gallery run** (`user-research/0006` protocol, theme-seeking
   denominator): if theme facets draw **zero unprompted taps across ≥ 5 participants**,
   the 1,000 added works are inventory nobody browses, and any talk of 4K reopens
   THIS entry first, with that number in hand.

## Costs, named

~+0.33 GB plates on the volume; +1,000 works of museum-text share (blurb debt is
per-day, not per-work — 0023's tripwire unaffected); curation + audit time inside an
11-day window to kill review, moving 0 of 5 `BET.md` thresholds. Sequenced third
behind two findability stories for exactly that reason.
