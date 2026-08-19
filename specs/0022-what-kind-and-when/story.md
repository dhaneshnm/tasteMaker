# 0022 — What kind, and when

Date: 2026-08-19
Lane: Full (core). Honest size: likely > 3 days — see "What this story does not
decide yet" below; may split at eng review the way 0018/0019 did.
Status: Draft

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
  existing browse surfaces** (`/feed`, `/days`), not a new surface and not the New
  differentiator — citing Zoe or Tomás as the justification here would blur exactly the
  Proven/New line `CLAUDE.md` polices. If this ships and reads as "the personalization
  feature," that is scope creep past what this story actually is.

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
  *next* gallery run should count as a denominator, because the first run didn't. No
  participant-count evidence exists yet for how common this is; the observation is real,
  its prevalence is not measured.
- **What's missing technically:** the `paintings` table carries no genre/subject field.
  `department`, `medium`, and `culture` are adjacent (museum-side classification and
  material) but answer different questions than "is this a portrait or a landscape."
  Genre/subject classification does not exist anywhere in this pool today.

## Story

As a reader who came in looking for a kind of thing — a period, a genre — I want to filter
the browse surfaces by that, so the range this app already has stops being invisible past
whatever the curation order happens to show me first.

## Intake

- **Problem:** browse is one undifferentiated stream; a reader seeking a theme or period has
  no way to ask for it, and the pool has no data to answer that ask even if the UI existed.
- **Evidence:** gallery test 2026-08-15/16 (qualitative, unquantified — see above);
  `IDEAS.md`'s Considering entry, which already scoped the taxonomy constraint: genre
  facets from an **existing** taxonomy (Getty AAT / Wikidata / Iconclass — "don't invent
  one"), plus a period/movement facet. A country facet is explicitly named as lower
  priority (it would be inferred, not sourced, and nothing in the evidence asks for it
  directly).
- **Success signal (prediction, falsifiable, time-bound):** by **Aug 26, 2026**,
  `/feed` supports filtering by genre and by period/movement, sourced from a real external
  taxonomy (not hand-invented categories); every facet offered has **at least one** work
  behind it in the committed pool (an empty facet is worse than no facet — it is a dead
  end dressed as a feature); and a follow-up gallery/informal session (the "next run" named
  in `user-research/0006`) records whether any participant actually uses it to find a
  theme, turning this story's own founding observation into the first counted instance of
  it. **Wrong if:** the taxonomy mapping can only cover a small minority of the 2,000-work
  pool (most facets would be near-empty, which is a data problem no UI fixes), or if the
  gallery follow-up records zero uses of the new controls — either falsifies the bet that
  this gallery-test signal generalizes.
- **In baseline?** Yes — `CLAUDE.md`'s Better bucket item 6, "curation range: beyond
  Euro-canon greatest hits," and `IDEAS.md` already buckets this "Proven (nav)." Not the
  New differentiator; that slot stays deferred to the Phase 3 gate per `BET.md`.

## What this story does not decide yet

Named rather than silently deferred, because the "how" is a real unknown this intake
can't responsibly guess at:

- **Which taxonomy, and how it attaches to 2,000 already-curated works.** Getty AAT,
  Wikidata (`P136` genre / `P135` movement), and Iconclass all classify differently and
  none of the four museum APIs (`Pool::Sources`) hand over a clean genre field directly —
  this needs the same dry-run-before-commit measurement discipline story 0019 used for
  recognizable-artist coverage, not an assumption baked into this story. Plan-time work,
  not story-time.
- **Whether this reaches `/days` or only `/feed`.** `/days` is chronological by design
  (`specs/0003-past-days`); layering a second filter dimension onto it may or may not be
  in scope for a first release.
- **UI shape** — facet chips, a filter sheet, URL-addressable filtered views — deferred to
  `/plan-design-review`, since this has real UI surface unlike story 0021.

## Out of scope

- Country/region facet — named lower-priority in `IDEAS.md`, no direct evidence asking for
  it; parked, not built here.
- The New differentiator slot — still deferred to the Phase 3 `BET.md` gate, not invented
  here by implication.
- Any change to curation selection (`Pool::Curator`, `pool:curate`) — this story filters
  the existing committed pool; it does not re-curate it.

## Sequencing note — read before promoting past Draft

**`IDEAS.md`'s own entry for this says "Not before submission; first candidate after."**
As of this story's date (2026-08-19), the app has not been submitted to the App Store —
`SHIPLOG.md`'s most recent entries and `BET.md` still show all five thresholds at zero,
twelve days from the Aug 31 kill review. Starting this now is a deliberate deviation from
that sequencing call, made explicitly rather than silently — the user's call, taken with
the gap named rather than reopened as if the note never existed.
