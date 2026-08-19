# 0022 — What kind, and when · implementation plan

Story: `specs/0022-what-kind-and-when/story.md`
Status: Draft — **Release 1 only.** Release 2 (the fill) keeps its dry-run-first shape
from the story and gets its own plan section stub below, the way 0018's plan carried
Release 2 until eng review split it.

Decisions in this plan were taken without a stop-and-ask round, on explicit instruction
(2026-08-19). Each is recorded with its reasoning where it lands.

## Approach — Release 1

Two facets on `/feed`, filtered by query params, rendered as rows of `.caps-link` items
in the product's own idiom. One structural rule enforced in the view: **a facet value
renders only when at least one work carries it**, so the genre row — empty until
Release 2 — renders nothing at all, and the page is byte-identical to today's.

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
century"`, `"c. 1900"`. Output: century buckets ("10th century" … "20th century"),
taking the **start** of a range ("1837–38" → 19th century; "c. 951–953" → 10th).
Unparseable → nil → the work simply never matches a period filter, and no bucket renders
for a value no work carries.

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

- Same `.caps-link` type, tracking, and 44px targets as the compass — the product
  already teaches this exact grammar ("the one you're on loses its link and steps back
  to `--ink-dim`", `aria-current`).
- The active value is the unlinked, dimmed one; "ALL" is active when no filter is set.
- The row scrolls horizontally (`overflow-x: auto`) rather than wrapping — a wrapped row
  costs 44px of fold budget per line, the exact cost DESIGN.md's rule 9 discussion
  polices. Never sticky: it rides with the masthead.
- No pills, no fills, no borders — `.days`' "never a card" rule generalizes.
- Filter links are plain GETs. No Stimulus, no form.

### D6 — Freshness and caching need nothing new

`/feed` is walled and private (story 0015); `Rack::ETag` digests the body, and a
filtered page is a different URL with a different body. The `@total` in the masthead
becomes the filtered count — free, and it doubles as the "N works match" feedback.

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
| `pool_period_bucket_test` | every measured `dated` format maps to its century; garbage → nil; range takes the start; "second half 16th century" → 16th, not 17th |
| `feed_filter_test` | `?period=<slug>` filters; unknown slug = unfiltered (no 500, no empty-page trap); combined genre+period ANDs; filtered `@total` in the masthead aside; pagination frame src preserves both params; page 2 of a filtered view stays filtered |
| `feed_filter_test` | **the non-empty rule**: a facet with no values renders no row (fixtures with nil genre → no genre row); a value present in fixtures renders exactly once |
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

- <none yet>
