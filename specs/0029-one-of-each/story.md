# 0029 — One of each

Date: 2026-08-28
Lane: **Full (≤ 2-day core).** New ordering module + rake task, no schema change, no new
UI — `/feed`'s existing `feed_ordered` scope (`app/models/painting.rb:134`) is untouched;
only the `feed_order` VALUES on 2,344 rows change.
Status: Draft. WIP slot: 0028 shipped 2026-08-27/28 (`SHIPLOG.md`), slot open (R5).

Promoted same-day from an owner screenshot review (`/feed/index`, the wings screen,
2026-08-28) — same intake path story 0027 used.

## Who

- **Maya** — persona 1, CORE. Scrolls `/feed` without tapping a facet door. Today's order
  is a stable seeded shuffle (`Pool::Curator::SEED = 1889`) — stable, but not composed;
  nothing stops five landscapes or five 19th-century Japanese prints from landing back to
  back by chance.
- **Amara** — persona 3, guard rail. The pool's whole range-bar apparatus (0013, 0016,
  0019, 0026) fights to make the *pool* diverse. Nothing today makes a *scroll* diverse —
  a reader could scroll 50 works deep through an unlucky run and never see the range the
  pool actually holds.
- **Jordan** — favorites contract. `feed_order` is currently the thing that keeps a
  bookmarked `/feed?page=N` meaning roughly the same thing across a reseed
  (`specs/0026-the-wider-pool/plan.md` step 2, "every bookmarked `/feed` offset inside the
  pinned range survives untouched"). This story's mechanism changes `feed_order` for
  every row, once — named as a real break of that promise, not hidden. See Non-goals.

## Problem

**The gallery's browse order is a fixed shuffle, not a composed sequence — so what a
reader sees in a row is luck, not design.** Owner's own screenshot of `/feed/index`
(the wings screen, story 0027), 2026-08-28:

- **Subject** (`genre` facet): Religious 338, Portraits 263, Landscape 140, Still Life
  50, Myth 30, Flowers 29 — 6 values clear `MIN_FACET_WORKS = 16`. **Known for 896 of
  2,340 works (38%).**
- **Tradition**: Japanese 288, Chinese 215, Mughal 108, Rajput 97, Jain 92, Pahari 89,
  Kalighat 57, Korean 38, Tibetan 35, Ukiyo-e 24, Persian 19 — 11 values clear the floor.
  **Known for 1,072 of 2,340 works (46%).**
- **Century** (`period`): 12th through 20th, 9 buckets, counts 17–794 — the third facet
  `Painting::FACETS` already tracks, alongside genre and tradition
  (`app/models/painting.rb:146`).

The ask, in the owner's own words: "the feed to be representative of the various
categories in our gallery... first will be a portrait and then a landscape and so on, so
that the feed is well distributed among subject, tradition, and time period."

**A hard number, not a guess:** more than half the pool (54% by subject, 54% by
tradition) carries no tag on the dimension being asked for at all — any repeating
template has to say what happens to the untagged majority, not just the tagged
minority. That split is this story's central design question; see plan.md.

## Story

As **Maya**, I want a scroll through `/feed` to feel like a walk through the whole
collection, not a coin flip — so that five works in a row don't repeat the same subject,
tradition, or century by chance.

## Intake

- **Problem:** above.
- **Evidence:** owner screenshot, `/feed/index`, 2026-08-28 (counts transcribed above);
  `Painting::MIN_FACET_WORKS = 16` and `Painting.displayed_facet_values` are the existing,
  live-computed floor this story reuses rather than re-deriving a new one.
- **Success signal (prediction, falsifiable and time-bound):**
  1. **On ship:** a fresh `/feed` scroll (no facet filter active), read 30 works deep from
     position 0, contains at least N distinct subjects and M distinct traditions where N
     and M are set in `plan.md` from the real template size — not "some variety," a
     number a test asserts.
  2. **On ship:** every one of the `displayed_facet_values(:genre)` and
     `displayed_facet_values(:tradition)` values appears at least once in the first full
     template cycle (see plan.md for the cycle length) — a reader who scrolls one cycle
     deep has seen the whole range the pool advertises on `/feed/index`, not just the
     thickest few categories.
  3. **Falsified if** the untagged majority (54%/54%) ends up silently pushed to the
     tail of the feed rather than interleaved — that would "fix" the visible categories
     while making the ordering worse for the uncategorized majority, the same shape of
     mistake 0019 named and avoided for artist coverage.
- **In baseline?** Execution-quality polish on the Proven-baseline browsable archive
  (CLAUDE.md Better bucket) — not a new user-facing capability, not the New-differentiator
  slot. No new evidence bar to clear beyond the screenshot above.
- **R7 note:** moves 0 of `BET.md`'s 5 thresholds. Kill review passed 2026-08-31 — this
  story is written and planned post-review-window if the app survives it; see session
  gates before implementation starts.

## Non-goals

- **Per-filtered-view reordering.** `/feed?tradition=mughal-painting` already narrows the
  SAME `feed_ordered` scope (story 0022/0024) — a filtered view is already
  single-category by construction and doesn't need interleaving. Only the unfiltered
  default view is in scope.
- **A live/dynamic sort.** The template runs once per re-curation (a new `pool:interleave`
  step, see plan.md), not per-request — matching how `feed_order` already works today,
  not introducing a new per-request cost.
- **Fixing the feed_order-stability break silently.** This story changes `feed_order` for
  the whole pool, once. Whether that's an acceptable one-time cost or needs its own
  `decisions/` entry is decided in plan.md, not assumed here.
