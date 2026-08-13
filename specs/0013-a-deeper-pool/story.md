# 0013 — A deeper pool
Date: 2026-08-13
Lane: Full (core, target ≤ 2 days)
Status: Shipped

## Who
**Amara** — Educated Depth-seeker, persona 3 (`specs/personas.md`). 30, UX researcher in
London, Lagos-born, art-history minor she still misses. She reads every blurb critically,
finds over-famous works banal, and named the failure precisely: *"Repeated tired old Van
Goghs which are already super famous"* and *"almost a complete disregard for works outside
of the western canon."*

Secondary: **the curator (Dhanesh)**, who picks tomorrow's artwork out of whatever the pool
holds. A pool that has been read to the bottom is a curation decision already made.

Also served, indirectly: the positive reviews behind persona 1 say novices *and*
self-described experts both prize discovering artists they had never heard of. Range is not
a specialist feature; it is what the app is for.

## Problem
The pool is **110 paintings from one museum**, chosen before the personas existed.

The 110 were downloaded on 2026-08-03 as a seed for a feed that needed something in it. The
personas were written the same day, from the review teardown, and the pool has not been
revisited since. Nothing about the current selection was argued against persona 3, because
persona 3 did not exist when it was made.

### What the current pool actually is (measured, `db/seeds/mia_paintings.json`)

| | Count | Share |
|---|---|---|
| Total | 110 | — |
| European Art | 45 | 40.9% |
| Asian Art | 45 | 40.9% |
| Arts of the Americas | 19 | 17.3% |
| **Arts of Global Africa** | **1** | **0.9%** |
| Non-European / non-US | 48 | 43.6% |
| Dated 1900 or later | 17 | 15.5% |
| Most works by one artist | 3 | 2.7% |
| Images under 1600px | 0 | — |
| Carrying museum text | 110 | 100% |

**This is not the disaster the personas would predict, and the story must say so.** A
44% non-Western pool is not "disregard for works outside the western canon." Whoever picked
these picked well. Two things are still wrong with it.

**P1 — one museum is a ceiling on range, not a floor.** Every work comes from the
Minneapolis Institute of Art. Range is capped at whatever one institution in Minnesota
happens to own and photograph. Arts of Global Africa is **1 of 110** — and no amount of
re-curating inside MIA's holdings fixes a hole in MIA's holdings. Four sources measured
against each other is the only way to select rather than accept.

**P2 — 110 works is a pool that has already been read.** At one artwork a day, 110 is 3.6
months. `/feed` streams the entire pool with infinite scroll, so any reader who wanders once
has seen the whole collection Tondo will ever show them. Persona 1 opens this every morning;
persona 2 builds a collection *over years*. The product's own promise outlives its inventory.

**P3 — the schema believes there is only one museum.** `paintings.mia_id` carries a unique
index and is the validated identity of a work (`app/models/painting.rb:4`). `db/seeds.rb`
upserts on it. The attributing string "Minneapolis Institute of Art" is hard-coded in three
places — `app/views/daily/_day.html.erb:71`, `app/views/paintings/_page.html.erb:17`, and
the site meta description at `app/views/layouts/_head.html.erb:24`. A second source cannot
be added as data; it is a migration and a copy change.

### The constraint the sources impose, measured
Live counts pulled from all four APIs on 2026-08-13. **Paintings only, open licence, image
present:**

| Source | Paintings | Museum text on the work | Access |
|---|---|---|---|
| Met | 14,297 w/ images (PD subset TBC) | **none — the field does not exist** | CSV dump (git-LFS, 317 MB) + API, 80 req/s, no key |
| Cleveland | 3,956 | 100 of 100 sampled | API, no key, 1,000/page |
| MIA | ~3,782 | 110 of 110 in current pool | git clone, per-object JSON |
| AIC | 1,954 | 52 of 100 sampled | nightly JSON dumps, no key |
| **Total** | **~24,000** | | |

Two findings that change the shape of this story:

**F1 — the Met publishes no curatorial text.** Not thin text; no field. `objectDescription`
and `description` are absent from every object in the API and from the CSV. The Met is the
largest and most range-rich source on the list and **every work it supplies arrives mute**.

`specs/0005-museum-note-fallback` made that decisive: a pick with neither a hand-written
note nor museum text **is invalid and cannot be published**. So a Met-heavy pool is a pool
of days that can only ship on a morning the curator had twenty minutes. Story 0005 also
predicted *fewer than 1 in 5 published days run museum text through the Aug 31 kill review*
— text availability is a live, measured contract, not a nice-to-have.

