# 0018 — The names you know
Date: 2026-08-18
Lane: Full (core). Honest size: **2–3 days across two releases** — Release 1 (artist page)
is same-day; Release 2 (coverage fill) carries research + a re-curation whose feasibility
is proven by dry run, not assumed.
Status: Draft

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
  1. By Aug 20: artist name on `/` and `/feed` is a link when `artist` is present; the
     artist page lists that artist's works (1–5, per the ≤5/artist bar); unknown slug →
     404; `bin/ci` green including new integration tests.
  2. By Aug 24: ranked ~200-name list committed (`user-research/0007`, method + data +
     independent control); every name classified **covered / filled / walled /
     fails-bars**; every *fillable* gap filled with ≥1 work; `pool:curate` `verify!`
     passes with all 0013 bars intact (`test/lib/pool_quota_test.rb` green on the new
     manifest).
  3. Next gallery run (protocol: `user-research/0006`): artist-name taps land somewhere
     — count of dead-end taps drops to zero; recognizable-name misses only for names
     the coverage report classifies walled. **Falsified if** the re-curation cannot
     meet the 0013 bars at any TARGET (fill abandoned, reason logged), or if the next
     run still logs misses on names the report claims filled.
- **In baseline?** Yes — item 3 (browsable archive/gallery, execution-quality bar 6:
  "curation range beyond Euro-canon") plus the direction memo's pre-submission verdict.
  No exception argument needed.
- **R7 note:** moves **0 of 5** BET.md thresholds directly. 13 days to kill review; the
  binary is still not uploaded to App Store Connect. This story is scoped to *not*
  delay submission — Release 1 is same-day, Release 2 is bounded by the dry-run gate,
  and neither blocks the upload.

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
