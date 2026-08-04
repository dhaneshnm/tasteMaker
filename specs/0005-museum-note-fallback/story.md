# 0005 — The day the note isn't written
Date: 2026-08-04
Lane: Express (same-day, reversible)
Status: Built 2026-08-04 — spec written after the fact, see Process note

## Who
**The curator (Dhanesh).** One person, publishing daily, with a day job that is building
this and eleven other things. Also **Maya** (persona 1), who opens the app expecting
something to read whether or not the curator had twenty spare minutes yesterday.

## Problem
`blurb` was required, so a day could not be scheduled without a written note. In practice
that means one of two things happens on a busy week: the queue runs dry and the front door
holds a stale day over, or the curator types filler to satisfy the validation. Both are
worse than the museum's own text, which is accurate, already in the database, and CC0.

The observed case: four of five published days in the dev queue carried placeholder text
("A note written for dogfooding this screen"), because something had to go in the field.

## Story
As the curator, I want a day with no note to run the museum's own text, marked as theirs,
so that a week I could not write does not leave the app with filler or a stale front door.

## Intake
- Evidence: direct instruction from the curator, 2026-08-04, after seeing placeholder text
  on the front door. Supporting: 110 of 110 seeded paintings carry museum descriptions, so
  the fallback is available on effectively every day.
- Success signal (prediction): fewer than 1 in 5 published days run museum text through the
  Aug 31 2026 kill review — checkable at a glance on the curator's queue, which now states
  the ratio. Above that line the fallback is not an escape hatch, and `decisions/0004` says
  what to do about it.
- In baseline? It modifies Proven item 1. The hand-written note stays the default and the
  promise; this is the bounded exception, attributed on the page so a reader is never
  misled about whose voice they are reading.

## Acceptance
- A pick can be saved with no note.
- A day with no note renders the painting's museum description, clamped like the archive's,
  under "From the Minneapolis Institute of Art" in the metadata treatment.
- A day with a note renders it whole, unclamped, with no attribution line.
- A pick with neither a note nor museum text is invalid, and the error says why.
- The curator's queue distinguishes a museum day from a zero-word day, and states the
  running ratio against the 20% line.
- The painting picker marks paintings that have no museum text to fall back on.
- Blank notes normalise to NULL, so the ratio is countable with one query.

## Out of scope
- Generating any text. `CLAUDE.md` bans AI-written artwork descriptions; the fallback is
  the museum's own words or nothing.
- Changing the PWA manifest or meta description, which still promise a hand-written note.
  See `decisions/0004` for why that is deliberate.
- A second museum's attribution string. All 110 works are MIA today; adding a `source`
  column before a second source exists is infrastructure for later.
- Any change to `/feed`, which already showed museum copy this way.

## Process note
Built directly on the curator's instruction mid-session, before this spec existed — which
is backwards per the build flow in `CLAUDE.md` ("Do NOT build: any feature without a spec")
and was caught by `/code-review`, not by me. The spec is written after the fact rather than
pretended into the past. `decisions/0004` carries the position and the falsifiable
prediction; this file carries the intake fields that were skipped.
