# 0022 — What kind, and when · implementation plan

Story: `specs/0022-what-kind-and-when/story.md`
Status: **Release 1 implemented 2026-08-19.** `bin/ci` green (rubocop, brakeman,
bundler-audit, importmap audit, 447 unit/integration + 62 system tests). Verified live
against a real `bin/rails s` — see Deviations. Release 2 (the fill) keeps its
dry-run-first shape from the story and gets its own plan section stub below, the way
0018's plan carried Release 2 until eng review split it.

Decisions in this plan were taken without a stop-and-ask round, on explicit instruction
(2026-08-19). Each is recorded with its reasoning where it lands.

## Approach — Release 1

Two facets on `/feed`, filtered by query params, rendered as rows of `.caps-link` items
in the product's own idiom. One structural rule enforced in the view: **a facet value
renders only when at least `MIN_FACET_WORKS` works carry it** (see D3), so the genre
row — empty until Release 2 — renders nothing at all, and the unfiltered page is
byte-identical to today's except the period row.

```
GET /feed?period=19th-century&genre=portrait&page=2
        │
        ▼
PaintingsController#index
        ├─ resolve slugs → canonical values (nil for unknown/absent)
        ├─ scope = Painting.feed_ordered
        │           .where(period: value)   ← only when param resolves
        │           .where(genre: value)    ← only when param resolves
        ├─ @total = scope.count             ← masthead aside shows the filtered count
        └─ pagination frame src carries the filter params through every lazy page
```

### D1 — Schema: two nullable string columns, not a join table

`genre` and `period` on `paintings`, both nullable strings, both indexed. A join table
models works carrying several genres — a real thing in taxonomy land, but premature here:
Release 2's likely route (artist-level movement) is single-valued per work, the UI offers
single-select filters, and the `artist`/`artist_slug` precedent on this table is
single-valued strings. If Release 2's dry-run measures multi-valued assignment as
necessary, that is a migration then, with data in hand — not a speculative join table now
(CLAUDE.md: infrastructure for later).

Columns store the **canonical display value** ("19th century", "Portrait"). URLs carry
the `parameterize`d slug. One resolution function per facet turns a slug back into the
canonical value by matching against `DISTINCT` values — the `artist_slug_for` lesson
applied: one reduction function, used by both the URL writer and the URL reader, so the
two can never disagree.

### D2 — The period parser runs at seed time; genre comes from the manifest

Reseed semantics decide where classification lives (the 0019 machinery is the context):

- **`period`** is derived from `dated`, which the manifest already carries. So the parser
  is a pure function (`Pool::PeriodBucket.from_dated(string)` → `"16th century"` … or
  nil), and `db/seeds.rb` writes its output at seed time. Reseed-safe by construction —
  recomputed on every seed, no backfill task to forget, no manifest change needed.
- **`genre`** has no source until Release 2 adds it to the manifest
  (`db/seeds/paintings.json`) through the pool pipeline. The column ships now; the seed
  copies the manifest field when present, nil otherwise. Release 2 changes the manifest,
  not the app.
- A one-off `bin/rails runner` backfill sets `period` on the existing production rows
  after deploy (the alternative — a full reseed — moves 0.66 GB of plates for a
  metadata-only change).

### D3 — Period buckets are centuries, and movements are Release 2's question

The parser targets the measured format zoo: `"1913"`, `"c. 951–953"`,
`"second half 16th century"`, `"mid 19th century"`, `"1837–38"`, `"first half of 19th
century"`, `"c. 1900"` — plus the shapes the outside voice measured in the manifest that
the first draft missed: `"about 1213–1069 BCE"` and 4 more BCE dates, `"c. 1100s"`,
`"1560s?"`, `"16th/17th century"`, `"Mid–1850s"`. Output: a century bucket with its
ordinal, taking the **start** of a range ("1837–38" → 19th century; "c. 951–953" → 10th).
Whatever centuries the data yields render — the committed pool runs 1st through 20th,
not "10th–20th" as the first draft claimed.

**Two failure modes, and only one is safe.** Unparseable → nil → the work never matches
a period filter — safe. Parsing *falsely* — a BCE date's start-year grabbed and labeled
13th century **CE** — puts an actively wrong label on a rendered facet, which is worse
than no label. So: **any string carrying `BCE`/`B.C.` maps to nil**, never a CE bucket
(5 works; a "13th century BCE" singleton bucket would also be a dead end), and the
fixture zoo pins every wrong-parse trap above, not just the happy formats.

**Provisional facet floor in Release 1** (outside voice F5): the story calls a 1-work
facet "a dead end dressed as a feature," and without a floor the period facet lights
singleton centuries immediately (10th: ~6 works, earlier: 1–2). `MIN_FACET_WORKS = 5`,
one named constant — a value renders only when at least that many works carry it; works
below the floor stay reachable through ALL. Release 2's measurement re-decides the
number; the constant is where it lands.

Two conventions pinned here so no future edit flips them silently (eng review):

