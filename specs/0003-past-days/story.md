# 0003 — The days behind you
Date: 2026-08-03
Lane: Full (core, target ≤ 2 days)
Status: Draft — awaiting /plan-design-review

## Who
**Maya** — Daily Ritual Learner, persona 1 (`specs/personas.md`). 33, pediatric nurse in
Columbus, three 12-hour shifts a week. On shift days the app does not get opened.
Secondary: **Amara**, persona 3, who wants to go back to the Hiroshige from last week
because she is now reading about ukiyo-e and wants to look at it properly.

## Problem
Maya misses days — not occasionally, structurally. Three 12-hour shifts a week means
three days she does not open anything. Today the artwork she missed is simply gone: the
front door shows the latest published day and there is no way to reach any other one. A
daily ritual that erases what you miss punishes exactly the person it is for, and it
quietly tells her the app is a stream rather than a collection worth keeping up with.

The one screen that lists past days today is the curator's queue, behind HTTP Basic auth.
`/feed` is not this: it browses the 110 MIA works we hold, in no relation to any day.

## Story
As Maya, I want to look back at the days I missed and re-open the ones I liked, so that a
week of shifts does not cost me the week of art.

## Intake
- Evidence: **Proven baseline item 3** (`CLAUDE.md`), validated in the 17-app teardown.
  The persona evidence is structural, not a quote: persona 1's own schedule (three
  12-hour shifts) guarantees missed days, and persona 1 is ~8 of 31 reviews analysed.
  Persona 3 re-reads and cross-references; persona 2's whole behaviour is keeping art
  they found rather than consuming it once.
- Success signal (prediction): after ship, any published day is reachable in **two taps**
  from the front door and has its own URL that renders the same page today's does, dated
  honestly. A day that has not arrived in Eastern time is not reachable by URL guessing.
  Checkable on the day it lands, by hand, without analytics.
- Honest caveat: on ship day this screen holds **one** day. Its value compounds — at 30
  days it is the reason to keep the app installed through a bad week; on day one it is
  nearly empty. Building it now is a bet that the pool fills, and the empty state has to
  be good enough to not look broken while it does.
- In baseline? Yes — Proven item 3.

## Acceptance
- A list of published days, newest first, reachable from the front door.
- Each entry shows its date, the artwork, the title and the artist.
- Tapping an entry opens that day: the same layout the front door uses, dated with that
  day's own date, with the curator's note in full and zoom working as it does everywhere.
- Every past day has its own shareable URL. Reloading it revalidates and costs a 304 when
  nothing changed.
- A day that has not arrived yet is not in the list and its URL does not resolve — the
  queue can be filled weeks ahead without leaking (same rule as `DailyPick.current`).
- A malformed or unscheduled date does not error; it 404s.
- Before the first day is published, the list says so in the product's own voice rather
  than showing an empty page.
- The front door still shows today first. Nothing about the daily ritual changes.

Added at design review (2026-08-04):
- The way in is the date in the front door's masthead, and it only becomes a link once
  there is more than one published day — no door onto the room you are standing in.
- A past day carries `← Previous day` / `Next day →`, bounded by the published range, so
  catching up on three missed days is a walk rather than three round trips to the list.
- One day has exactly one URL: `/days/<today>` redirects to the front door.
- A date with no artwork lands on a linen 404 in the product's voice, not the stock Rails
  page — this is the first story that routes people to a 404 by design.

## Out of scope
- Calendar / month-grid picker. A list is the smallest thing that answers "what did I
  miss"; a calendar is a different question and needs its own evidence.
- Search, filtering by artist, or "on this day last year".
- Favourites (baseline item 4, its own story) — including any "save" affordance here.
- Pagination, until the list passes the trigger written into the plan. One day per day
  means the trigger is months away; building it now is infrastructure for later.
- Any change to `/feed`, the museum-collection browser. Different surface, different job.
- Push notifications deep-linking into a past day (baseline item 2, its own story).
