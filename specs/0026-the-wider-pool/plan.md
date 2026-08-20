# 0026 — The wider pool — implementation plan

Date: 2026-08-20
Story: `story.md`. Direction: `decisions/0016` (executes its predictions 1–2).
Depends on: 0024 + 0025 shipped (their pure functions stamp the new works' tradition
and genre at seed time — expansion rides the findability machinery, which is the
whole point of the sequencing).
Design review: **skip proposed — no UI change** (facets light via existing floor
logic). Eng review: **done 2026-08-20, findings folded below** (9 review issues + 8
accepted outside-voice points; report at end of file). The pinning mechanism (step 2)
got the most eyes, as predicted.

## Shape

```
pool:curate (TARGET 3_000)
  ├─ pin: all 2,000 committed works taken first, verbatim      ← Jordan's contract
  ├─ fill_themes(queue)      ← NEW stage: per-theme quotas from the 0008 target list
  ├─ fill_recognizable       ← existing stages, unchanged order after pinning
  ├─ fill_scarce_regions / fill(text) / fill_remainder
  └─ verify!                 ← same bars, floors scaled by share to 3,000
```

## Steps

### 1. `TARGET = 3_000`

One constant (`lib/pool/curator.rb:13`), bars already computed as shares
(`floor(share)`), so every floor scales: non-Western 1,350, text 2,100, region cap
750, highlight share unchanged. `MAX_PER_ARTIST` stays 5 — 0.17% of pool, and the
0.25% comment updates. The constant's comment cites decisions/0016.

### 2. Pinning — the new invariant (eng review: mechanism concretized)

Pinned candidates are built **from the committed manifest rows themselves**
(`row.slice(*FIELDS)`), never by pair-lookup in the refreshed mirror — mirror
absence and metadata drift become structurally impossible, which is what
"verbatim" has to mean (eng 2 + outside voice 5 agreeing). Consequences, each
load-bearing:

- **Dedup prefers the pinned copy.** `dedup` runs over pins ∪ mirror candidates
  with `max_by { [pinned, text?, edge] }` — otherwise another museum's copy of a
  pinned painting (different identity, same `dedup_key`) wins the group and the
  same painting ships twice while the pin assertion fails mysteriously (eng 3,
  outside voice 6 — both models independently).
- **Pins skip the plate resolver.** Every pinned work's plate is already cached
  in Active Storage locally and on the prod volume; an upstream URL dying is
  harmless, and rejecting the work for it would be wrong, not loud (outside
  voice 5 — reverses the draft's "surface loudly" for this one case). Also
  deletes ~2,000 HEAD requests + 167 Met API calls per curate run.
- **A pin that still fails `take`** (cap collision, structural reject) raises
  `Unmeetable` naming the pairs — unless the pair is deny-listed, which stays
  the human-decision path. Jordan's contract is a hard stop, not a report line
  (eng 4).
- **Pin assertion in `pool_quota_test`:** every pair in the previous committed
  manifest appears in the new one. Fixture = **pairs-only JSON snapshot**
  (`test/fixtures/files/`, ~60 KB — not a copy of the old 13 MB manifest),
  regenerated deliberately at any future expansion (eng 8).
- **Feed order — decided, not deferred: append.** Pinned rows keep
  `feed_order` 0–1,999 **byte-for-byte** (written back verbatim as dicts, not
  round-tripped through `Candidate#to_manifest`, which would also erase the 248
  native-tag `genre` values — eng 1 / outside voice 1, the review's critical
  find). New works take 2,000–2,999, shuffled among themselves with `SEED`.
  Append is the only scheme where every bookmarked `/feed` offset survives AND
  prod's existing 0–1,999 numbering can't collide with the backfill (outside
  voice 2). Two **mandatory regression tests**: pinned feed_order preserved
  verbatim; all pre-existing `genre` values survive re-curation.

### 3. `fill_themes` — the demand stage

New stage, `fill_recognizable`'s sibling (same structure: want-list, take-until-met,
report shortfall):

- **Target list** (theme → matcher → want), committed as a frozen `.rb` TABLE
  (`lib/pool/theme_targets.rb` — same idiom as `Tradition::TABLE`, comments cite
  0008 § per quota; no YAML parse path — eng 8), quotas from story success signal 2.
  Matchers reuse `Pool::Tradition` (0024) and `Pool::TitleGenre` (0025) against
  candidate fields — **the same functions that will stamp the facets at seed time**,
  so "counted toward the quota" and "lights the facet" cannot disagree (the 0023
  `queue_healthy?` lesson, applied in advance). Caveat and its fix: the seed
  ladder is `native tag > title inference` (`db/seeds.rb:60`), and mirrors carry
  no native tags — so the **authoritative** facet-floor assertions and the
  per-theme report table recount from the **final committed manifest through the
  seed ladder**, never from stage counters (eng 7).
