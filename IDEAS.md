# IDEAS.md — idea/feature queue

Everything not being built right now. Flow: CLAUDE.md Build flow step 0. Not a spec —
intake fields (evidence, success signal, lane) happen at promotion to
`specs/NNNN-slug/story.md`.

**Not for:** outreach/research logistics (gallery-run protocol, named R3 targets). Those
feed BET.md's conversation threshold — track in `user-research/`, never as queue rows.

## How to use

- **Capture:** one dated line under Inbox — `- YYYY-MM-DD — <idea> (who/where)`.
  No bucket, no rationale, no ID. Done in seconds.
- **Triage (batch, not live):** move Inbox lines to Considering (ordered — top = next
  pick) or Parked (reason required — the reason says dormant vs dead).
- **Pick:** WIP slot opens (R5) → take the top Considering entry → promote per Build
  flow step 1 → move the entry to Promoted with its spec number.
- **Bucket tag** = Proven / Better / New (CLAUDE.md build order). `—` until triage
  assigns one; unassigned = triage TODO, not a fourth lane. One New slot total — the
  slot is named in `BET.md` at the Phase 3 gate, not here.

## Inbox

- 2026-08-31 — Link work titles on `/artists/:slug` and `/feed` to `/paintings/:id` once story 0030 ships the page. Titles are dead text today; after 0030 every work has an address, so the link is a one-line `link_to` per surface. Named out-of-scope in `specs/0030` to keep the bug-fix lane Express; carries the story-0018 caution (never from `/`, which is public — see the root-is-public rule). (0030 eng review)
- 2026-08-21 — Hand-curated "wings" on `/feed`: named tradition+period combos with a written line ("Mughal miniatures"). The 7-star from 0027's Chesky ladder; borders the New slot, needs evidence (0027 non-goals)
- 2026-08-21 — Remember the last `/feed` filter per device. 0027 non-goal; no evidence anyone returns to a filter
- 2026-08-21 — Pinned face per wing on `/feed/index` (admin picks the work that stands for Mughal/Portraits/…). 0027 ships curation-order-first as the face; pin only if a default embarrasses a wing (0027 plan step 1)
- 2026-08-20 — Facet-usage receipt: instrument/query whether readers tap ?genre= / ?tradition= before the expansion story starts (0025 eng review F12, outside voice — every facet success signal so far is an input metric)
- ~~2026-08-27~~ **Fixed 2026-09-01, per this entry's own prescription** — it
  started blocking CI (2 of 3 runs): the geometry reads are now one atomic
  JS snapshot, no stale handles; the keyboard-focus sibling flake got
  Capybara's retrying `:focus` matcher in the same pass. Original entry:
  `test/system/favorites_test.rb`'s "the compass separates its four doors" is flaky, not broken: reran it 5 times in isolation during specs/0028 follow-up work, saw `StaleElementReferenceError` (line 158, reading `.native.location.y` off elements captured a moment earlier) twice and a completely unrelated assertion failure once, clean 2 of 5. Pre-existing (reproduces against unmodified `main`, unrelated to any pool/content change) — a real browser timing race, not this story's regression. Worth a `assert_no_changes`/re-query-before-read fix if it starts blocking CI regularly.