- **Century arithmetic is the strict convention**: `((year - 1) / 100) + 1`, so 1900 is
  the 19th century (1801–1900) and 1901 opens the 20th. Pinned by a parser test fixture,
  because "c. 1900" reads colloquially as 20th and an unpinned choice re-buckets the
  facet on somebody's future "fix."
- **Chronological ordering is numeric, never lexical**: "10th century" sorts before
  "9th century" as a string. The parser exposes the century ordinal alongside the label;
  `Painting.facet_values(:period)` sorts by it. Pinned by a test with 9th/10th both
  present.

Centuries, not movements, because centuries are what `dated` can honestly answer.
"Impressionism" is an attribution claim, not an arithmetic one — it arrives in Release 2
via the artist-movement route (Wikidata `P135` through the 0019 matcher), and the dry-run
decides whether movements enrich this facet or live in the genre column. Not decided
here; decided by measurement there.

### D4 — `/days` stays out of Release 1

`/days` is chronological by design (`specs/0003-past-days`) — its organizing principle
is *when the app showed it*, not *what kind of thing it is*. Filtering it is a coherent
later ask but a different mental model; bundling it here grows a 2-day release for a
surface nobody's evidence names. Out, noted, revisitable.

### D5 — UI: `.caps-link` rows under the compass rail, no new component family

One row per lit facet, directly under `.compass--rail`, before the first `.post`:

```
TODAY · DAYS · KEPT · GALLERY          ← compass rail (unchanged, sticky)
ALL · 16TH C · 17TH C · … · 20TH C     ← period row (new, not sticky)
[genre row: renders nothing in R1 — no values exist]
```

- Same `.caps-link` type and tracking as the compass — the product already teaches this
  exact grammar ("the one you're on loses its link and steps back to `--ink-dim`").
  **The row states the 44px bar itself** (design review pass 5): `.caps-link` sets size
  and tracking, never height — assuming otherwise is ISSUE-002 (commit 866bbc2), and
  DESIGN.md rule 9 lists every control that had to learn this. `min-height: var(--tap)`
  on the row's items, the token not a literal.
- The active value is the unlinked, dimmed one, carrying `aria-current="true"` — not
  `"page"` (the compass marks a *location*; this marks a *filter*). "ALL" is active when
  no filter is set. Each row is its own `<nav aria-label="Filter by period">` landmark
  (design review pass 6).
- **Within-row order is chronological** for period (design review pass 1). No row labels:
  century names and genre names self-identify, and a "PERIOD:" prefix is chrome the
  compass precedent doesn't carry. Genre's order is Release 2's call, made when the
  values exist.
