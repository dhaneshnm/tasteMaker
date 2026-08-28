# 0029 — Plan

## The real shape of the data, checked before designing anything

`Painting::FACETS = %i[period genre tradition]` (`app/models/painting.rb:146`) — all three
dimensions the owner asked for already exist as live, computed facets;
`Painting.displayed_facet_values(facet)` already returns exactly the values that clear
`MIN_FACET_WORKS = 16` for each. This story reuses that, not a new floor.

Today's live counts (2,344 works, post-0028):

| Facet | Displayed values | Known for |
|---|---:|---:|
| genre (subject) | 6 (Religious 338, Portraits 263, Landscape 140, Still Life 50, Myth 30, Flowers 29) | 896 (38%) |
| tradition | 11 (Japanese 288 … Persian 19) | 1,072 (46%) |
| period (century) | 9 (12th 17 … 20th 309) | ~2,050+ (nearly all — `period` is derived from `dated`, which almost every work carries) |

**The number that changes the design**: genre + tradition combined are known for at most
~54% of the pool (the two sets overlap, so the true union is somewhere under 896+1072).
A template built only from the 17 genre+tradition category values has **no candidate at
all for well over half the pool** on any given cycle. A fixed 15–20-slot template, as
literally described ("repeat those"), either strands the untagged majority at the tail
(the exact failure success signal 3 in `story.md` calls out) or has to dedicate roughly
half its own slots to "uncategorized," which most people wouldn't recognize as one of
"fifteen or twenty categories."

## Recommendation: a rotating lens, not a fixed value list

Three points, then the mechanism:

1. **A "template" here can't be one flat list of ~17 values** — genre, tradition, and
   period are three *independent* dimensions (a single painting is simultaneously a
   Portrait, Mughal, and 18th-century). Flattening them into one 26-value list and
   round-robin-ing across it means a painting can only ever represent ONE of its three
   true categories per appearance, arbitrarily.
2. **Bucket sizes range 19 to 794** (Persian tradition to 19th-century period) — a fixed
   small template treats a 794-work bucket and a 19-work bucket as equally "one slot,"
   which either exhausts the small bucket almost immediately (Persian: 19 works ÷ 1-per-
   cycle ≈ empty after 19 cycles, then that slot has nothing for the remaining ~130
   cycles a 2,344-work pool needs) or, if slots repeat proportionally, stops looking like
   "fifteen or twenty placeholders" at all.
3. **Recommended mechanism**: a **rotating lens** — the sequence of *positions* cycles
   through `[genre, tradition, period, untagged]` (4 lenses, repeating), and each lens
   internally cycles through ITS OWN displayed values in turn (genre: Religious →
   Portraits → Landscape → Still Life → Myth → Flowers → repeat; tradition: its 11 values
   in turn; period: its 9; `untagged`: a plain seeded shuffle of whatever carries none of
   the three tags). A painting is placed once, by whichever lens+value claims it first
   (priority: genre-lens claims before tradition-lens, matching `Recognizable`'s existing
   "primary slug" idea — the first dimension to need it gets it, everything else skips an
   already-taken identity, same `@taken` idiom `Pool::Curator` already uses).

   This produces exactly what "first a portrait, then a landscape, and so on" describes
   — a step through named categories — while staying honest about period (a THIRD named
   step, not folded into the other two) and about the untagged majority (its own
   recurring step, not silently deferred to the end).

**A cycle** (one full pass: genre-lens visits each of its 6 values once, tradition-lens
each of its 11, period-lens each of its 9, untagged-lens some fixed count per cycle —
proposed **6**, matching the genre lens length so no single lens dominates a cycle) is
`6 + 11 + 9 + 6 = 32` positions. Not 15–20 — the real number, given three independent
facets exist today, not the two (subject + a folded-in sense of "and so on") the
original description was picturing. **This is the one open call worth confirming before
implementation**: ship the 32-position rotating lens as designed above, or fold period
out of its own lens and use it only as a same-slot tiebreak (closer to the original
15–20 estimate, weaker on the explicit "time period" ask). Recommendation is the
32-position version — it answers all three named dimensions instead of two, and the
`display_facet_values` counts it's built from already update themselves as the pool
grows, so it never goes stale the way a hand-picked list of 15–20 names would.

## Where this runs

A new rake task, `pool:interleave` — same shape as `pool:genre_fill`
(`lib/tasks/pool.rake`): reads the committed manifest, does **not** re-select or re-fetch
any work, only recomputes and rewrites the `feed_order` field, then appends a section to
`db/seeds/pool_report.md` (lens visit counts, any lens-value that ran out before the pool
did — logged, not hidden, same idiom `fill_themes`'s shortfall reporting already uses).
Runs once after `pool:curate` (or after `pool:genre_fill`, since tradition/genre tags can
still be filling in at that point) — NOT folded into `Pool::Curator` itself, because
ordering is orthogonal to selection and `pool:genre_fill` already establishes "a
standalone enrichment pass over the committed manifest" as this codebase's pattern for
exactly this shape of problem.

New module: `lib/pool/feed_interleave.rb` — `Pool::FeedInterleave.reorder!(manifest_rows)`,
pure function over the manifest's own rows (genre/tradition/period/artist already sit on
each row — no mirror or DB read needed), returns the same rows with `feed_order`
reassigned. Seeded shuffle within each lens value's own candidate list
(`Pool::Curator::SEED`, same constant, same reproducibility guarantee every other stage
already has).

## The feed_order-stability promise this breaks — and why now is the cheap time to break it

`specs/0026-the-wider-pool/plan.md` built `feed_order` specifically so a reseed never
disturbs an existing `/feed?page=N`. This story reassigns `feed_order` for all 2,344
rows, once — a real, full break of that promise, not a corner case of it.

**Why this is the right time anyway**: every `SHIPLOG.md` entry through 2026-08-27 reads
"zero installs." There is no reader today with a real bookmarked page to break — the cost
this story pays is paid against nobody. Doing the same reorder after the first real
install would cost something; doing it now costs nothing measurable. No `decisions/`
entry proposed for this reason specifically — R4 is for direction-level calls with real
stakes, and "reorder a feed nobody has scrolled yet" doesn't clear that bar. Named here
so it's not silently assumed.

## Test plan (for the implementation story, not run here)

- `Pool::FeedInterleave` unit tests, same style as `PoolCuratorTest`: a synthetic pool
  with known bucket sizes, assert (a) every displayed facet value appears within its
  lens's first cycle, (b) no work is placed twice, (c) untagged works are interleaved
  throughout, not clustered at the tail, (d) a lens value that runs out mid-pool degrades
  to "skip that slot" for the remainder — pool still fully placed, shortfall reported.
- `pool_quota_test.rb` gets one new assertion mirroring story success signal 1: sample the
  first 30 `feed_order` positions of a real curated pool, assert ≥ N distinct genres and
  ≥ M distinct traditions appear (N, M pinned to the actual lens-cycle math above once
  implemented, not guessed).
- Manual: `/feed` scrolled in a browser, first ~40 works, eyeballed against the report's
  lens-visit log.

## Non-goals (implementation-time, restated from story.md)

- No live/per-request sort — `pool:interleave` runs at curation time like every other
  pool-shaping step.
- No change to filtered views (`/feed?genre=…`) — already single-category by construction.
- No `decisions/` entry for the feed_order-stability break — reasoned above, zero
  installs make it free today.
