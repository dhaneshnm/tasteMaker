# 0018 — The names you know
Date: 2026-08-18
Lane: Full (core). Honest size: **1.5–2 days, Release 1 only.**
Status: Draft — **scope reduced 2026-08-18 by `/plan-eng-review` (E5).**

**Release 2 (the coverage fill) left this story** and sits at the top of `IDEAS.md`
Considering. The original "same-day" estimate was not credible: it predated the migration
and backfill, the `_artist_line` extraction across two shipped screens, the
`NOT_AN_ARTIST` deny-list, the accent-preference rule, and six blocking fixture rows.
Corrected to 1.5–2 days (X9) — a fact about the work, not a choice about it.

## Who

- **Tomás** — persona 4, Reference Browser (`specs/personas.md`). Treats the app as a
  searchable museum: "It's too hard to discover artists… should be set up like going to
  an in-person museum." Wants everything by an artist he just discovered.
- **Maya** — persona 1, CORE (`specs/personas.md:10`). Not the driver, but the gallery-test
  participants searched *recognizable* names — greatest-hits level, which is Maya's
  knowledge level, not Tomás's. The observed user sits between the two: Tomás's behavior
  at Maya's expertise.
- **Amara** — persona 3, Educated Depth-seeker — the guard rail, not the requester. A
  recognizable-name fill skews Euro-canon ("Repeated tired old Van Goghs"). Her bar: the
  fill must not regress the range bars 0013 fought for.
- Not in this story: Jordan (favorites contract untouched), Priya/Zoe (Phase 3 gate).

## Problem

**Artist names are dead ends, and the names people already know are missing.** Gallery
hallway tests, 2026-08-15/16, 7 participants (`user-research/0006`, source memo
2026-08-14):

- **P1 (Observed):** participants tapped artist names on works and nothing happened.
  Every surface renders the artist as plain text (`paintings/_painting.html.erb:8`,
  `daily/_day.html.erb:144-149`, `days/_row_body.html.erb:13`). The mental model —
  museum wall label → more by this artist — is real and currently punished.
- **P2 (Observed):** participants looked for artists they already knew and didn't find
  them. The datum is *coverage of recognizable names*, not raw count — the 10–20K bulk
  target stays parked (`IDEAS.md`; aggregation is the settled trap).
- **The constraint that reshapes P2:** the four wired sources (Met/AIC/CMA/MIA) publish
  public-domain works only. A lay-recognized name list is heavy with 20th-century
  artists still under copyright (Picasso, Kahlo, Dalí, O'Keeffe…). Those names cannot
  be filled from CC0 sources at any effort level. The fill covers what CC0 *can* reach;
  the rest is documented as walled, never faked.
- **What is already decided and does not reopen:** pool quota bars (0013 — non-Western
  ≥45%, region ≤25%, ≤5/artist, text ≥70%); museum-note fallback (0005 — no per-work
  hand-written blurb required, so the fill costs zero mandatory editorial); banned
  ingest sources (0013).

## Story

As **Tomás**, I want to tap an artist's name on any work and see everything Tondo holds
by that artist, so the collection behaves like a museum instead of a slideshow.
As **Maya**, I want the artists I already know to be there when I look for them, so the
collection feels credible.
As **Amara**, I want the famous-name fill to arrive without draining the range, so the
pool doesn't become the leader's Euro-canon greatest hits.

## Intake

- **Problem:** P1 + P2 above.
- **Evidence:** Observed in-session behavior, gallery tests 2026-08-15/16 — the only two
  build items the direction memo marks "build before submission." Both promoted from
  `IDEAS.md` (top two Considering entries).
- **Success signal (prediction, falsifiable and time-bound):**
  Rewritten 2026-08-18 (X7): the original #2 and half of #3 belonged to Release 2, and
  #3's "drops to **zero**" was unachievable by Release 1 alone — a prediction guaranteed
  to be falsified by scope rather than by the hypothesis, which under R4 measures nothing.

  1. By Aug 20: the artist name links on `/feed` and `/days/:date` whenever the work has a
     usable artist slug, and renders **dim and unlinked on `/`** (public page, walled
     target). The artist page lists that artist's works — **1 to 9**, since the measured
     max is 9, not the ≤5 the original claimed. Unknown slug → 404. `bin/ci` green.
  2. Next gallery run (protocol: `user-research/0006`): **dead-end artist-name taps drop
     to zero on `/feed` and `/days/:date`.** Recognizable-name misses are **unchanged and
     expected** — that is Release 2's job. **Falsified if** participants still tap artist
     names on those two surfaces and nothing happens, or if they reach an artist page and
     cannot get back to where they were.
  3. **Not instrumented, stated plainly.** Session gate 6 (analytics, error tracking) is
     unmet, so nothing measures whether a reader ever opens `/artists/:slug`. The gallery
     run is the only instrument this signal has.

  Moved to the Release 2 spec: the ranked ~200-name list, the covered/filled/walled/
  fails-bars classification, the `pool:curate verify!` gate, and the walled-name clause.
- **In baseline?** Yes — item 3 (browsable archive/gallery, execution-quality bar 6:
  "curation range beyond Euro-canon") plus the direction memo's pre-submission verdict.
  No exception argument needed.
- **R7 note — corrected 2026-08-18, and the correction is the important part.** Moves
  **0 of 5** BET.md thresholds. The original claim that this story is "scoped to *not*
  delay submission" was **false by construction**: R5 means WIP = 1, so there is no
  parallel track — this story *is* the thing in flight.

  What the outside voice put on the record, verified against the repo: `BET.md:11` set
  "app live by **Aug 14, 2026**" and that date passed four days ago with the binary never
  uploaded. All five thresholds sit at zero. There is no `solid_queue` in the `Gemfile`,
  only `application_job.rb`, and no APNs anywhere in `ios/` — so **Proven-baseline items 1
  (the daily publish job) and 2 (the daily push, one of only two moats `CLAUDE.md` names)
  do not exist.** `DailyPick.current` holds the last published day indefinitely.

  The owner was shown all of this and chose to ship Release 1, then submit. Recorded
  rather than re-argued — but recorded, because the Aug 31 kill review reads this file.

## Non-goals

- Artists index/directory page (browse all artists) — not observed; only work → artist.
- Artist bios or per-artist editorial. Museum copy or nothing (0005 contract).
- Normalized Artist model / join table — 1,019 free strings group fine by exact match;
  a table is infrastructure-for-later until something needs it.
- Search, theme/period filters (`IDEAS.md`, queued separately).
- Bulk expansion to 10–20K (settled trap, `IDEAS.md` Parked).
- Artist links inside archive/collection rows — the whole row is already one `<a>`
  (`days/_row.html.erb`); nesting anchors is invalid HTML. Feed + day page only.
- New compass surface — the artist page is reached from work labels, not the compass
  (`ApplicationHelper::COMPASS` stays four).