- The row scrolls horizontally (`overflow-x: auto`) rather than wrapping — a wrapped row
  costs 44px of fold budget per line, the exact cost DESIGN.md's rule 9 discussion
  polices. Never sticky: it rides with the masthead (rule 5's sticky budget on `/feed`
  is spent on the compass rail, and this row doesn't earn a second exception).
  **The scroll affordance is the next value clipping at the viewport edge** — no fade
  masks, no indicators, no scrollbar styling (rule 6: no decoration; design review
  pass 4).
- No pills, no fills, no borders — `.days`' "never a card" rule generalizes.
- Filter links are plain GETs. No Stimulus, no form.

### D5a — The two states a filter can put the page in (design review pass 2)

Combined filters can produce **zero results even though every offered value has works**:
genre=portrait has works, period=16th-century has works, their AND may be empty. Two copy
states follow, both missed by the first draft:

- **Empty filtered page:** without a spec, `_page.html.erb` renders zero posts and then
  the coda — "You have walked the whole gallery," over a page holding nothing, with no
  way out. Instead: the `.page--empty` variant (already in DESIGN.md's vocabulary),
  ornament + one display-italic line — "Nothing here wears both." — and a `.caps-link`
  back to the unfiltered gallery. An empty state is a feature: warmth, a way out,
  context.
- **The end of a filtered walk:** "You have walked the whole gallery" is false under a
  filter — the reader walked a subset. The coda's line becomes "Every match, end to
  end." when any filter is active; the museum-credit note and back-to-top stay as they
  are. One conditional in the coda, not a copy system.

### D6 — Freshness and caching need nothing new

`/feed` is walled and private (story 0015); `Rack::ETag` digests the body, and a
filtered page is a different URL with a different body. The `@total` in the masthead
becomes the filtered count — free, and it doubles as the "N works match" feedback.

Rendering the facet rows costs two `DISTINCT` plucks per request (eng review A3) —
considered and accepted: 2,000 rows in SQLite, on a walled page, is not a cost worth a
process-global cache and its staleness bugs. A stale bookmarked filter URL after a
Release 2 value rename degrades to the unfiltered gallery by the unknown-slug rule —
graceful by construction, no redirect machinery needed (eng review A2).

## Files — Release 1

| File | Change |
|---|---|
| `db/migrate/*_add_genre_and_period_to_paintings.rb` | two nullable string columns + two indexes |
| `lib/pool/period_bucket.rb` | new — `from_dated(string)` pure function |
| `db/seeds.rb` | write `period` from the parser, copy `genre` from manifest when present |
| `app/models/painting.rb` | `facet_values(:genre/:period)`, slug resolution, filter scope |
| `app/controllers/paintings_controller.rb` | resolve params, apply scope, filtered `@total`, pass filters to pagination |
| `app/views/paintings/index.html.erb` | facet rows between rail and page |
| `app/views/paintings/_facet_row.html.erb` | new — one row, non-empty values only |
| `app/views/paintings/_page.html.erb` | pagination frame src carries filter params |
| `app/assets/stylesheets/application.css` | `.facets` row — overflow-x, spacing; tokens only |
| `test/lib/pool_period_bucket_test.rb` | new — the parser against the real format zoo |
| `test/integration/feed_filter_test.rb` | new — see Tests |
| `test/system/feed_test.rb` (extend) | filter tap → filtered page, active value unlinked |

## Tests — Release 1 (R1: written with the code)

| Test | Pins |
|---|---|
| `pool_period_bucket_test` | every measured `dated` format maps to its century; garbage → nil; range takes the start; "second half 16th century" → 16th, not 17th; **"1900" → 19th century** (the strict-convention pin); the ordinal accompanies the label; **every BCE form → nil, never a CE bucket**; "c. 1100s" → 12th (the off-by-one trap); "1560s?" and "16th/17th century" pinned |
| `feed_filter_test` | the provisional floor: a value carried by fewer than `MIN_FACET_WORKS` works renders no control, and its works stay reachable through ALL |
| `test/models/painting_test.rb` (extend) | `facet_values(:period)` orders 9th before 10th — numeric, not lexical (eng review A1) |
| `feed_filter_test` | `?period=<slug>` filters; unknown slug = unfiltered (no 500, no empty-page trap); combined genre+period ANDs; filtered `@total` in the masthead aside; pagination frame src preserves both params; page 2 of a filtered view stays filtered |
| `feed_filter_test` | **the non-empty rule**: a facet with no values renders no row (fixtures with nil genre → no genre row); a value present in fixtures renders exactly once |
| `feed_filter_test` | **the empty combined-filter state** (design review): a genre+period AND with zero matches renders `.page--empty` with its own line and a link back to the unfiltered gallery — never the "walked the whole gallery" coda over nothing |
| `feed_filter_test` | the coda line under an active filter reads the filtered variant, and the unfiltered gallery keeps the original line |
| `test/system/dynamic_type_test.rb` or `feed_test.rb` (extend) | the facet row's items clear the 44px bar at the accessibility cap — the ISSUE-002 regression, asserted not assumed |
| `feed_filter_test` | filtered view is URL-addressable: a cold GET with params works with no prior state |
| `test/system/feed_test.rb` | tap a period link → filtered feed, tapped value now unlinked/dimmed with `aria-current`, "ALL" restores |
| existing feed/design/dynamic-type suites | unchanged — the R1 page with no genre data must render byte-identically except the period row |

## Release 2 — the fill

Status: **Implemented and deployed to the committed manifest, 2026-08-19.** `bin/ci`
green (rubocop, brakeman, bundler-audit, importmap audit, 464 unit/integration + 62
system tests). Real coverage measured against all 403 AIC/MET works, not sampled — see
Deviations. `/plan-design-review` skipped, same reasoning 0019's fill used: no new UI,
Release 1's facet row already renders whatever `genre` values exist.

### The dry run

**Pool split, measured:** CMA 853 (43%), MIA 746 (37%), AIC 236 (12%), MET 167 (8%).
Any route's ceiling is capped by which museums it can reach.

**Route 1 — Wikidata `P135` artist-movement, via the existing 0019 QID list.**
Re-measured with the REAL matcher (`Pool::Recognizable.match`), not a naive slug
lookup — the first pass of this measurement made exactly the mistake the module's own
header warns about (a naive check said 308 works; the real matcher says **124**, because
naive slug intersection against the union of every name's alias set produces false
positives the real collision-aware matcher doesn't). 105 of the 200 recognizable names
match something in the pool at all. **124/2000 works (6.2%) route through an artist this
list already has a QID for.** Of those QIDs, 95/97 sampled (98%) carry a real `P135`
claim — so the bottleneck is reconciliation coverage, not Wikidata's data. Extending
reconciliation to the pool's other ~775 distinct unresolved artist strings is a research
project the size of building the 0007 list itself, with an unmeasured ceiling — out of
scope for a 1–2 day release.

**Route 2 — museum-native subject/genre fields, checked live against each museum's own
API** (the committed mirrors never captured these — `lib/pool/sources.rb`'s
`AIC_FIELDS`/CMA/MIA field lists were built for the app's existing columns and never
requested a subject field, so this had to be checked against the live APIs, not the
cached JSON):

| Museum | Share | Native field | Sampled | Genre-mappable |
|---|---|---|---|---|
| CMA | 43% | **none** — full key list checked on a real object (`/api/artworks/94979`); no subject/tag/style/movement field exists | — | 0% (structurally) |
| MIA | 37% | **none** — same check against `search.artsmia.org`'s real response keys | — | 0% (structurally) |
| AIC | 12% | `subject_titles` (real, rich, per-object — e.g. `["portraits: male subject", "portrait", ...]`) | 25 random works | **21/25 (84%)** matched a plain 17-term genre dictionary |
| MET | 8% | `tags` (Getty-AAT-linked per the Met's own API docs), plus `artistWikidata_URL`/`objectWikidata_URL` directly on the object | 25 random works (18 parsed — 7 hit a control-character JSON bug in this probe script, not a data gap) | **11/18 (61%)**, likely undercounted: misses included Buddhist-subject works whose tags were accurate but outside a Western-leaning term list |

**CMA and MIA are 80% of the pool and have no reachable genre signal without a much
larger research investment** (full artist-QID reconciliation, or a different route not
yet found). This is the headline number the rest of this plan has to be honest about.

**Combined ceiling: roughly 15–20% of the pool** — AIC + MET native tags only. The exact
number is Step 1 below, not this estimate. (Route 1's 124 works are dropped from this
release — see "Route 1, deferred" immediately below.)

### Route 1 (Wikidata `P135`), deferred out of this release — eng review

Outside-voice review (Claude subagent, Codex rate-limited) found three real problems
with folding Route 1 into Release 2, verified against the actual code:

1. **It breaks the CMA/MIA invariant this plan pins as a test.** `Pool::Recognizable
   .match` (`lib/pool/recognizable.rb`) iterates every candidate regardless of source —
   nothing in it is AIC/MET-only. "Museum tag beats `P135`" only resolves a conflict
   when a museum tag EXISTS. CMA and MIA structurally never have one, so for any
   CMA/MIA work whose artist is on the 105-name matched list, `P135` would win
   unopposed — directly contradicting "no CMA or MIA work ever carries a non-nil
   genre," which this plan needs to be true and testable. Route 1 is artist-based, not
   museum-based, so it was never actually scoped to "the 20% AIC/MET can reach" in the
   first place — that scoping error is what caused the contradiction.
2. **`Candidate::FIELDS` has no default.** `Struct.new(*FIELDS, keyword_init: true)`
   (`lib/pool.rb`) with no custom initializer leaves an omitted keyword `nil`, not `[]`.
   Real bug, independent of Route 1 — still fixed below (Step 1).
3. **The Wikidata SPARQL client is genuinely new infrastructure.** Nothing in `lib/` or
   `app/` talks SPARQL today; the only precedent is a throwaway Python research script
   (`user-research/scripts/0007/sparql.py`), not reusable Ruby. Step 3's old "one batched
   query" bullet compressed "build an HTTP client, construct a 105-QID `VALUES` clause,
   POST it, parse `sparql-results+json`, map QIDs back to works" into a single line, with
   only a call-count stub for a test — nothing verifying the query round-trips against
   the live endpoint before a real backfill depends on it.

**Decision: Route 1 dropped from Release 2, not fixed in place.** The three problems
compound rather than each being a quick patch, and the outside voice's cost/benefit read
is correct: 124 works, "mostly overlapping" with Route 2 by this plan's own words,
against real new external-dependency risk five days from the kill review. Simpler
release: ship Route 2 alone now. Route 1 becomes its own future story if a real ask
justifies it — logged in `IDEAS.md`, not silently dropped (see Deviations).

### What the dry run changed

The story's own falsification clause fires: *"if every candidate route covers only a
small minority of the pool... ship the facets that clear the floor and log the
shortfall, not invent a taxonomy."* 20–25% is that minority. This is not a reason to
cancel Release 2 — a real, honestly-labeled genre facet over a fifth of the pool is
still a real feature, and the floor mechanism Release 1 already shipped (`MIN_FACET_WORKS`)
handles a partial fill by construction, no new code needed there. It changes what
Release 2 promises: **a genre facet that is real where it exists and silent where it
doesn't, not a claim of pool-wide coverage.**

**A real product tension, named rather than shipped silently:** a genre-filtered view
will skew toward AIC's and MET's collecting emphasis, not the pool's actual subject
distribution — CMA and MIA carry meaningfully different holdings (MIA alone: 439 works
in "Indian and Southeast Asian Art," 443 in "Asian Art," per the department breakdown),
so "Portrait" as a filter undercounts real portraits sitting in the 80% this route can't
reach, and skews what's reachable back toward the two more Western-canon-encyclopedic
collections — the exact tension persona 3 (Amara) exists to guard. Sharper now that
Route 1 is deferred: with no second route reaching into CMA/MIA at all this release,
100% of whatever genre coverage ships is AIC/MET-shaped. Not blocking: named so the
design review and the shipped copy can address it (a caveat in the empty/thin state, or
simply not over-promoting genre in the UI's visual weight versus period).
Recommendation, not yet a decision: genre stays a secondary row under period, never
implied to be exhaustive.

### Architecture (eng review)

```
lib/pool/sources.rb — ALL FOUR adapters (eng review Issue 3 + outside voice #2)
        │ candidate.genre_source_terms — ONE common field, EXPLICITLY set on
        │ every Candidate.new call, not left to Struct's default. AIC/MET
        │ populate it from subject_titles/tags; CMA/MIA pass genre_source_terms: []
        │ explicitly — Struct.new(*FIELDS, keyword_init: true) has no custom
        │ initializer, so an omitted keyword is nil, not []. GenreFill would
        │ crash calling .each on nil without this.
        ▼
Pool::GenreFill (new, standalone — NOT curator.rb; eng review Issue 1)
        │ curator.rb SELECTS which works make the pool. This ENRICHES
        │ metadata on works already selected and shipped (Release 1's
        │ manifest is frozen) — a different job, kept in its own file,
        │ same reasoning that put the period parser in db/seeds.rb rather
        │ than curator.rb.
        │
        └─ per candidate: genre_source_terms → first dictionary-order match
           (the dictionary's own term order IS the tie-break — one
           definition, not two; eng review Issue 2). CMA/MIA candidates:
           empty array, no match, genre stays nil — the only route this
           release, so this is now the WHOLE tie-break story, not half of it.
        ▼
db/seeds/paintings.json — genre backfilled; db/seeds.rb already reads it
        ▼
MIN_FACET_WORKS / displayed_facet_values — Release 1's floor, unchanged,
now doing real work on real data
```

### Steps

1. **The real coverage measurement** (not the sample above — the full run). Extend
   `lib/pool/sources.rb`'s **all four** adapters to set `genre_source_terms` explicitly
   on every `Candidate.new` call (outside voice #2 — `Struct.new(*FIELDS,
   keyword_init: true)` has no custom initializer, so an omitted keyword is `nil`, not
   `[]`, and `Pool::GenreFill` calling `.each`/`.any?` on that would raise for every
   CMA/MIA candidate). AIC's `subject_titles` and MET's `tags` populate it with real
   values; CMA's and MIA's adapters pass `genre_source_terms: []` literally. Re-run
   `pool:mirror` for AIC and MET only — CMA and MIA mirrors are untouched metadata-wise,
   though their adapters still need the one-line explicit-empty-array fix. Full 236 +
   167 AIC/MET works measured, not 50 sampled.
2. **The genre dictionary.** A term → canonical genre value map, built from Getty AAT's
   own genre vocabulary (the story's constraint: "don't invent one") — Portrait,
   Landscape, Still Life, Religious Art, Mythological Art, History Painting, Marine Art,
   Animal Painting, Nude, Allegory, Battle Painting, Cityscape — plus whatever the full
   measurement in step 1 shows is common and currently unmapped (the Buddhist-subject
   gap found above is a named example, not the only one; a broader first pass than the
   probe's 17 terms is the fix, not a footnote). Committed as data
   (`lib/pool/genre_terms.rb` or a YAML file), same idiom as `Pool::PLACES`.
   **The dictionary is an allowlist, exact-term match — never fuzzy/substring**
   (eng review, Test section): AIC's own `subject_titles` mixes real genre terms with
   exhibition/provenance noise on the same object (`"Century of Progress"`,
   `"world's fairs"`, `"Chicago World's Fairs"` all appeared in the sampled data
   alongside genuine hits like `"portrait"`) — a loose match risks a noise term
   misfiring as a genre. The dictionary's key set is the only thing checked against;
   nothing outside it can match by construction.
3. **Multi-match resolution** (eng review Issue 2, `Pool::GenreFill`'s core logic):
   within one work's own `genre_source_terms`, the dictionary's own term order decides
   which hit wins — the dictionary IS the priority list, one definition, not a second
   ranking bolted on top. (Cross-source priority — museum tag vs. `P135` — no longer
   applies: `P135` is deferred, so museum tags are the only source this release.)
4. **Backfill into the manifest**, same shape Release 1 already reads: `genre` in
   `db/seeds/paintings.json`, `db/seeds.rb` copies it through unchanged (no app-code
   change — Release 1 already wrote `genre: attrs["genre"]`).
5. **Facet floor** — no new mechanism. `MIN_FACET_WORKS` and `displayed_facet_values`
   already do this job; step 1's real numbers are what feed it.
6. **`pool:coverage`-style report** — genre coverage by museum, by bucket, and the
   CMA/MIA shortfall stated in the same report, matching 0019's own coverage report
   shape rather than inventing a new one.

### Not decided here — real open questions for design/eng review

- Whether the museum-skew caveat needs UI treatment or just stays in the pool report.
- Whether MET's `objectWikidata_URL` (present on several sampled objects even without
  an artist QID) is worth a second, smaller measurement pass — unexplored past finding
  it exists.
- The exact genre dictionary size and whether Iconclass adds meaningfully over AAT terms
  alone for this pool's actual subject mix — step 1/2's real run answers this, this plan
  doesn't guess further.

### NOT in scope

- **Wikidata `P135` artist-movement (Route 1).** Deferred out of this release — see
  "Route 1, deferred" above. Logged in `IDEAS.md`, not silently dropped.
- **CMA/MIA genre coverage by any route.** No route measured in this dry run reaches
  them; a future story would need to find one (full artist-QID reconciliation at
  ~775-name scale, or a route not yet discovered) with its own evidence.
- **UI treatment for the museum-skew caveat.** Named as a real tension; left to design
  judgment at implementation time or a future design-review pass, not decided here.
- **Any change to the period facet.** Release 1 shipped and pinned it; Route 1's
  deferral removes the only reason this release would have touched it.

### What already exists

- `lib/pool/sources.rb`'s `get_json` — retry/backoff (3 attempts, exponential) already
  built for exactly this class of external-API call; the new AIC/MET field capture
  reuses it, not a second HTTP mechanism.
- `Pool::PLACES` — the existing idiom for "a committed vocabulary, not an invented one,"
  which `lib/pool/genre_terms.rb` follows rather than inventing a new shape.
- `MIN_FACET_WORKS` / `Painting.displayed_facet_values` (Release 1) — the floor
  mechanism this release's partial fill depends on; no new code needed for it to work
  correctly on real, uneven data.
- 0019's `pool_report.md` shape — this release's coverage report extends it rather than
  inventing a new report format.

### Files (Release 2 — approximate, firms up after step 1's real numbers)

| File | Change |
|---|---|
| `lib/pool.rb` | `Candidate::FIELDS` gains `genre_source_terms` (one array field) |
| `lib/pool/sources.rb` | all four adapters set `genre_source_terms` explicitly (outside voice #2) — AIC/MET from `subject_titles`/`tags`, CMA/MIA to `[]` |
| `lib/pool/genre_terms.rb` (or `.yml`) | new — the AAT-sourced allowlist dictionary, term order is the tie-break |
| `lib/pool/genre_fill.rb` | new, standalone (eng review Issue 1 — not `curator.rb`) — the dictionary-mapping pass over `genre_source_terms` |
| `db/seeds/paintings.json`, `db/seeds/pool_report.md` | genre backfilled, coverage reported |
| `test/lib/pool_genre_fill_test.rb`, `test/lib/pool_genre_terms_test.rb` | see Tests |

### Tests (Release 2 — R1: written with the code)

| Test | Pins |
|---|---|
| `pool_genre_terms_test` | **the allowlist is exact, never fuzzy**: real noise terms from the sampled data (`"Century of Progress"`, `"world's fairs"`, `"Chicago World's Fairs"`) never map to a genre value, sitting right next to genuine hits (`"portrait"`) that do |
| `pool_genre_fill_test` | **within-work multi-match**: a candidate with `genre_source_terms: ["Portraits", "Landscape"]` (both real dictionary keys) resolves to whichever the dictionary lists first — order-dependent, and the test pins the actual order, not just "picks one" |
| `pool_genre_fill_test` | **the nil-safety regression** (outside voice #2): a candidate built the way `cma()`/`mia()` build one — `genre_source_terms: []`, explicit, not omitted — resolves to nil genre without raising. A second test constructs a `Candidate` the OLD way (keyword omitted) and asserts it would have raised on `nil.each`, so the fix is provably load-bearing, not decorative |
| `pool_genre_fill_test` | a work with source terms present but none matching the dictionary resolves to nil, not an empty string |
| `pool_genre_fill_test` | **the one critical gap this review flagged** (Failure modes, below): one malformed AIC/MET record among 403 real ones is skipped (logged, `genre_source_terms` stays empty for it), and does not abort the rest of the run |
| `test/models/painting_test.rb` (extend) | `displayed_facet_values(:genre)` clears `MIN_FACET_WORKS` correctly on real backfilled data — the same floor test Release 1 wrote, now exercised with genre instead of a synthetic fixture |
| `test/lib/pool_quota_test.rb` (extend) | **the CMA/MIA invariant, now actually true** (outside voice #1 — this was false with Route 1 in scope): no CMA or MIA work ever carries a non-nil `genre` this release, since museum-native tags are the only route and neither source has any |

### Failure modes

| Codepath | Failure | Tested? | Error handling? | User-visible? |
|---|---|---|---|---|
| AIC/MET live re-mirror (step 1) | API down or rate-limited mid-fetch | Existing `get_json` retry/backoff already covers this (3 attempts, exponential) — reused, not new | Yes, existing | No — a re-run picks up where the mirror left off, same as every other source today |
| Malformed/empty tag JSON on one object | A single AIC/MET object returns unparseable `subject_titles`/`tags` (this dry-run's own probe hit a control-character JSON bug on 7/25 MET samples) | **Not yet named as a test** — flagging as the one real gap | **Not yet named** | Would be silent today: one bad object could raise and abort the whole fill rather than skipping that object and continuing |
| Dictionary has zero matches for a real, common term (a mapping gap found only in the full run, not the 25-work sample) | Genre coverage lands lower than the 15–20% estimate | The estimate is explicitly not a promise (Steps say "step 1's real numbers," not this number) — no test needed, the report states reality |

**One critical gap, named:** a single malformed AIC/MET API response during the full
236+167-work run has no stated handling. Given `get_json`'s existing pattern of raising
on a non-2xx after retries exhausted, an unhandled parse failure on one object could
abort the entire genre-fill run over one bad record. Fix, folded into step 1: wrap the
per-object tag extraction in a rescue that logs and skips that one object (leaving its
`genre_source_terms` empty, same as if the museum never provided tags at all), not one
that lets a single object's malformed response take down the whole pass. Test:
`pool_genre_fill_test` — one malformed record among real ones doesn't stop the others
from being processed.

### Worktree parallelization

Sequential implementation, no parallelization opportunity — every step reads or writes
`lib/pool/sources.rb`, the dictionary, or the manifest in an order that depends on the
step before it (mirror capture → dictionary → fill → backfill → report).

- **No new backfill file.** D2 anticipated "a one-off `bin/rails runner` backfill." Once
  `db/seeds.rb` itself computes `period` at write time (which it must, for a fresh seed to
  carry it at all), it IS the backfill: the metadata-write loop upserts every row
  unconditionally, and the image-download loop only touches paintings with no image
  attached — every production row already has one, so `bin/rails db:seed` (or
  `SKIP_IMAGES=1`, identical result here) re-run post-deploy backfills `period` on all
  2,000 rows with zero image transfer. Deploy follow-up, not a code task.
- **Real-manifest parser check, run before wiring the seed:** every one of the 903
  distinct `dated` strings in the committed manifest, not just the fixture zoo. Zero
  wrong-parses (confirmed: every loose "b.c"-shaped string in the manifest resolves to
  nil, none leaked a false CE bucket). 1,984 of 2,002 works land a period; the 18 that
  don't are BCE dates, blank, "not dated", or (one case, `"c. 25–37 CE"`) a genuine CE
  date whose year digits are too short for `ANY_YEAR`'s 3-4 digit floor — safe (nil), not
  wrong, and not worth widening the regex for a single instance. Bucket distribution:
  12th century (11 works) through 20th (280) all clear `MIN_FACET_WORKS`; 2nd–11th (27
  works total, seven buckets) stay below it and are reachable only through ALL — the
  provisional floor is doing real work, not a hypothetical one.
- **Manually verified against a real `rails s`** (2026-08-19), via the story 0021 mock
  door: unfiltered `/feed` renders all 9 lit period buckets and no genre row; filtering by
  `period=16th-century` narrows the count (143 works), dims the active value, and drops
  its own link; an unresolvable slug (`period=not-a-real-thing`) degrades to the full
  unfiltered 2,002 with no error; a genuinely empty combined AND (period + genre set by
  hand on a few dev rows, since Release 1 ships genre dark) renders `.page--empty` with
  "Nothing here wears both." and the way out; the genre row stays silent below the floor
  (3 works) and lights only once real values clear it. Dev DB reseeded clean afterward —
  no scratch genre data left behind.
- **`.masthead__aside`'s "works · Mia" text left untouched.** Pre-existing leftover from
  when the pool was Minneapolis-only (confirmed via `git log -p`, predates this story by
  months) — not in scope for this story, not touched, even though this exact line was
  edited for the filtered-count behavior. Noted rather than silently carried, since it's
  the kind of thing that looks like an oversight if found later without this note.
- **Release 2's `/plan-eng-review` cut Route 1 (Wikidata `P135`) from scope entirely**,
  after the outside voice (Claude subagent, Codex rate-limited both times this story
  used it) found it would break this plan's own pinned CMA/MIA test, exposed a real
  `Struct` default-value bug independent of Route 1, and required genuinely new SPARQL
  client infrastructure with no Ruby precedent in this repo — three compounding problems
  for 124 works the plan itself already called "mostly overlapping" with Route 2. Logged
  to `IDEAS.md` Inbox rather than silently dropped: *"Wikidata P135 artist-movement fill
  for genre (deferred from 0022 Release 2, 2026-08-19) — 124/2000 works reachable via the
  existing 0007 QID list, 98% of those carry a real P135 claim once reconciled, but the
  route needs its own SPARQL client (none exists yet) and must be explicitly scoped to
  AIC/MET works only, not artist-wide, or it silently breaks the CMA/MIA-has-no-genre
  invariant Release 2 shipped."*
- **Implementation-time architecture correction: `genre_source_terms` never touched
  `Candidate`/`FIELDS`/`curator.rb` at all** — the reviewed plan's literal Files table
  (`lib/pool.rb` gains a field, all four `sources.rb` adapters change) turned out to be
  infeasible as written. MET's tags are NOT in its bulk CSV (the mirror's normal MET
  source) — they exist ONLY on the per-object REST endpoint, confirmed live. Widening
  the shared `Candidate` struct and re-running `pool:mirror` would have meant fetching
  tags for MET's full multi-thousand-row CSV, not just the 167 works already shipped —
  thousands of wasted calls. Built instead: `Pool::GenreFill`, a standalone module
  (`lib/pool/genre_fill.rb`) that reads the ALREADY-COMMITTED manifest, filters to
  `source` in `%w[aic met]`, and makes ONE targeted per-object API call per already-
  shipped work — never touches `Pool::Candidate` at all. This is a smaller diff than
  reviewed (no `lib/pool.rb` change, no CMA/MIA adapter edits) and makes outside voice
  finding #2 (the `Struct` nil-vs-`[]` default bug) structurally impossible rather than
  patched: CMA/MIA rows are never even looked at, by construction, so there's no default
  to get wrong. Same architecture the review actually cared about (standalone module,
  not `curator.rb`; dictionary order as tie-break; skip-and-continue on a bad record) —
  only the fetch mechanism changed. `pool_genre_fill_test.rb` proves the CMA/MIA
  exclusion directly (a test asserting the stub is never even called for those rows),
  stronger than the reviewed test could have been.
- **Real coverage, measured against all 403 AIC/MET works** (not the 50-work sample the
  dry-run used): **248/2,000 works (12.4%)** carry a genre — AIC 185/236 (78%), MET
  63/167 (38%), both lower than the dry-run's loose-substring sample suggested, because
  the shipped dictionary is a strict allowlist (exact match + AIC's own colon-qualifier
  convention only — no fuzzy matching). 11 genre values have any coverage; **5 clear
  `MIN_FACET_WORKS` and render as a control**: Portrait (113), Landscape (76), Religious
  Art (25), Still Life (15), Animal Painting (8). The other 6 (Mythological Art,
  Battle Painting, Cityscape, Genre Scene, Marine Art, Nude — 1–4 works each) stay
  reachable only through ALL, exactly as designed — the provisional floor doing real
  work on real data, not a hypothetical.
- **The fetch hit transient DNS failures across three passes** (14, then 1, then 3
  records — different IDs each time, confirmed as network flakiness, not a
  source-specific or ID-specific problem), each time skip-and-continue working exactly
  as designed rather than aborting the run. Retried until 403/403 fetched successfully
  (100%). Live-verified afterward via a real `rails s` (the story 0021 mock door):
  unfiltered `/feed` renders both facet rows; `genre=portrait` narrows to 113; a combined
  `genre=portrait&period=17th-century` AND narrows to 12; `genre=not-a-real-genre`
  degrades to the full unfiltered 2,002; a genuinely empty AND
  (`genre=animal-painting&period=12th-century`) renders `.page--empty`.
- **`Pool::Report.genre_section`'s own first real output caught its own bug**: the
  "N value(s) clear MIN_FACET_WORKS" line printed all 11 buckets with coverage, not the
  5 that actually clear the floor — `by_bucket` was never filtered through
  `displayed_facet_values`. Fixed before commit; the report now separates "any
  coverage" from "clears the floor, is a real control" explicitly, and marks
  below-floor buckets inline.

## GSTACK REVIEW REPORT

Covers the whole plan file. Release 1 shipped and merged (PR #4) before this pass;
Release 2 is what this review round covers.

| Review | Trigger | Why | Runs | Status | Findings |
|--------|---------|-----|------|--------|----------|
| CEO Review | `/plan-ceo-review` | Scope & strategy | 0 | — | — |
| Codex Review | `/codex review` | Independent 2nd opinion | 0 | — | rate-limited both times this story used it; Claude subagent ran as outside voice each time |
| Eng Review | `/plan-eng-review` | Architecture & tests (required) | 2 | CLEAR (PLAN) | R1: 4 issues + 7 outside-voice, 4 folded. R2: 4 issues + 5 outside-voice, all 5 outside-voice folded (3 real problems drove a scope cut, 2 were fixed in place) |
| Design Review | `/plan-design-review` | UI/UX gaps | 1 | CLEAR (FULL) | R1: score 6/10 → 9/10, 6 decisions. R2 skipped — no new UI, Release 1's facet row already renders whatever `genre` values exist |
| DX Review | `/plan-devex-review` | Developer experience gaps | 0 | — | — |

- **CROSS-MODEL:** the outside voice caught real, code-verified bugs in the first-party
  review's own architecture both times this story ran it. R1: a wrong-parse class (BCE
  dates → false CE centuries) the first-party pass missed entirely. R2: the first-party
  review's own "museum tag beats P135" tie-break silently didn't apply to CMA/MIA (they
  never have a museum tag to win), which would have broken the very CMA/MIA invariant
  this plan pins as a test — a self-contradiction the first-party pass wrote and didn't
  catch. Both folded, not argued with.
- **VERDICT:** ENG CLEARED for Release 2 — ready to implement. Design review not
  required for R2 (no UI scope).
- **R2 eng decisions**, auto-taken on explicit owner instruction: `Candidate
  #genre_source_terms` as one field normalized at ingestion, not per-museum names
  (Issue 3); `Pool::GenreFill` standalone, not inside `curator.rb` (Issue 1 — enrichment
  of an already-frozen selection is a different job than selection itself); dictionary
  term-order as the within-work tie-break (Issue 2). **Route 1 (Wikidata `P135`) cut
  from Release 2 entirely** on the outside voice's finding — it broke this plan's own
  CMA/MIA test, needed genuinely new SPARQL infrastructure, and added mostly-overlapping
  coverage for real new risk five days from the kill review; logged to `IDEAS.md`
  Inbox rather than dropped. The `Struct` nil-vs-`[]` default bug (outside voice #2) is
  fixed regardless of Route 1's fate — all four adapters now set
  `genre_source_terms` explicitly. One critical gap closed: a malformed AIC/MET API
  response mid-run now skips that one record instead of risking the whole fill.

NO UNRESOLVED DECISIONS
