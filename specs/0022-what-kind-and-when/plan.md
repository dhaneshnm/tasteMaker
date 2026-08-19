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

## Release 2 — the fill (stub; own plan section before building)

Per the story: dry-run coverage measurement first (Wikidata `P135` artist-movement via
`Pool::Recognizable`, work-level `P136`, Getty AAT/Iconclass, department heuristics) →
the numbers pick the route → manifest gains the field → facet floor set by measurement
and asserted `pool_quota_test`-style. Nothing in Release 1 presumes the route: the
`genre` column takes whatever canonical vocabulary the dry-run wins with.

## Deviations (added during build)

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

## GSTACK REVIEW REPORT

| Review | Trigger | Why | Runs | Status | Findings |
|--------|---------|-----|------|--------|----------|
| CEO Review | `/plan-ceo-review` | Scope & strategy | 0 | — | — |
| Codex Review | `/codex review` | Independent 2nd opinion | 0 | — | rate-limited; Claude subagent ran as outside voice |
| Eng Review | `/plan-eng-review` | Architecture & tests (required) | 1 | CLEAR (PLAN) | 4 issues + 7 outside-voice findings, 4 folded |
| Design Review | `/plan-design-review` | UI/UX gaps | 1 | CLEAR (FULL) | score: 6/10 → 9/10, 6 decisions |
| DX Review | `/plan-devex-review` | Developer experience gaps | 0 | — | — |

- **CROSS-MODEL:** the outside voice's strongest finding (BCE dates parsing to false CE
  centuries) was a class the first-party review missed entirely — wrong-parse vs
  no-parse. Folded, with the fixture zoo grown to pin it.
- **VERDICT:** DESIGN + ENG CLEARED — ready to implement Release 1.
- Eng decisions auto-taken on explicit owner instruction: numeric century ordering
  (lexical-sort trap); strict century convention pinned ("1900" → 19th); BCE → nil,
  never a CE bucket; `MIN_FACET_WORKS = 5` provisional floor (outside voice F5, the
  story's own dead-end rule applied to R1); complexity check named (12 files) and
  proceeded — 5 are tests, 3 are one-line touches. Outside-voice findings skipped with
  reasons: F1 (submission displacement — owner decided twice, recorded in story), F2
  (genre plumbing — the machinery is generic, the R1/R2 split was the owner's explicit
  instruction), F7 (store-the-slug — resolution reuses the pluck the rows already need,
  display-value column keeps R2 vocabulary options open).

NO UNRESOLVED DECISIONS
