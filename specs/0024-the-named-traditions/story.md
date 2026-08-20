# 0024 — The named traditions

Date: 2026-08-20
Lane: **Full (≤ 2-day core).** One column, one pure function, one facet row on existing
machinery, one adjudicated mapping table. No new external dependency.
Status: **Draft — first of the three-story sequence from decisions/0016** (findability
→ findability → expansion). Takes the WIP slot when it opens (R5).

Promoted from `IDEAS.md` Inbox ("Tradition facet from culture strings", captured
2026-08-20 from `user-research/0008` N3) same day — the WIP sequencing is the queue,
not the Inbox.

## Who

- **Amara** — persona 3, Educated Depth-seeker, the driver, in her own words: *"she
  wants Benin bronzes, **Mughal miniatures, ukiyo-e**."* The pool holds Mughal 102,
  Rajput 102, Pahari 84, Kalighat 44, Chinese 180, Japanese 276, Jain manuscript ~52 —
  and no surface can say any of those words. 0013/0019 put the range in; nothing yet
  makes it findable as what it is.
- **Maya** — persona 1, CORE. Guard rail: `/feed` must not get slower or busier. One
  more `.caps-link` row in the pattern 0022 already taught her, nothing else.
- **Tomás** — persona 4, museum-mode browser. A tradition is a museum wing; this is
  the wing label.
- Not in this story: Jordan (favorites untouched), curator (no admin change),
  Priya/Zoe (Phase 3 gate).

## Problem

**~35% of the pool (~700 works) carries a nameable painting tradition in free-text
culture strings that no facet can express** (`user-research/0008` §3.5). Each drawn
tradition pulls 15K–72K annual Wikipedia lookups (Mughal painting 67,575; Thangka
49,234; Kalighat 27,733; Pahari 24,013). Demand phrasing is corroborated by
autocomplete ("mughal paintings", "mughal paintings of women"). The 0022 facet
machinery (columns → `displayed_facet_values` → `_facet_row`, `MIN_FACET_WORKS = 5`
floor) is built and generic; the tradition axis just never got a column.

## Story

As **Amara**, I want to tap "Mughal Painting" on the feed and see the Mughal works,
so the range this pool actually has stops hiding behind curation order.

## Intake

- **Problem:** above — stored data, real demand, no surface.
- **Evidence:** `user-research/0008` §3.5 + §3.3 (pageviews per tradition, autocomplete
  phrasing); gallery tests 2026-08-15/16 observed theme-seeking in session
  (`IDEAS.md` → 0022's evidence chain); persona 3's verbatim ask.
- **Success signal (prediction, falsifiable and time-bound):**
  1. **By Aug 22:** `/feed?tradition=mughal-painting` filters correctly; every
     tradition value rendered clears `MIN_FACET_WORKS`; unfiltered `/feed` is
     byte-identical except the new row; `bin/ci` green.
  2. **Mapping accuracy, measured not asserted:** a hand-audit of 50 random
     tradition-stamped works finds ≥ 95% correctly attributed (the culture strings
     are free text; "Rajasthan" can catch non-Rajput works). Audit result recorded in
     the plan's Deviations. **Falsified if** < 95% — then the offending pattern
     narrows or drops rather than shipping a wrong label.
  3. **Not this story's gate:** whether readers tap it — next gallery run's
     theme-seeking denominator (`user-research/0006`), per decisions/0016 tripwire.
- **In baseline?** Yes — Better bucket 6 ("curation range beyond Euro-canon") made
  navigable; same footing as 0022, which `IDEAS.md` bucketed "Proven (nav)". Not the
  New differentiator.
- **R7 note:** moves **0 of 5** `BET.md` thresholds. Findability for the expansion
  story behind it (decisions/0016 sequencing), eleven days from kill review.

## Non-goals

- **Movement facet** — Rule 3 (decisions/0016): movements arrive by P135-verified
  artists via the reconciliation story still queued in `IDEAS.md`, not by strings.
- **Ukiyo-e as a value.** The pool's ~18 Edo works are Edo *painting*, mostly not
  ukiyo-e; stamping 306K-lookup expectations on that label needs the expansion
  story's 16 nikuhitsu works first. The value ships when 0026 stocks it.
- **Inventing tradition names.** The vocabulary is the 0008 measured list (Wikidata/
  enwiki article names); same "don't invent a taxonomy" constraint as 0022.
- **`/days` filtering** — chronological by design; 0022 D4 settled it.
- **New manifest fields.** Derivation is a pure function at seed time; the manifest
  does not change (0022 D2's reseed-safe pattern).
