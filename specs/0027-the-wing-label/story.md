# 0027 — The wing label

Date: 2026-08-21
Lane: **Full (≤ 2-day core).** No schema change, no JavaScript. One new route and
page (`/feed/index`), one glyph on the existing rail, three partials deleted, one
constant re-decided, one query moved from the pool to the scope.
Status: **Draft.** Branch `gallery-filter-6star`. Takes the WIP slot — 0025/0026 shipped
2026-08-20 (`SHIPLOG.md`), slot open (R5).

Promoted from `IDEAS.md` Inbox same day (owner screenshot review, 2026-08-21).

## Who

- **Maya** — persona 1, CORE. The guard rail that 0022 and 0024 each promised and
  together broke: "her session must not get slower or busier." Today `/feed` puts
  **34 controls in three rows above the first work**; on a 390px phone each row is a
  `nowrap` horizontal scroll with most values off-screen. She came for pictures and
  gets a form.
- **Amara** — persona 3, Educated Depth-seeker, the driver of 0022/0024. The wings are
  in the pool (Mughal 108, Pahari 89, Kalighat 57) and the words are on the screen —
  and she still cannot walk into one with confidence, because nothing tells her
  whether a tap leads to a wing or a closet, and **74% of two-tap paths end in
  "Nothing here wears both" or a page of 1–4 works.**
- **Tomás** — persona 4, museum-mode browser. A museum wing has a label on the wall
  with a count of rooms. This is that label.
- Not in this story: Jordan (favorites untouched), curator (no admin change),
  Priya/Zoe (Phase 3 gate).

## Problem

**The facet UI shipped as three stories' worth of rows, never designed as one
control.** Owner rated it **3 of 11** on the Chesky scale, 2026-08-21. Measured against
the committed 2,302-work dev pool the same day:

| Defect | Measured |
|---|---|
| Unlabeled rows | 3 rows, each opening with a dim `All`. No row says century / subject / tradition; the reader infers it from the values. |
| Chrome before art | 34 controls. First work at ~y 330 of 870 on desktop. On 390px: three horizontal-scroll rows, no scroll indicator (DESIGN rule 6 forbids one). |
| Dead ends by combination | Two-facet combos: **176 of 318 empty** (period×genre 35/90, period×tradition 49/108, genre×tradition 92/120). 60 more hold 1–4 works. |
| No weight | Madhubani (6) and 19th century (783) render identically. Six offered values sit under 16 works: Madhubani 6, Nude 7, Animal 9, Cityscape 10, Marine 11, 12th century 15. (Persian & Islamic sits at 19 — a floor of 20 would have taken it too; see `decisions/0017`.) |
| Silent coverage holes | 1,423 works carry no genre; 1,247 no tradition. Tap `Portrait` and 228 portraits with no tradition drop out of every tradition combo; 84 Mughal works have no genre. Nothing says so. |
| Active state is dimming | Same idiom the compass uses for "you are here." Unfiltered = three dim `All`s that mean nothing. The only feedback is the masthead count, a row and a half away. |
| Wrapping | Tradition labels wrap to two lines; row heights go uneven. |

Root cause, not blame: `MIN_FACET_WORKS = 5` was written as "provisional; Release 2
re-decides by measurement" (0022 plan D3) and was never re-decided. `_facet_row` was
designed for one row (0022 Release 1) and reused twice. The non-empty rule guards each
facet alone, never the intersection a reader actually taps into.

## Story

As **Amara**, I want to tap "Mughal painting" and know before I tap that it is a wing of
108 works, and then tap "18th century" and see only centuries the Mughal wing actually
has — so every path through the gallery ends at pictures, never at an apology.

As **Maya**, I want the gallery to open on art, with the filters out of sight until I
ask for them.

## What ships — 6 stars, not 5

