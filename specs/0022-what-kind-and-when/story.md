# 0022 — What kind, and when

Date: 2026-08-19
Lane: Full (core), split into two releases — the 0018/0019 shape, chosen at intake this
time instead of discovered at eng review. Honest size: **Release 1 ≈ 1.5–2 days,
Release 2 ≈ 1–2 days**, sequential.
Status: Draft

**Release 1 — the machinery.** Schema, filter UI, controllers, tests. Ships with whatever
facet data exists at ship time (the period facet has raw material today; the genre facet
almost certainly ships empty — see "Release 1 ships dark" below).
**Release 2 — the fill.** Taxonomy dry-run, backfill of the pool, facet floor decided by
measurement. The 0019 pattern: measure first, the report is the deliverable that decides
the rest.

## Who

- **Maya** — persona 1, CORE. Not the requester, but the one the "Proven (nav)" bucket
  exists for: this is navigation, not the differentiator. Her session must not get slower
  or busier to add it.
- **Amara** — persona 3, Educated Depth-seeker. "Tenth Van Gogh this month gets an
  eye-roll... she wants Benin bronzes, Mughal miniatures, ukiyo-e." A theme/period facet is
  one of the few navigation tools that lets her route AROUND the Euro-canon greatest hits
  instead of scrolling past them — the range 0013/0018/0019 already fought to put in the
  pool becomes findable rather than just present.
