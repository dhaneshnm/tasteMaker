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

## Result (2026-08-20) — prediction 1 falsified, on the record

`pool:curate` at TARGET=3,000 raised `Unmeetable` against the real mirrors: pool size
2,847/3,000, museum text 1,999/2,100. A target search (binary search over `Pool::
Curator::TARGET`, same candidates and bars) found the additive ceiling is
**~2,428, not 3,000** — the exact mechanism is `MAX_REGION_SHARE = 0.25`, which caps
europe/south_asia/east_asia at a quarter of the pool each, combined with the real fact
that these four museums' CC0 painting holdings carry almost no North American work
(531 total, pinned + new — a hard ceiling, not a caps artifact) and little in the
remaining smaller regions combined (~76). `pool_size = 0.75·TARGET +
min(607, 0.25·TARGET)`, which equals TARGET only up to ≈2,428 — above that, the
region cap and the region's own real-world thinness pull in opposite directions and
the smaller number wins.

**This is prediction 1's own falsification clause firing exactly as written**: "the
fallback (swap within whatever total the bars allow) executes." Re-reading that
clause against the actual math: a swap of *which specific works* are pinned does not
change the ceiling — the constraint is supply (how much CC0 North American painting
these four museums hold) and policy (the region cap that exists specifically to
protect range, persona 3's complaint), neither of which moves by reshuffling
identities within the same total. "Whatever total the bars allow" **is** the lower
additive target — swap and "accept ~2,428" are the same fallback, not two different
ones. Shipped at **`Pool::Curator::TARGET = 2,300`** (a safety margin below the
~2,428 ceiling, chosen so the real network-verified run succeeds without a second
multi-hour attempt), not 3,000. Not reopened: the region cap itself is not loosened —
that would resolve the falsification by deleting the thing it's protecting.

Prediction 2 (per-theme floors) reads separately, partially falsified: 7 of 10
targeted themes clear their `want` at the final, post-pipeline count (all 10
clear `MIN_FACET_WORKS = 5`, the actual display-floor bar — Icon and Vanitas
are the two that don't clear their higher story-level `want`). Persian
miniature falls short from curation time onward (19/25, unaffected by
`genre_fill` — a tradition-route theme). Icon, Vanitas, and Marine all cleared
their `want` at curation time and then fell (or, for Marine, narrowly missed)
once `pool:genre_fill` ran — the museums' own tags legitimately outrank a
title-inferred value per the seed ladder. Icon 5→4, Vanitas 5→2 (zero margin
to begin with, 5 usable candidates each in all four museums combined), Marine
12→11 (still comfortably above `MIN_FACET_WORKS`). Code review caught that the
curation-time report couldn't see this (a genre-route theme's tag data doesn't
exist yet when `fill_themes` runs) — `Pool::Report.theme_recount_section` now
recomputes every theme from the committed manifest through the full ladder
after `genre_fill`, and `pool_report.md` carries both tables. None of this
gates `bin/ci` (see `test/lib/pool_quota_test.rb`).

Full numbers: `specs/0026-the-wider-pool/plan.md` Deviations.
