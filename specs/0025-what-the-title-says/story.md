# 0025 — What the title says

Date: 2026-08-20
Lane: **Full (≤ 2-day core).** One pure function + dictionary, seed-time fill, one
vocabulary addition (Flowers), one invariant test rewritten. No UI change — the genre
facet row already renders whatever lights.
Status: **Draft — second of the decisions/0016 sequence**, queued behind 0024 (R5).

Promoted from `IDEAS.md` Inbox ("Genre fill v2: title/description keywords", captured
2026-08-20 from `user-research/0008` N2/N5).

## Who

- **Amara** — persona 3. The genre facet 0022 shipped is real where it exists — and it
  exists almost nowhere she browses: 248 of 2,000 works, AIC/MET only.
- **Maya** — persona 1, CORE. "Paintings of flowers" is a top-3 autocomplete
  completion of "paintings of"; the pool has ~148 flower-work candidates and the facet
  has no Flowers value. The names people actually use, present when looked for —
  0019's credibility argument, subject edition.
- Not in this story: Tomás (no new surface), Jordan, curator, Priya/Zoe.

## Problem

**The genre facet covers 12.4% of the pool because its only route (museum tags) is
structurally blind to 80% of it.** 0022's dry run measured CMA and MIA as having *no*
subject field at any effort — correct, and shipped honestly. What it never measured:
**titles and descriptions exist on every work.** The 0008 keyword probe over the 1,752
genre-nil works found candidate ceilings of Religious 302, Landscape 210, Portrait
163, Flowers 148, Still Life 27, Mythological 24, Marine 12 (`user-research/0008`
§3.6) — adjudicated even at half yield, coverage goes 248 → ~600–900, and every new
fill lands in exactly the sources the museum-tag route cannot reach.

Venue phrasing (0008 §3.3): subject demand speaks depicted content — "paintings of
jesus / flowers / women" — not taxonomy. A title reading "Bouquet of Roses in a Vase"
answers that ask; a missing museum tag was never the reader's problem.

## Story

As a reader who came looking for a kind of picture — flowers, a portrait, a sea —
I want the genre filter to know about works whose titles plainly say what they are,
so four-fifths of the collection stops being invisible to the one facet that could
answer me.

## Intake

- **Problem:** above.
- **Evidence:** `user-research/0008` §3.6 (probe counts + samples, raw data
  `data/0008-pool-coverage.json`); §3.3 autocomplete phrasing; 0022's own dry-run
  finding that museum tags cap at 15–20% (this story is that ceiling's third route,
  not a reopening of the museum-tag verdict).
- **Success signal (prediction, falsifiable and time-bound):**
  1. **By Aug 24:** genre coverage ≥ **500 works** (from 248) with every fill made by
     the ordered dictionary through the same validations as museum-tag fills;
     `bin/ci` green. **Falsified if** adjudication forces the dictionary so narrow
     that coverage lands under 500 — then the probe's half-yield estimate was wrong
     and the honest number ships with the shortfall logged (0022's own falsification
     idiom).
  2. **Precision, measured not asserted:** hand-audit of 50 random title-route fills
     ≥ 95% correct; result in plan Deviations. **Falsified if** below — offending
     patterns narrow or drop before ship.
  3. **A Flowers value exists and clears `MIN_FACET_WORKS`** on `/feed` — the one
     vocabulary addition demand makes (0008 N5).
- **In baseline?** Yes — same footing as 0022 Release 2 (Better bucket 6, "Proven
  (nav)"). The route is new; the feature is the same facet getting honest coverage.
- **R7 note:** moves **0 of 5** `BET.md` thresholds. Second findability prerequisite
  for the expansion story (decisions/0016).

## Non-goals

- **AI classification.** The dictionary is hand-written patterns over titles the
  museums wrote; the BANNED line does not move. The machine matches strings; it
  neither writes nor describes.
- **Touching museum-tag fills.** Where AIC/MET tags produced a genre, that value
  stands — tags outrank titles (provenance ladder, plan D1).
- **New genre vocabulary beyond Flowers.** Vanitas, trompe-l'œil, icon — real
  demand, sub-`MIN_FACET_WORKS` supply today; the expansion story restocks first.
- **Tradition axis** — 0024's column, separate question, filters compose.
- **Movement axis** — Rule 3, reconciliation story, unchanged.