- **Not the driver, named so this stays honest:** Zoe (persona 5, "pick a favorite
  genre... or specific color scheme") and Tomás (persona 4, wants a searchable museum) both
  ask for something adjacent to this. Both are explicitly **NOT baseline — New-slot
  candidates** in `specs/personas.md`. This story is scoped as **navigation on top of the
  existing browse surfaces**, not a new surface and not the New differentiator — citing Zoe
  or Tomás as the justification here would blur exactly the Proven/New line `CLAUDE.md`
  polices. If this ships and reads as "the personalization feature," that is scope creep
  past what this story actually is.

## Problem

**A reader who wants a kind of thing — portraits, landscapes, the Impressionist era — has
no way to ask for it.** Every browse surface (`/feed`, `/days`) is one undifferentiated
stream in curation order. The only navigation today is chronological (days) or
open-ended-scroll (feed).

- **Evidence:** gallery hallway tests, 2026-08-15/16 — `IDEAS.md`'s Considering entry
  records the observation directly: theme-seeking in session, participants asking for
  "portraits" and "landscapes from the impressionist era." **This is qualitative, not a
  count.** `user-research/0006-next-gallery-run-and-r3-targets.md` names this exact gap in
  the first run's own methodology — "how many sought a theme" is listed as a behavior the
  *next* gallery run should count as a denominator, because the first run didn't.
- **What's missing technically, measured 2026-08-19 against the committed pool:**
  - **No genre/subject field exists.** Nothing in the schema answers "is this a portrait."
  - `department` (33 distinct values) is museum-org labeling ("Asian Art", "European
    Paintings") — adjacent, not genre.
  - `dated` is present on 1993 of 2002 works **but free-text**: `"c. 951–953"`,
    `"second half 16th century"`, `"1837–38"`. A period facet requires a date parser —
    real work this story names now rather than discovers mid-build.
  - Work-level genre from any external taxonomy (Wikidata `P136`, Getty AAT, Iconclass)
    likely covers a minority — most museum works have no external-taxonomy entry.
    **Artist-level movement (Wikidata `P135`) is far more reachable**: story 0019 already
    built the Wikidata artist matcher (`Pool::Recognizable`). Release 2's dry-run decides
    between these routes by measurement, not assumption.

## Story

As a reader who came in looking for a kind of thing — a period, a genre — I want to filter
the browse surfaces by that, so the range this app already has stops being invisible past
whatever the curation order happens to show me first.

## Release 1 — the machinery (schema, UI, code)

Filter controls on `/feed` for two facets — **genre** and **period/movement** — backed by
new schema on `paintings`, with one structural rule: **a facet value renders as a control
only when at least one work in the pool carries it.** No dead-end chips, ever, by
construction rather than by data hygiene.

**Release 1 ships dark, and that is the design, not a defect.** The genre column ships
empty (no data source exists until Release 2's fill), so the genre control renders
nothing. The period facet may ship partially lit if the `dated` parser lands in Release 1.
This is the exact shape 0018 shipped in: the artist page existed and 404'd on Vermeer
until 0019 filled the pool. The machinery's correctness is testable with fixtures
regardless of the production fill.

In scope:
1. Schema: genre + period fields on `paintings` (exact shape — string vs join table — is
   a plan decision, with the `NOT_AN_ARTIST`/slug lessons from 0018 in view).
2. The `dated` → period parser (named subtask, with the messy real formats above as its
   test fixtures).
3. Filter UI on `/feed`: URL-addressable (a filtered view is a shareable, cacheable
   address), non-empty facets only.
4. Tests: parser against the real format zoo, filtering behavior, the non-empty-facet
   rule, and the existing feed tests staying green.

Deferred inside Release 1's plan: whether `/days` gets the controls too. `/days` is
chronological by design (`specs/0003-past-days`); the plan argues it in or out.

## Release 2 — the fill (data)

The 0019 pattern, deliberately: a dry-run coverage measurement **before** any backfill
commitment, producing a report that decides the rest.

1. Dry-run: for the committed 2,000-work pool, measure what each candidate route actually
   covers — Wikidata `P135` artist-movement via the existing 0019 matcher, work-level
   `P136` genre, Getty AAT/Iconclass mapping, department-derived heuristics. The numbers
   pick the route; the story does not.
2. Backfill the chosen route into the Release 1 schema.
3. **Facet floor set by measurement**, not asserted here: a facet with 1 work behind it is
   a dead end dressed as a feature, but whether the floor is 3, 5, or 10 depends on what
   the fill actually achieves. The floor becomes a `pool_quota_test`-style assertion (R1).
4. The coverage report joins `pool_report.md`, same as 0019's.

## Intake

- **Problem:** browse is one undifferentiated stream; a reader seeking a theme or period
  has no way to ask for it, and the pool has no data to answer that ask even if the UI
  existed.
- **Evidence:** gallery test 2026-08-15/16 (qualitative, unquantified — see above);
  `IDEAS.md`'s Considering entry, which already scoped the taxonomy constraint: facets
  from an **existing** taxonomy (Getty AAT / Wikidata / Iconclass — "don't invent one").
  Country facet explicitly lower priority (inference, no direct evidence) — parked.
- **Success signals (prediction, falsifiable, time-bound) — one per release, plus one
  this story does not own:**
  1. **Release 1, by Aug 22:** `/feed` accepts genre and period filter parameters,
     filtered views are URL-addressable, and no control renders for an empty facet —
     all pinned by Minitest against fixtures, independent of the production fill.
  2. **Release 2, by Aug 26:** the coverage dry-run report is committed, the chosen
     route backfills the pool, and every facet the UI offers clears the measured floor.
     **Wrong if** every candidate route covers only a small minority of the pool — that
     is a data problem no UI fixes, and the honest answer is to ship the facets that
     clear the floor and log the shortfall, not to invent a taxonomy (the banned move).
  3. **Not this story's gate:** whether a gallery participant actually uses the filters.
     That belongs to the next gallery run (`user-research/0006` — unscheduled, needs
     named contacts, not under this story's control). Recorded there as the validation
     follow-up, not here as a ship gate a research event could silently invalidate.
- **In baseline?** Yes — `CLAUDE.md` Better bucket item 6 ("curation range: beyond
  Euro-canon greatest hits") made navigable; `IDEAS.md` bucketed it "Proven (nav)." Not
  the New differentiator; that slot stays deferred to the Phase 3 gate per `BET.md`.

## Out of scope

- Country/region facet — named lower-priority in `IDEAS.md`, no direct evidence; parked.
- The New differentiator slot — still deferred to the Phase 3 `BET.md` gate.
- Any change to curation selection (`Pool::Curator`, `pool:curate`) — this story
  classifies and filters the existing committed pool; it does not re-curate it.
- Gallery-run validation of filter usage — the next run's protocol
  (`user-research/0006`), not this story's ship gate.

## Sequencing note — read before promoting past Draft

**`IDEAS.md`'s own entry for this said "Not before submission; first candidate after."**
As of this story's date (2026-08-19), the app has not been submitted to the App Store —
`SHIPLOG.md`'s most recent entries and `BET.md` still show all five thresholds at zero,
twelve days from the Aug 31 kill review. Starting this now is a deliberate deviation from
that sequencing call, made explicitly rather than silently — the owner's call, taken with
the gap named rather than reopened as if the note never existed. The runway cost is real:
Release 2's Aug 26 target leaves five days to the kill review.