**F2 — "paintings only" cannot serve Amara's own example.** She asked for Benin bronzes.
Bronzes are not paintings. Mughal miniatures and ukiyo-e are reachable; African
representation in a paintings-only pool will stay thin across all four collections, because
the African work these museums hold is overwhelmingly sculpture, textile and object. This
story does not solve that, and must not claim to.

## Story
As Amara, I want the daily artwork drawn from a pool deep and wide enough that I meet
painters I have never heard of instead of the tenth Van Gogh, so that I keep reading past
the first week.

As the curator, I want a queue I cannot exhaust and a selection I can defend against the
personas, so that tomorrow's pick is a choice rather than what is left.

## Intake
- **Evidence:** `specs/personas.md` persona 3, verbatim — *"repeated tired old Van Goghs"*,
  *"almost a complete disregard for works outside of the western canon"* — plus the positive
  reviews under persona 1 showing discovery is prized by novices and experts alike.
  Supporting measurement, all taken 2026-08-13: the pool table above (our own data), and the
  live source counts (four APIs, queried directly). `CLAUDE.md` Better bar 6 — *curation
  range: beyond Euro-canon greatest hits* — is the standing requirement this serves.
  Countervailing evidence, stated: **no user has asked for this.** BET.md's five
  conversations stand at zero. The argument is a teardown of a competitor plus arithmetic
  about our own inventory, and that is weaker than a user saying it.
- **Success signal (prediction), hand-checkable on ship day, no analytics required:**
  1. Pool is **≥ 2,000 paintings from ≥ 4 sources**, no single source above 50%.
  2. **No artist holds more than 5 works** (0.25%). Today's ceiling is 3 of 110, or 2.7% —
     an order of magnitude tighter, and the direct answer to "the tenth Van Gogh."
  3. **Non-European/non-US share ≥ 45%** — at or above the 43.6% we have today. This story
     may not regress range while multiplying volume.
  4. **≥ 15% dated 1900 or later** — holds today's 15.5%, and answers persona 5's *"all I
     get are paintings from before 1900AD."*
  5. **≥ 10% highlight/boosted works, and ≤ 10%** — the famous ones stay in the pool as
     anchors and never dominate it.
  6. **≥ 70% of the pool carries museum text**, and every text-less work is visibly flagged
     in the picker. Under that line, story 0005's contract quietly converts into a backlog
     of unpublishable paintings.
  7. **Every stored image has a longest edge ≥ 1600px**, matching today's floor of 1920px.
     Better bar 7 (zoomable, high quality) is not traded for count.
  8. **Stored images ≤ 1.2 GB on disk**, against CX22's 40 GB. `decisions/0009` predicted
     ~1 GB for 2,000 and made that the basis for choosing the box.
  9. `/feed` first paint and scroll are no worse than at 110 works, on a phone.
  10. `bin/ci` green, including a test that fails if any of 1–8 stops holding.
- **In baseline?** Yes — it is the input side of **Proven item 1** (*one artwork per day,
  curated*) and the standing **Better bar 6** (*curation range*). It adds no reader-facing
  feature, no new screen and no new surface. It does **not** spend the "New" slot, which
  stays deferred to the Phase 3 gate per `BET.md`.
- **R7, stated plainly and against my own interest:** 110 works is **3.6 months** of dailies.
  The kill review is **Aug 31 — 18 days**. The pool is not what is stopping this bet, and
  finishing this story moves **none** of BET.md's five numbers. The scoreboard is 0 live /
  0 posts / 0 keywords / 0 conversations / 0 installs; the App Store submit target is
  **tomorrow, Aug 14**, and `config/deploy.yml` still carries two `CHANGEME` values. This
  story is an input metric. **Recommended sequencing: it ships after the box is deployed and
  the app is submitted, not before.** If it goes first, it is builder's gravity with a spec
  attached.

## Acceptance

### The pool
- A curated pool of **2,000 paintings**, drawn from Met, Art Institute of Chicago,
  Cleveland and MIA, satisfying every numeric bar in the success signal above.
- **Selection is programmatic and re-runnable, not hand-picked.** At 2,000 the quota table
  *is* the curatorial act; it lives in the repo, is executable, and prints its own report.
- The report is committed with the pool: counts per source, per region, per era, per artist
  ceiling, text availability, and every bar's pass/fail. A quota that cannot be shown to
  hold has not been met.
- **Dedup across sources.** The same work held by two museums enters once. Near-duplicates
  by the same artist are capped by the per-artist ceiling, not by hand.
- Works whose museum text is a bare tombstone (dimensions, provenance, no sentence about
  the work) count as **text-less**, not as text. Bar 6 is a claim about something a reader
  can read.

### Metadata mirror
- Metadata for **all ~24,000 open-licence paintings** across the four sources is mirrored
  locally, from bulk dumps where they exist (Met CSV, AIC nightly JSON, MIA git clone) and
  by paged API only where they do not (Cleveland).