**Amended 2026-08-21, after the canvas.** The first draft of this section put one
collapsed row of three named pickers under the rail. Mocked at 390×844 (round 1,
three options) it still added a row and stacked values 44px apiece; the owner
rejected all three. Round 2 made the filter cost **zero pixels** until asked for and
put the index on its own screen; the owner chose **F** (the door rides the sticky
rail) and, of three index treatments, **Plates**. The canvas is the record
(`The Wing Label`, artifact `a30286fb`, pages "Round 1", "Round 2", "F — working
mock", "Index — three directions"). What follows is the chosen shape.

The Chesky exercise: an 11 is a curator walking you into the wing you named with
three works already pulled. Back off to what a 2-day Hotwire story can hold honestly:

**The 5 — works, no surprises (all required):**

1. **Zero pixels on the feed.** No filter row. `/feed` unfiltered is today's feed
   minus the three rows: **first plate above the fold at 390×844 at first paint.**
2. **One door, on the sticky rail.** A floor-plan glyph (23px, 1.4 stroke, 44px
   target — a functional glyph under amended DESIGN rule 6) at the right end of the
   compass rail. Fills when a facet is active. The only control that survives
   scrolling: reachable forty works down.
3. **The index is its own screen** — `/feed/index`, a real page with the masthead
   ("The index", count in the aside) and compass. Not a modal, nothing hovering
   over art. Tradition and subject as **plates**: a real work from each wing,
   uncropped (contain, letterboxed, frame edge — the plate idiom at 80px), four
   across, name and count beneath. Century as a caps row.
4. **Scoped values — the non-empty rule extended to intersections.** Every value
   is counted within the scope of the *other* active facets (switching Mughal →
   Pahari replaces, not ANDs). A value that would land under the floor is not
   offered. The empty state becomes unreachable by tapping — kept only for stale
   deep links.
5. **Floor re-decided: `MIN_FACET_WORKS` 5 → 16** (`decisions/0017`; first written as
   20 — eng review's outside voice found 20 drops Persian & Islamic at 19, the
   second-most-searched tradition). Drops the six near-dead values.
   Pinned by a pool assertion (R1): every value the index offers clears the floor,
   unfiltered and under each single-facet filter.

**The 6 — the part that reads as Tondo (required, this is the ask):**

6. **The feed's label is a sentence in the editorial voice.** The masthead label
   already speaks ("The full gallery"); under a filter it becomes *"Mughal
   painting, eighteenth century"* — a wall label, not a chip stack. Facet values
   get hand-written display forms — a short form for plate captions ("Mughal",
   "Jain", "17th") and a sentence form for the label ("Mughal painting",
   "portraits", "eighteenth century") — **written by the owner, not generated**
   (CLAUDE.md: editorial text is hand-written).
7. **The wings have faces.** The index shows the art it indexes. The face of a
   wing is its first work in curation order — the owner's order — with a pin as a
   later escape hatch, not built now.
8. **Untagged is named, not hidden.** For each of subject / tradition not active,
   one dim line counted inside the current scope: with Mughal active, *"Subject is
   known for 24 of 108 works."* A facet with nothing to offer inside the current
   wing says so in one line rather than vanishing.
9. **Sections ordered by demand, not by story number.** Tradition, subject,
   century (`user-research/0008` §3.3); within a section, heaviest wing first.

**7+ — named so they do not creep in (see Non-goals):** hand-curated "wings"
(named tradition+period combos with a written line), remembering the last filter per
device, a pinned face per wing.

## Intake

- **Problem:** above — three unlabeled rows, 34 controls above the art, 176 of 318
  two-tap paths dead, no weight, no summary.
- **Evidence:** owner review of the live screen 2026-08-21 (3/11); counts measured
  against the dev pool the same day (table above); 0022's own Maya guard rail,
  violated; `IDEAS.md` Inbox 2026-08-20 "facet-usage receipt" — every facet success
  signal so far is an input metric, and a 3/11 surface will not produce the output one.
- **Success signals (prediction, falsifiable, time-bound):**
  1. **By Aug 23:** `bin/ci` green. System test: on a 390×844 viewport, the first
     `.painting` plate's top edge is inside the viewport at first paint of `/feed`,
     unfiltered. (Today it is not.)
  2. **By Aug 23:** a test walks every offered value under every offered
     single-facet filter and asserts the resulting page has ≥ `MIN_FACET_WORKS`
     works — **zero reachable empty states.** The "Nothing here wears both" state
     stays, reachable only by URL.
  3. **By Aug 23:** every value the UI renders clears the floor, unfiltered and
     scoped; the assertion lives in the test suite, not the story.
  4. **Owner re-rates ≥ 6/11 on the same screen before merge.** Subjective by
     design — it is the metric that opened the story. Wrong if < 6: then the design
     review missed it, and the story does not ship on "but the tests pass."
  5. **Not this story's gate:** whether readers tap it — the `IDEAS.md` receipt
     idea and the next gallery run (`user-research/0006`).
- **In baseline?** Yes — Better bucket 2 ("art + text visible together — text never
  swallows the artwork": today the filter chrome does) and bucket 6 ("curation range
  made navigable"), on the 0022/0024 footing. Not the New differentiator.
- **R7 note:** moves **0 of 5** `BET.md` thresholds directly. It is the screen the
  facet stories already spent three days on; leaving it at 3/11 wastes them.

## Non-goals

- **Hand-curated wings** (`Mughal miniatures` = tradition+period+written line).
  Editorial curation on top of navigation; it is the 7-star and it borders the New
  slot. Needs its own evidence. Parked in `IDEAS.md` when this promotes.
- **Remembering the last filter per device.** Plausible 7; no evidence anyone returns
  to a filter. Parked.
- **New facets, new data, schema changes.** The pool and its columns are what 0025/0026
  left. This story spends nothing on fill.
- **Filter on `/days`.** Chronological by design; 0022 D4 settled it, 0024 reaffirmed.
- **Search box.** Tomás's ask, New-slot candidate in `specs/personas.md`. Not this.
- **A sticky filter bar.** DESIGN rule 5's sticky budget on `/feed` is spent on the
  compass rail — and the door is one glyph *on* that rail, navigation only, not a
  second bar. The filter state itself (the label) scrolls away with the masthead.
- **A pinned face per wing.** The face is the first work in curation order; an admin
  pin is the escape hatch if a default ever embarrasses a wing. Parked, not built.
- **AI-written label copy.** Display forms and the coverage line are hand-written
  (CLAUDE.md ban).

## Design constraints carried in

- DESIGN rule 4: counts and the coverage line are dim. The masthead label keeps its
  own treatment (italic, `--ink-faint`) filtered or not — struck at design review
  (outside voice #19): the label is the screen's name, and the name does not get
  louder when it changes.
- DESIGN rule 2: a plate thumbnail is `contain`, letterboxed on `--bg-lift` with the
  frame edge — a smaller picture, never a cropped one.
- DESIGN rule 5: nothing hovers over art — the index is a page, not an overlay; the
  glyph is navigation on the one sticky rail the rule already allows.
- DESIGN rule 6: no cards, shadows, or rounded corners on the plates grid; the door
  is a functional glyph (23px, 1.4 stroke), not ornament.
- DESIGN rule 9: every plate, value, and the glyph is a 44px target in both axes —
  the four compass words plus the glyph must still fit one row at the Dynamic Type
  cap on 375px (measured, see plan risks).
- `/feed` stays walled and private (0015); scoped counts are not per-reader, so no
  cache concern — but they are per-filter, so no `public` cache either (already true).

## Open for the plan

- The rail at the Dynamic Type cap on 375px: four words + a 44px glyph may wrap —
  plan names three options; design review measures and picks.
- Hotwire Native stack shape for index → filtered feed (`data-turbo-action="replace"`
  or not) — verified in the simulator, recorded in the plan's Deviations.
- Query cost of `/feed/index` (three scoped `GROUP BY`s + up to 16 plate lookups and
  variants) — measured, not guessed, before any caching is considered.
