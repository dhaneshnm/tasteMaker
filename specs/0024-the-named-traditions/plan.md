# 0024 — The named traditions — implementation plan

Date: 2026-08-20
Story: `story.md`. Direction: `decisions/0016` (sequence position 1 of 3).
Design review: **skip proposed — UI-light** (one more `_facet_row` render in 0022's
shipped pattern; build flow step 3 allows the skip when noted). Eng review: owed
before implement (build flow step 4).

## Shape

The 0022 period facet, third verse. A pure function derives `tradition` from
culture/country/department at seed time; the generic facet machinery renders it.

```
db/seeds.rb ──▶ Pool::Tradition.from_strings(culture, country, department)
                 └─ ordered pattern table → canonical value or nil
paintings.tradition (new string column, indexed)
 └─ Painting.displayed_facet_values(:tradition)   ← existing, generic
     └─ /feed third facet row (_facet_row partial, existing)
```

## Steps

### 1. Migration + column

`add_column :paintings, :tradition, :string` + index — the 0022 D1 shape exactly
(nullable string, canonical display value in the column, `parameterize`d slug in the
URL, one resolution function shared by writer and reader).

### 2. `Pool::Tradition` — the mapping table is the work

`lib/pool/tradition.rb`, pure function, `PeriodBucket`'s twin. Ordered pattern table
(first match wins — the `GenreTerms` priority idiom), hardened from the 0008 probe
regexes, which were sizing instruments, not classifiers:

| Canonical value | Match on (culture ∪ country ∪ department, case-insensitive) |
|---|---|
| Mughal Painting | `mughal` |
| Pahari Painting | `pahari`, `kangra`, `guler`, `basohli`, `mandi` |
| Rajput Painting | `rajput`, `mewar`, `marwar`, `bundi`, `kota`, `bikaner`, `kishangarh` |
| Kalighat Painting | `kalighat` |
| Jain Manuscript Painting | `jain` |
| Chinese Painting | `china`, `chinese` |
| Japanese Painting | `japan` (Edo included — see story non-goal on ukiyo-e) |
| Korean Painting | `korea` |
| Persian & Islamic Painting | `persia`, `iran`, `safavid`, `qajar`, `islamic`, `ottoman` |
| Tibetan & Nepalese Painting | `tibet`, `nepal` |

Deliberately dropped from the probe version: bare `rajasthan` and `gujarat`
(region ≠ school — the story's 95% audit gate exists exactly for these; they return
only if the audit shows the narrower patterns starve a real bucket). Precedence
matters and is tested: a "Mughal India, court of Akbar" work is Mughal, not Persian,
even though Persian patterns may also fire — the table order IS the tie-break.

Diagram-comment above the table in the file, per the house idiom (`daily_pick.rb`,
`auto_fill!`).

### 3. Seed + backfill

- `db/seeds.rb` writes `tradition` at seed time — recomputed every reseed, no
  manifest change (0022 D2's exact pattern, same reasoning).
- Prod: one-off `bin/rails runner` backfill over existing rows (0022's precedent —
  a full reseed moves 0.66 GB of plates for a metadata-only change).

### 4. `/feed` row + controller

- `PaintingsController#index`: resolve `params[:tradition]` exactly as `:period` /
  `:genre` (same reduction-function idiom), compose into the same scope chain and
  pagination frame params.
- View: third `_facet_row` render under genre. Row hidden entirely when no value
  clears `MIN_FACET_WORKS` — by construction, not data hygiene.
- Masthead filtered-count aside already generic; verify, don't rebuild.

### 5. The audit (success signal 2, R1)

`bin/rails runner` script prints 50 random tradition-stamped rows (title, artist,
culture, stamped value); hand-check; result → Deviations. < 95% → narrow or drop the
offending pattern and re-run. The audit is the enforcement that ships with the
mapping table.

### 6. Tests (with the work — R1)

- `Pool::Tradition` unit: every pattern row (fixture per tradition), precedence
  (Mughal-vs-Persian double-fire), nil on blank/unmatched, the dropped-pattern
  regression (a bare "Rajasthan, 19th century" culture string maps to nil, pinned).
- Controller/integration: `?tradition=` filters; unknown slug → no filter (the 0022
  behavior); combined `?tradition=&period=` works; empty facet renders no row;
  unfiltered page unchanged (byte-comparison test if 0022 left one — extend it).
- `pool_quota_test`: every non-nil tradition value is in the canonical vocabulary
  (no free-text leaks into the facet).
- System: tap tradition value on `/feed`, filtered page shows only matching works,
  ALL returns.

### 7. Ship

`bin/ci` → `/qa` → `/simplify` → `/code-review` → re-verify → commit, deploy
(operator runs Kamal — agent shell lacks secrets), backfill runner, `SHIPLOG.md`
receipt: URL of a filtered feed page serving real works.

## Risks, named

- **Free-text culture strings misattribute** — the 95% audit gate + dropped broad
  patterns own this; wrong label is worse than no label (0022's BCE lesson).
- **Row chrome creep on `/feed`** — three facet rows now; Maya's calm bar. If design
  review is un-skipped, this is the one question worth its time: rows vs a single
  combined row. Default: ship the third row, pattern-consistent.
- **Tradition ∩ genre double-labeling** (a Mughal portrait is both) is a feature,
  not a bug — different columns, different questions, filters compose.

## What already exists (reused, not rebuilt)

`displayed_facet_values` / `facet_counts` / `MIN_FACET_WORKS` (0022 R1, generic);
`_facet_row` partial + slug resolution idiom; `PeriodBucket` as the pure-function
template; `GenreTerms` as the ordered-dictionary template; the 0008 data files as
the vocabulary + sizing source.