- **Image bytes are downloaded only for the selected 2,000.** The mirror is the curation
  surface; it is not a picture library. 600K images is 290 GB against a 40 GB box, and a
  full-paintings byte mirror is 11 GB for ~22,000 works we will not publish before the kill
  review — both are infrastructure for later and both are out.
- Re-curating later must not require re-downloading anything but the newly selected images.

### Schema and attribution
- `paintings` identifies a work by **(source, source_id)**, not by `mia_id`. Existing rows
  migrate to `source: "mia"` with no data loss and no re-download of the 110 images already
  on disk.
- Attribution is **per source**, everywhere it appears: the day page's museum-text credit
  (`daily/_day.html.erb:71`), the painting page's collection link
  (`paintings/_page.html.erb:17`), and the site meta description
  (`layouts/_head.html.erb:24`), which today promises a single museum by name.
- **Each source's image terms are recorded per row, not assumed.** MIA's repository states
  plainly that its images are *not* under the same licence as its metadata. Met, AIC and
  Cleveland images are CC0/PD for the works we select; MIA's are the exception that must be
  checked rather than inherited. If MIA image terms do not clear, MIA drops to metadata-only
  and the other three carry the pool — the quota table must survive that outcome.

### Operations
- Ingest is **idempotent and resumable**. A failed or interrupted run resumes; it does not
  restart 2,000 downloads. `db/seeds.rb`'s existing "only download what is missing"
  behaviour is the standard to keep.
- Ingest is **polite by default**: AIC's 60 req/min anonymous limit is the binding floor and
  is respected without being the run's wall-clock (bulk dumps exist precisely for this).
- The run states its own numbers when it finishes: fetched, skipped, deduped, rejected by
  which bar, bytes on disk.
- Feed order is regenerated across the whole pool, deterministically, as `db/seeds.rb`
  already does with a seeded shuffle.
- The seed manifest stays reproducible from the repo. If 2,000 records make a single
  committed JSON unwieldy, the plan says what replaces it — a checked-in manifest of
  identities plus a fetch step is acceptable; an unreproducible pool is not.
- `bin/ci` green, with the quota bars enforced by a test (R1 — the rule and its enforcement
  land in the same unit of work).

## Out of scope
- **Everything that is not a painting.** The Met alone holds ~502,000 objects; sculpture,
  prints, textiles, arms, furniture and photography are all out. This is the decision taken
  on 2026-08-13 and it is what keeps the story to ~24,000 candidates instead of 700,000.
  It also means Amara's Benin bronzes are not served by this story (F2) — that is a known,
  named gap, not an oversight.
- **A full image mirror of all ~22,000 paintings** (11 GB, 6–10 hours). Considered and
  rejected the same day: it stores 20× what we will publish before the kill review, and
  the metadata mirror already buys the only thing it was for — offline re-curation.
- **Smithsonian, NGA, SMK, Rijksmuseum, Getty, Walters.** All viable, all documented in this
  session's source survey. Four sources clear every bar; a fifth is added when a bar fails,
  not because the list exists. Rijksmuseum and Getty additionally cost a second resolve call
  per object (linked data), which is the most expensive integration on the list.
- **Harvard (non-commercial API terms) and Brooklyn (CC BY-NC images).** Licence-excluded,
  not deferred.
- **Europeana and Wikimedia as ingest sources.** Mixed per-record licences and undisciplined
  metadata. Usable to *discover* a gap, never to fill one.
- **Any generated text.** `CLAUDE.md` bans AI-written artwork descriptions and
  `specs/0005` fixed the only permitted fallback as the museum's own words or nothing.
  A pool of 2,000 does not become a reason to loosen this; it is the exact pressure the ban
  exists to resist.
- **Storing AIC's `color` field.** It arrives free in the same dump and is the obvious lever
  for persona 5's colour-matched widget — which is a **New-slot candidate deferred to the
  Phase 3 gate**, not a thing being built. A schema column for an unbuilt feature is
  infrastructure for later. The local mirror retains it at zero cost; the database does not
  gain a column until something reads it.
- **Search, artist directory, browse-by-era, browse-by-region.** Persona 4 (Tomás),
  explicitly not baseline. A bigger pool makes the case for it louder and still does not
  authorise it.
- **Any change to how a day is chosen, published, or rendered.** This story fills the
  queue. `DailyPick` and every reader screen behave exactly as they do today.
- **Publishing 2,000 days.** The pool is a curation queue, not a content promise. At one a
  day, 2,000 works is 5.5 years, and every published day still needs the curator's own
  sentence or the museum's.