- 2026-08-27 — Met CSV mirror may be missing rows the live Met object API has. `tmp/pool/met.json` (pulled 2026-08-13 from the bulk GitHub CSV) carries zero rows for Emanuel Leutze, but `collectionapi.metmuseum.org/.../objects/11417` ("Washington Crossing the Delaware") lives, is tagged `isPublicDomain: true`, and is attributed to Leutze today. Worth a spot-check next `pool:mirror` re-run: is the CSV export stale, or is Leutze filed under different metadata the CSV parser doesn't catch. (specs/0028 plan)
- 2026-08-27 — A fifth CC0 museum mirror (NGA DC, Getty, or Rijksmuseum, all confirmed CC0-granting on their own object pages) would close the two names story 0028 found genuinely absent from the current four (Catlin, Leutze) plus likely others. Real option, not decided — needs its own `decisions/` entry (new fetcher, rate limits, region mapping) and evidence that "absent" names are a real reader complaint, not just a research artifact's finding. (specs/0028 story, "Non-goals")
- 2026-08-20 — A pinned work whose plate download previously failed (image_url_full present, `image.attached?` false — `db/seeds.rb`'s fetch failure path warns and moves on) has no path back to detection: `pool:curate`'s pins skip the plate resolver by design (0026, plates "already cached"), so a work that was NEVER actually cached ships silently forever. Not built now — the deliberate skip is what removed ~2,000 HEAD requests/run, and no such row is confirmed to exist today (0026 code review, latent not observed). If a blank-plate report ever surfaces a pinned work, this is the first place to look; a fix would be a LOCAL (no-network) `image.attached?` check against the live DB before skipping, not a full re-verify.

- 2026-08-28 — `Pool::FeedInterleave.round_robin` (story 0029) duplicates `Pool::Curator#fill_remainder`'s "drain N queues, one per queue per round, drop empties" loop rather than sharing it — the two differ only in whether a draw can be rejected (Curator's `take` can fail a cap check; FeedInterleave's never rejects), which is exactly parameterizable as a shared `Pool::RoundRobin` primitive. Not extracted now (`/simplify`, story 0029): would mean touching `Curator#fill_remainder`, a stable, heavily-tested, heavily-commented selection method, for a same-story DRY win outside this story's actual scope (ordering, not selection). Worth doing if a third caller of this shape shows up.
- 2026-08-28 — `Pool::Tradition.from_strings`'s `ukiyo_e?` path (`Pool.word_match?`) compiles a fresh interpolated `Regexp` per `UKIYO_E_ARTISTS` name per call instead of precompiling once, the exact anti-pattern `Tradition::PATTERNS` was precompiled to avoid for its own table (`/simplify`, story 0029, efficiency lens). Pre-existing, not introduced by 0029 — but `pool:interleave`'s `Pool::FeedInterleave.derive` now calls `Tradition.from_strings` a second time over the same ~2,340 rows `db/seeds.rb` already calls it over once, roughly doubling this cost per curation cycle. Fix: precompile `UKIYO_E_ARTISTS` into one alternation `Regexp` or a frozen array of compiled `Regexp`s, same treatment `PATTERNS` already gets.

### Canonicalise the artist string so one artist is one page — Better (range)

Source: `specs/0019-the-coverage-fill/plan.md` C4b, 2026-08-19. Deferred there on purpose.

Museums spell one artist several ways and each spelling becomes its own `/artists/:slug`
page. Measured over the mirrors: Goya's 29 works sit on four pages, Rembrandt's 42 on
three, Kandinsky's 8 on two ("Vasily" and "Vassily"). Story 0019 makes the *fill*
concentrate on each name's deepest page, which stops it building thin pages, but it does
not merge the pages that already exist.

The fix rewrites stored attribution data for every reader, so it needs its own evidence
and its own story — not a line inside a re-curation. Depends on 0019.

### Wikidata P135 artist-movement fill for genre — Better (range)

Source: `specs/0022-what-kind-and-when/plan.md`, Release 2 eng review, 2026-08-19.
Deferred there on purpose.

124/2,000 pool works route through an artist the existing 0007 QID list already
resolves, and 98% of those QIDs (95/97 sampled) carry a real Wikidata `P135` movement
claim once reconciled — the reconciliation coverage is the bottleneck, not the data.
Not built in Release 2 because folding it in broke that release's own CMA/MIA-has-no-genre
invariant (`P135` is artist-based, not museum-based, so it reaches CMA/MIA works too
unless explicitly scoped away from them) and needs a genuinely new Wikidata SPARQL
client — nothing in `lib/` or `app/` talks SPARQL today; the only precedent is a
throwaway Python research script.

If ever picked up: scope the route to AIC/MET works only (or re-derive a fresh
CMA/MIA invariant that accounts for it), build the SPARQL client as a first-class
`lib/pool/` module reusing `Pool::Sources.get_json`'s retry/backoff idiom, and batch the
QID lookup in one `VALUES` clause — the dry-run already proved that query shape works
live against Wikidata's public endpoint.

**Re-sized by `user-research/0008`, 2026-08-20:** the 6.2% (124-work) figure was the
floor from the 200-name QID list alone. A top-80-artist sample puts P135 reach at
≥70% of works by attributed top artists, and movements are the highest-demand theme
vocabulary readers look up (Impressionism 466K annual pageviews vs portrait 57K). The
payoff is a movement facet, not a genre patch — and the hard part (artist
reconciliation) is the same work the canonicalisation entry above needs. The two
entries plus 0008's evidence are probably one story.

### Rejected-memory for machine picks — — (untriaged)

Source: eng review of `specs/0023-the-standing-order`, outside voice finding O7,
2026-08-19. Deleting an auto-picked future day is a re-roll, not a veto — the machine
refills the date next morning, possibly with the same painting (random order, no memory
of rejections). 0023 documents swap-in-place as the veto and says so in the destroy
flash. If re-rolls repeating rejected works annoys in practice, a small "not this one"
memory earns its keep; until the curator actually hits it, it is infrastructure for
later.

## Considering — top = next pick

- 2026-08-31 — **Guided sit, shapes B/C** (region pan + curator context lines +
  full capture; protocol-in-app). Held back deliberately: B waits for shape A's signal
  and authoring-cost evidence; C waits for the finished 15-sit dogfood
  (`user-research/0010`) — its prompt ranking, surviving duration, and blind-spot
  tally ARE C's spec inputs. Owner directions already locked (2026-08-31 session):
  capture end-state = text + audio + uploads (audio favored — eyes stay on painting;
  no transcription until demanded); notes account-backed behind 0015 sign-in;
  region lines carry context (owner's blind-spot tally: context = the gap looking
  can't close). B/C border the New slot (BET.md, named at Phase 3 gate); supersede/
  unblock Parked "Art coach" — self-logged delta removes its LLM-grading block.
  Gate-6 note: user content raises privacy labels + backup burden.

## Parked — reason required

- **Bulk expansion to 10–20K works** — settled fact (CLAUDE.md): aggregation is the
  documented strategic trap — do not reopen; no user signal unparks this. Inference
  only, no user evidence; ArtDay has 300K works. Bounded coverage fill
  (`specs/0019-the-coverage-fill`) is the in-scope alternative.
  (2026-08-14 memo)
- **Similar works on keep** (metadata similarity vs vector image search) — Better.
  Zero gallery-test evidence. Vector embeddings before a proven need =
  infrastructure-for-later by name. Needs a user signal. (2026-08-14 memo)
- **Social / invite mechanics** — no evidence from any Tondo test; investigate-only.
  Extract mechanics (Nikita Bier: invite flows, shareability), demo thesis rejected.
  Output would be a `decisions/` note, not a feature. (2026-08-14 memo)
- **Art coach** (gaze → record → delta → dialogue) — New-slot *candidate*; the slot
  itself is still Deferred in `BET.md` and gets named there at the Phase 3 gate (R4
  `decisions/` entry then). Blocked: step 3 as sketched is LLM-graded free text — the
  anti-pattern vs the answer-key framework; needs keyed multiple-choice / spatial
  hit-test redesign first. Validation plan open. Latent demand proven at scale
  (YouTube); zero expressed demand for interactive/paid. (2026-08-14 memo)

## Promoted

- 2026-08-31 — Guided sit, shape A: the look-first gate → `specs/0032-sit-with-it`.
  Front door's note starts folded behind a soft 60-second invitation; reveal never
  locks; signed-in readers get one optional first-impression line (account-backed,
  turbo-frame idiom). Better-bucket sequencing, no New-slot claim. Evidence:
  `user-research/0009` (DM exchanges) + `user-research/0010` (protocol dogfood,
  5 sits avg 12 min saturation). Shapes B/C stay in Considering above.
- 2026-08-21 — `/feed` filter UI, owner-rated 3/11 → `specs/0027-the-wing-label`.
  Same-day promotion: WIP slot open after 0025/0026, and the facet stories' three days
  of work are unusable at 3/11. Target 6/11 — the 5 (one line, counts, scoped values,
  floor 20, summary + clear) plus the 6 (editorial-voice label, named coverage).
- 2026-08-20 — Tradition facet from culture strings → `specs/0024-the-named-traditions`.
  First of the three-story decisions/0016 sequence (findability → findability →
  expansion).
- 2026-08-20 — Genre fill v2: title/description keywords → `specs/0025-what-the-title-says`.
  Second of the sequence; rewrites the CMA/MIA-never-genre invariant on purpose.
- 2026-08-20 — Theme-gap re-curation → `specs/0026-the-wider-pool`. **Mechanism
  inverted on promotion by owner decision (decisions/0016):** the Inbox entry
  proposed swap-within-2,000; the owner chose additive expansion to TARGET 3,000
  with swaps as the recorded fallback. Evidence carried over; mechanism did not.
- 2026-08-18 — Artist page + recognizable-artist coverage fill →
  `specs/0018-the-names-you-know` (Release 1 only; Release 2 split out by eng review E5)
- 2026-08-19 — The coverage fill — recognizable names → `specs/0019-the-coverage-fill`.
  Promoted when 0018 Release 1 shipped and deployed. All three deferred findings it
  carried are consumed by that spec: fill depth (D17, plan step 4), `dedup_key`
  normalization (plan C3), and the deny-list's culture-string gap (plan step 5, which
  found 49 works over 31 strings already live as place-name artist pages).
- 2026-08-19 — A Keep rail on every multi-work surface → `specs/0020-keep-where-you-find-it`.
  **Corrected on promotion:** the Inbox line claimed Zoom *and* Keep were unreachable on
  `/feed` and `/artists/:slug`. Zoom is reachable — `shared/_plate.html.erb:7` makes the
  picture itself the zoom trigger, and both surfaces already render `shared/_zoom`. The gap
  is Keep only, and 0020 is scoped to Keep only. Built same day (`b9a6727`), `bin/ci` green.
  Code only — not deployed.
- 2026-08-19 — Theme/period filters → `specs/0022-what-kind-and-when`. **Sequencing
  deviation, taken deliberately, not silently:** this entry said "not before submission,"
  and the app is still not submitted (`BET.md`, all five thresholds zero) — promoted anyway
  on explicit direction, with the gap named in the story rather than the note quietly
  dropped.
- 2026-08-19 — Auto-fill the daily queue: system picks the day's painting →
  `specs/0023-the-standing-order` — Proven (pipeline: "curated queue → daily publish job").
  Captured and promoted same day: source is a direct operator report ("manual picking has
  become unsustainable"), WIP slot was open, and `config/deploy.yml:115` had carried the
  IOU for this exact job since first deploy. Direction forks (7-day buffer; random +
  spacing) settled in `decisions/0015`. Built same day (`fb67cf7`), `bin/ci` green.
  Code only — not deployed.