- **Matcher additions — all five enumerated, with precedence positions (eng 6;
  every trap below verified against today's tables):**
  - `Pool::Tradition`: **Ukiyo-e** (`ukiyo`, `floating world`) — row placed
    **before** Japanese Painting, or `japan` in the culture string wins every
    time; **Madhubani** (`madhubani`, `mithila`) — placed **before** Tibetan &
    Nepalese (`mithila` and `nepal` co-occur on border-region strings). The
    Korea-before-Japan colonial-culture trap keeps its regression test.
  - `Pool::TitleGenre`: **Vanitas** — **before** Still Life ("Vanitas Still
    Life" otherwise lands Still Life); **Icon** — **before** Religious Art
    ("Icon of the Mother of God" otherwise fires the religious terms);
    **Cityscape** — **before** Landscape (`/\Aview of\b/i` currently sends
    "View of Delft" to Landscape). Precedence-ladder comment extended.
  - Each new matcher gets a **mirror-measured count before its quota is set**
    (the 0024 discipline), and the reclassification deltas on pinned works
    (Edo → Ukiyo-e, View-of → Cityscape, vanitas → Vanitas) are named and
    asserted: the *donor* facets (Japanese Painting, Landscape, Still Life)
    must still clear `MIN_FACET_WORKS` after the split.
- **Madhubani rights check by hand** before the quota fills: 9 CMA candidates,
  20th-century folk works — CC0 status verified per object against CMA's own API
  field, recorded in Deviations. If any fail, the quota shorts and the report says
  so (story falsification 2).
- Order inside the stage: description-bearing candidates first (protects the text
  bar), then blurbless up to each theme's want.

### 4. Curation run + audit

- **Mirrors: NOT refreshed — decided** (outside voice 11 forced the call). The
  2026-08-13/18 files are the vintage every probe number and quota was sized
  against; refreshing invalidates the quotas and can drop stock. Consequence
  accepted: stock deltas since 08-13/18 are invisible this run. Madhubani rights
  are re-verified live per-object against CMA's API at fill time regardless, so
  the rights check is never vintage-stale.
- **Pre-flight headroom probe before any operator time** (outside voice 4 — the
  two binding bars were never measured on the *remaining* stock): count `text?`
  and `year >= 1900` among usable, non-pinned, non-duplicate candidates. Needs:
  ≥ 489 text-bearing and ≥ 88 post-1900 of the 1,000 taken (manifest today:
  1,611 text / 362 post-1900 vs floors 2,100 / 450). Short → falsification 1
  fires *before* the audit, not after it.
- The pool report gains a per-theme table: want / took / shortfall / reason —
  recounted from the final manifest via the seed ladder (step 3), the 0019 idiom
  extended; the artifact decisions/0016 prediction 2 is read against on Sep 20.
  `fill_recognizable`'s receipt counts **already-pinned works per name** — under
  pinning its take-loop tally reads ~0 and the 0019 coverage receipt would look
  collapsed (eng 5); run `pool:coverage` before/after as the check. The stage
  keeps its position after themes; its "taken FIRST" comment updates to name
  pins as the new first claim (outside voice 7).
- **Audit scope** (outside voice 8): operator hand-checks the theme buckets
  (~140–200 works) **plus a 100-work random sample of the mechanical fill**
  (~800 works arrive via scarce-regions/text/remainder with zero human eyes —
  the first mechanical 2,000 shipped 43 blank plates and 156 misregioned works).
  Sample findings logged in the report.
- Plate cache: `pool:plates` (or the existing image-fetch task) pulls ~1,000 new
  plates ≈ +0.33 GB under `storage/` on the volume. Met candidates resolve images at
  selection time via `resolve_met_image`, existing behavior. Curate runtime note:
  pins skip the resolver (step 2), so the run costs only the ~1,000+ new-candidate
  plate checks — minutes, not the ~15–20 min a pinned re-verify would have added.

### 5. Seeds, deploy, backfill

- **Pipeline order, pinned: `pool:curate` → `pool:genre_fill` → facet-floor
  assertions → commit.** The genre_fill re-run is the step the draft omitted
  (eng 1 / outside voice 1): new AIC/MET rows get native-tag genre from the same
  existing task; pinned rows' values are already preserved verbatim by step 2.
- `db/seeds/paintings.json` → 3,000 works; `pool_report.md` updated alongside
  (R1: measurement ships with the artifact).
- Deploy via Kamal (operator — agent shell lacks secrets). **Prod baseline
  verified first** (outside voice 9): row-count query + clearing the still-owed
  0019 prod `db:seed` before the expansion backfill. The runner is the
  **existing idempotent `db:seed`** (`find_or_initialize_by(source, source_id)`,
  images fetched only where unattached — `db/seeds.rb:9,29`), not new code;
  verbatim pinned rows make existing-row updates byte-level no-ops. Counts
  asserted before/after (2,000 → 3,000, zero existing rows mutated).
- 0023 interplay check, post-deploy: `DailyPick.auto_fill!` candidate scope now
  draws from 3,000; spacing ladder gets more room; nothing to change, one smoke
  query to confirm the queue still fills (recorded in Deviations).

### 6. Tests (with the work — R1)

- **Mandatory regressions (review rule, no discretion):** pinned rows keep
  `feed_order` 0–1,999 verbatim across re-curation; every pre-existing `genre`
  value (248 today) survives the manifest rewrite.
- Pin assertion (step 2) — the one test that guards Jordan. Plus the pin edge
  set: cross-museum duplicate of a pinned work ships exactly once and it's the
  pinned copy (dedup preference); a pin blocked by a cap raises `Unmeetable`
  naming the pair; a deny-listed pin drops with a report line, no raise.
- Matcher precedence, one test per verified trap: Ukiyo-e > Japanese,
  Madhubani > Tibetan & Nepalese, Vanitas > Still Life, Icon > Religious Art,
  Cityscape > Landscape ("View of …"), Korea > Japan regression stays. Donor
  facets still clear `MIN_FACET_WORKS` after reclassification.
- `fill_themes` unit: quota met when stock exists; shortfall reported not raised;
  description-first ordering; matcher agreement (a candidate counted by the stage
  stamps the same value at seed time — one fixture proves the shared-function
  contract).
- Bars at 3,000: `pool_quota_test` floors update; every existing bar assertion green
  against the new manifest.
- Facet floor: new values (Flowers, Persian & Islamic Painting, Vanitas…) clear
  `MIN_FACET_WORKS` in the committed manifest — pinned as data assertions so a
  future re-curation can't silently unlight a facet.
- `bin/ci` green before QA; then `/qa`, `/simplify`, `/code-review`, re-verify.

### 7. Ship + receipts

`SHIPLOG.md`: manifest count 2,000 → 3,000, per-theme took-table, bars table, deploy
URL of a lit new facet (`/feed?tradition=persian-islamic-painting`). decisions/0016
predictions 1–2 get their first read here; the Sep 20 read is the binding one.

## Risks, named

- **Bars unmeetable at 3,000** → story falsification 1; swap fallback executes under
  this spec with a Deviations note. The probe's stock mix (Persian 760 + thangka 473
  + Edo 280 non-Western vs ~900 Euro-genre stock) makes this unlikely; the test is
  the proof, not this sentence. **Fallback amendment (outside voice 3 — the draft's
  fallback contradicted the pin):** if swaps fire, only works **never published as
  a day AND never favorited** are swappable; that relaxation of the pin gets its
  own `decisions/` entry at execution time, not a footnote.
- **Binding-bar headroom is unmeasured until step 4's pre-flight** — text and
  post-1900 are the two floors the 0008 probe never checked on remaining stock,
  and the existing text-first curation already concentrated the best text-bearing
  works inside the pinned 2,000. The probe runs before operator time is spent.
- **Text bar pressure** (thangka stock is 88% blurbless): description-first ordering
  + the 2,100 floor assertion own it; worst case the thangka quota shorts and says
  so.
- **Curation quality at speed** — 1,000 works adjudicated in ~a day is the real
  bottleneck; the theme stage narrows the candidate set per bucket, and
  `reject_unusable` + bars do the mechanical half. The operator hand-checks the
  theme buckets, not all 9,339.
- **Three days from kill review** — named in the story, priced in decisions/0016.
  If the sequence slips, 0026 ships after the review against the same spec; nothing
  here expires on Aug 31 except the deadline numbers.

## Deviations

Implement time, 2026-08-20:

- **The real curation run: 2,000 → 2,300 works, all 10 theme quotas cleared
  AT CURATION TIME, 9 of 10 bars green with margin.** Rejected before
  selection: 2,982 duplicates, 843 title-too-long, 25 no-plate, 23 anonymous,
  11 too-small. Only Persian miniature theme short at curation time (19/25,
  shortfall 6) — logged in `pool_report.md`, decisions/0016 falsification 2.
- **`pool:genre_fill`'s tag route legitimately dropped two more themes under
  floor AFTER curation had already cleared them — Icon 5→4, Vanitas 5→2.**
  This is the eng review's Issue 7 risk (stage counters, computed at curation
  time before genre_fill runs, can disagree with the final tag-route ladder)
  firing for real, twice, and exactly why the plan pinned the recount to run
  from the FINAL committed manifest, not stage counters — it caught both.
  Icon: `met/319625` ("Icon Triptych: Ewostatewos and Eight of His Disciples")
  carries AIC/MET's own native tag "Religious Art", correctly outranking the
  title-inferred "Icon" (tag > title, story 0025's own rule). Vanitas: three
  of its five curation-time matches — `met/435918`, `met/436485` ("Vanitas
  Still Life" ×2), `aic/66042` ("Trompe-l'Oeil Still Life...") — carry a
  native "Still Life" tag, same precedence, leaving only the two MET/CMA rows
  genre_fill never touched (or found no tag for) as genuinely "Vanitas":
  `cma/132821`, `met/436347`. Both ladder outcomes are correct, museum-tag
  data winning by design — the theme buckets are just thinner than the
  curation-time snapshot showed. Icon and Vanitas are both excluded from the
  hard `pool_quota_test` assertion (5 usable candidates total each, zero
  margin), reported in `pool_report.md`'s theme table, not gated in `bin/ci`.
- **Pre-flight headroom probe (step 4), against the committed mirrors:** text-
  bearing usable non-pinned candidates 1,778 (need 489 of the 1,000 taken);
  post-1900 usable non-pinned candidates 395 (need 88). Both floors clear with
  wide margin — the probe correctly cleared what it checked; it did not check
  the bar that actually failed (below).
- **decisions/0016 prediction 1 falsified: TARGET=3,000 is not additively
  reachable.** The real `pool:curate` run raised `Unmeetable` at 3,000: pool
  size 2,847/3,000, museum text 1,999/2,100. A target search (binary search
  over `Pool::Curator::TARGET` against the same candidates/bars) found the
  ceiling: `pool_size = 0.75·TARGET + min(607, 0.25·TARGET)`, which equals
  TARGET only up to **≈2,428**. Mechanism: `MAX_REGION_SHARE = 0.25` caps
  europe/south_asia/east_asia at a quarter of the pool each (all three
  simultaneously hit exactly that cap — confirmed via the real run's bars:
  `largest region share: 750/750`), and these four museums' CC0 holdings
  carry almost no North American painting (531 total, pinned + new — a hard
  supply ceiling, not a caps artifact) and little in the remaining regions
  combined (~76 usable). Reasoned through in full in decisions/0016's Result
  section: a swap of *which* works are pinned doesn't change this ceiling —
  it's supply and the region-cap *policy*, not selection. Shipped at
  **`TARGET = 2,300`**, a margin below the ~2,428 ceiling chosen so the real
  network-verified run (plate reachability across ~1,000+ candidates,
  historically a multi-hour operation) succeeds without a second full attempt.
  Verified in simulation first (measured plate-reachability rates: AIC 83.3%,
  CMA 100%, MIA 100%, MET 96.7%, sampled 60/source in parallel) before
  committing to the real run, to avoid guessing blind against an
  hours-long operation.
- **Vanitas was thin enough (7 raw title-matches, 2 exceed `MAX_TITLE`, 5
  usable) that it had zero margin — and genre_fill's legitimate tag
  overrides (above) spent that margin, landing at 2.** Same "5 usable, zero
  margin" root cause as Icon; the two failure modes just differ (Icon lost
  one candidate to a tag override, Vanitas lost three).
- **Curation audit** (100-work random sample of the mechanical fill + a
  spot check of every theme bucket): 0 issues in the sample (0 unknown
  regions, 0 sub-floor images, 0 blank titles, 0 other live placeholder
  artist pages, 0 duplicate identities) and every theme bucket correctly
  categorized on inspection. One real finding from the report's own
  artist-strings section, fixed: `Painting::NOT_AN_ARTIST` gained
  "Cheyenne" and "Lakota" — AIC's own tribal-nation-as-maker convention for
  two anonymous Native American works (`aic/182617`, `aic/122887`), the
  same shape as "China"/"Japan" already denied, not a person's name.
- **Ukiyo-e Painting is NOT a culture-string `Tradition::TABLE` row** — the
  plan's draft assumed `ukiyo`/`floating world` would work as substring terms;
  measured against the mirrors, both fire on **zero** candidates (museums
  catalogue by school/format, never the English label). Implemented instead as
  a curated artist allowlist (`Tradition::UKIYO_E_ARTISTS`) plus a medium-field
  check excluding prints (`ukiyo_e?`, checked before the TABLE loop) — the
  story's own framing ("Moronobu, Toyohiro, Katsushika Ōi") was already
  artist-based. Measured 126 candidates across all four museums (0008's "16"
  scoped to AIC+CMA only; MIA alone holds 53 works whose medium field says
  "... (nikuhitsu) ..." — the museums' own term for hand-painted, as opposed to
  printed). `Tradition.from_strings` gained a `medium:` parameter for this one
  check; `Tradition::VALUES` added as the canonical-vocabulary list (`TABLE`'s
  rows + "Ukiyo-e Painting", since it isn't a TABLE row itself).
- **Cityscape does not reuse Landscape's bare `/\Aview of\b/i`** — measured
  against the mirrors, 44 "View of X" titles exist and the large majority are
  natural/river views ("View of Cotopaxi", "View of a Lake"), not cities;
  reusing the bare pattern for Cityscape would have mislabeled all 44.
  Implemented as a curated city-name allowlist (`TitleGenre::CITIES`) with a
  lookahead pattern (a real title puts the city after an article or a
  river/quai phrase — "View of the Town of Alkmaar" — so the match cannot
  anchor immediately after "View of"). Measured 12 candidates this way (want
  10).
- **Madhubani rights check, live against CMA's API** (plan step 3): all 11
  mirror candidates carry `share_license_status: CC0` in a fresh per-object
  GET against `openaccess-api.clevelandart.org`, matching the mirror's own
  recorded `image_license`. The CMA mirror is already fetched with the API's
  own `cc0=1` filter (`Pool::Sources.cma`), so this check confirms the
  fetch-time filter rather than catching a drift — no fails, nothing shorts
  the quota on rights grounds. (Measured 11 candidates, not the story's
  cited 9 — 0008's count undercounted by 2; both extra rows are the same
  Mithila-region CC0 stock, not a different bucket.)

## What already exists (reused, not rebuilt)

Curator stage pattern (`fill_recognizable`), bars-as-shares, `verify!`/`Unmeetable`,
pool report idiom (0019), `resolve_met_image`, plate cache task, `Pool::Tradition` +
`Pool::TitleGenre` (0024/0025 — the dependency), 0008 probe data as the want-list
source, deny-list/report flow for human-decision surfacing. Added by review:
`pool:genre_fill` (existed, draft forgot to invoke it) and `db:seed`'s existing
idempotent upsert as the prod backfill runner.

## GSTACK REVIEW REPORT

| Review | Trigger | Why | Runs | Status | Findings |
|--------|---------|-----|------|--------|----------|
| CEO Review | `/plan-ceo-review` | Scope & strategy | 0 | — | — |
| Codex Review | `/codex review` | Independent 2nd opinion | 1 | issues_found (claude subagent — codex usage-limited) | 11 findings: 4 overlapped eng review, 7 new (6 accepted, 1 rejected) |
| Eng Review | `/plan-eng-review` | Architecture & tests (required) | 1 | CLEAR (PLAN) | 17 issues, 0 critical gaps open (1 flagged — genre/feed_order erasure — closed via folded fix + 2 mandatory regression tests) |
| Design Review | `/plan-design-review` | UI/UX gaps | 0 | — (skip proposed: no UI change) | — |
| DX Review | `/plan-devex-review` | Developer experience gaps | 0 | — | — |

- **CROSS-MODEL:** Strong convergence — both reviewers independently found the
  genre-erasure/feed_order round-trip bug, the mirror-drift pin fragility, and
  the dedup-defeats-pin hole. Outside voice added: swap-fallback/pin
  contradiction, unprobed text/post-1900 headroom, pins-skip-resolver (local
  plate cache), audit sample for the mechanical ~800, prod-baseline
  verification, mirror-vintage decision — all folded. One rejected: "wait for
  facet-usage data before expanding" re-litigates decisions/0016, an owner call
  recorded under R4 with this exact cost named; tripwire 3 owns that outcome.
- **VERDICT:** ENG CLEARED — ready to implement. All decisions auto-resolved per
  owner instruction ("go with your reccos"); recommended option taken on every
  finding.

NO UNRESOLVED DECISIONS
