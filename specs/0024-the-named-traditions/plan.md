# 0024 — The named traditions — implementation plan

Date: 2026-08-20
Story: `story.md`. Direction: `decisions/0016` (sequence position 1 of 3).
Design review: **skip proposed — UI-light** (one more `_facet_row` render in 0022's
shipped pattern; build flow step 3 allows the skip when noted). Eng review:
**done 2026-08-20** — 6 findings in-section plus 7 outside-voice findings (6
accepted, 1 partial), all folded below; see the GSTACK REVIEW REPORT at the end.
All decisions auto-resolved to the reviewer's recommendation on the operator's
standing instruction.

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
regexes, which were sizing instruments, not classifiers.

**Match fields (eng review O4, verified against 12 real works):** culture ∪ country
∪ department, **plus `artist` when — and only when — the artist string is a
`NOT_AN_ARTIST` placeholder** (`Painting.artist_slug_for` returns nil). Museums
misfile school data in the artist column ("Mewar school", "Painter: Mughal school",
"Nurpur workshop", "Baysunghur school" — every one already enumerated in the
model's own deny-list, `painting.rb:49`), and those strings are by definition
culture data, not names. A real artist's name never participates, so "Kota Ezawa"
can never become Rajput.

**Every pattern is `\b`-word-anchored and case-insensitive** (eng review Issue 3 +
outside voice O6, cross-model agreement): "Indochina" must not fire `china`,
"Normandie" must not fire `mandi`.

| Canonical value | Match terms (in precedence order — first match wins) |
|---|---|
| Mughal Painting | `mughal` |
| Pahari Painting | `pahari`, `kangra`, `guler`, `basohli`, `mandi`, `nurpur`, `bilaspur` |
| Rajput Painting | `rajput`, `mewar`, `marwar`, `bundi`, `kota`, `bikaner`, `kishangarh` |
| Kalighat Painting | `kalighat` |
| Jain Manuscript Painting | `jain`, `gujarat` |
| Korean Painting | `korea` |
| Chinese Painting | `china`, `chinese` |
| Japanese Painting | `japan` (Edo included — see story non-goal on ukiyo-e) |
| Persian & Islamic Painting | `persia`, `iran`, `safavid`, `qajar`, `islamic`, `ottoman`, `baysunghur` |
| Tibetan & Nepalese Painting | `tibet`, `nepal` |

Three table calls made explicit, each from a measured fact:

- **`gujarat` stays IN the Jain row (outside voice O1, verified):** the pool's ~51
  Jain manuscript works — Kalpa-sutra folios — carry culture "Western India,
  Gujarat"; the bare `jain` substring matches exactly **1** work. Dropping
  `gujarat` (the first draft's call) ships a value that never clears
  `MIN_FACET_WORKS` and never renders. Bare `rajasthan` stays dropped — the
  Rajput row's school terms carry that bucket fine without it. The 95% audit gate
  owns the residual region≠school risk on `gujarat`.
- **Korean precedes Japanese (outside voice O3, verified against 4 CMA works):**
  culture "Korea, Japanese colonial period (1910−1945)" fires both terms;
  table order is the tie-break, and Japan-first would label colonial-era Korean
  painting "Japanese" — the exact wrong-label-worse-than-no-label case. Korea
  first, pinned by a fixture with that verbatim culture string.
- **"Persian & Islamic Painting" is a deliberate merge, named as a call (outside
  voice O7):** 0008 measured "Persian miniature" (51K lookups); the pool's ~19
  works span Persian, Ottoman, and Indo-Islamic. Splitting drops every piece
  below the floor. The merged umbrella ships; the audit samples this bucket
  specifically (it is the smallest and the most org-chart-driven — one work
  matches only on the Met's "Islamic Art" department).

Precedence is tested: a "Mughal India, court of Akbar" work is Mughal, not
Persian, even though Persian patterns may also fire — the table order IS the
tie-break. Diagram-comment above the table in the file, per the house idiom
(`daily_pick.rb`, `auto_fill!`).

**Dry-run before any UI work (outside voice O5):** run the shipping table over the
committed manifest and record per-tradition yields in this file's Deviations,
reconciled against 0008 §3.5's probe counts (probe said Rajput 102 / Korean 32 /
Jain 52; the shipping table's stricter matching lands lower — the dry run says
exactly where, per bucket, before the audit exists). The mapping table was named
"the work"; the dry run is proof it was actually run against the data it
classifies, at plan time, not discovered at QA.

### 3. Seed + backfill

- `db/seeds.rb` writes `tradition` at seed time — recomputed every reseed, no
  manifest change (0022 D2's exact pattern, same reasoning).
- Prod: one-off `bin/rails runner` backfill over existing rows (0022's precedent —
  a full reseed moves 0.66 GB of plates for a metadata-only change).

### 4. `/feed` row + controller

- **`Painting::FACETS` gains `:tradition`** (eng review Issue 1 — the machinery is
  generic by column but allowlist-gated: `FACETS = %i[genre period].freeze` at
  `painting.rb:134`, and `facet_counts` raises `ArgumentError` on anything else.
  The raise is a real guard and stays; the constant and its comment update).
  Display ordering: alphabetical — the existing `values.sort` branch already does
  it; only `:period` sorts numerically.
- `PaintingsController#index`: resolve `params[:tradition]` exactly as `:period` /
  `:genre` (same reduction-function idiom), compose into the same scope chain,
  **and add the key to `@filter_params`** — that hash is hand-built per facet
  (`paintings_controller.rb:39-42`) and a missed key silently drops the filter at
  lazy page 2, the exact class of the shipped artist-link-past-page-1 bug
  (`5d90908`).
- View: third `_facet_row` render under genre. Row hidden entirely when no value
  clears `MIN_FACET_WORKS` — by construction, not data hygiene.
- Masthead filtered-count aside already generic; verify, don't rebuild.

### 5. The audit (success signal 2, R1) — two instruments, committed

Committed as a rake task (eng review Issue 4 — story 0026's `fill_themes` reruns
it against the expanded pool; an ad-hoc one-liner gets rewritten from memory):

1. **Precision sample:** 50 random tradition-stamped rows (title, artist, culture,
   stamped value); hand-check; ≥ 95% or the offending pattern narrows/drops.
   Extra sampling weight on the Persian & Islamic bucket (smallest, most
   org-chart-driven — step 2).
2. **Reconciliation table (outside voice O2):** per-tradition stamped counts
   against 0008 §3.5's probe counts. The precision sample can only see false
   positives; a starved bucket (the Jain-without-`gujarat` failure this review
   caught at plan time) is invisible to it — an unstamped work is never in the
   sample. The reconciliation is the instrument for the other half of the risk.

Both results → Deviations. The audit is the enforcement that ships with the
mapping table.

### 6. Tests (with the work — R1)

- `Pool::Tradition` unit: every pattern row (fixture per tradition), precedence
  (Mughal-vs-Persian double-fire; **Korea-vs-Japan on the verbatim "Korea,
  Japanese colonial period (1910−1945)" string**), nil on blank/unmatched, the
  dropped-pattern regression (bare "Rajasthan, 19th century" → nil, pinned),
  **word-boundary negatives ("Indochina" ↛ Chinese, "Normandie" ↛ Pahari) and a
  mixed-case culture string**, **placeholder-artist union ("Mewar school" in the
  artist field with blank culture → Rajput; a real artist name containing a term,
  e.g. "Kota Ezawa", → nil)**.
- Controller/integration: `?tradition=` filters; unknown slug → no filter (the 0022
  behavior); **combined three-facet `?tradition=&period=&genre=`**; **lazy page 2
  of a filtered feed keeps the tradition filter** (the `@filter_params` threading —
  regression class `5d90908`); **AND-to-zero including tradition renders the
  "Nothing here wears both" empty state**; empty facet renders no row; unfiltered
  page unchanged — extend the existing byte-comparison at
  `test/integration/feed_filter_test.rb:6`.
- `pool_quota_test`: every non-nil tradition value is in the canonical vocabulary
  (no free-text leaks into the facet).
- Fixtures gain culture-string rows per tradition (the six-blocking-fixture-rows
  lesson from 0018 — priced in, not discovered).
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
- **Third facet row adds one indexed `GROUP BY` per page render** (~11 lazy fetches
  per full scroll ×1 extra query, sub-ms each on ≤3K rows). Reviewed and accepted
  as-is (eng review Issue 6) — memoization here is premature; revisit only if
  facet count or pool grows 10×. **Correction (code review):** the actual
  per-facet cost was two queries, not one — `resolve_facet_slug` and
  `displayed_facet_values` each independently called `facet_counts`. Fixed by
  passing pre-fetched counts through both (`counts:` kwarg), not by caching
  across requests — the "premature to cache" call above still stands; this
  was a same-request duplicate query, the exact shape story 0020 already
  fixed once for `Painting.count`.

## What already exists (reused, not rebuilt)

`displayed_facet_values` / `facet_counts` / `MIN_FACET_WORKS` (0022 R1 — generic by
column, gated by the `FACETS` allowlist step 4 extends); `_facet_row` partial +
slug resolution idiom; the unfiltered-page byte-comparison test at
`test/integration/feed_filter_test.rb:6` (extended, not rewritten);
`Painting::NOT_AN_ARTIST` + `artist_slug_for` as the placeholder detector step 2's
artist-field union reuses; `PeriodBucket` as the pure-function template;
`GenreTerms` as the ordered-dictionary template; the 0008 data files as the
vocabulary + sizing source.

## Failure modes (eng review, with coverage status)

| Failure | Test | Handling | Visibility |
|---|---|---|---|
| Substring misfire (Indochina→Chinese) | negative fixtures | \b anchoring | audit catches residue |
| Starved bucket never renders | reconciliation audit | `gujarat` restored | admin-invisible, audit-visible |
| Colonial-Korea mislabeled Japanese | verbatim-string fixture | Korea-first order | — |
| Filter dropped at lazy page 2 | integration test | `@filter_params` key | silent without test — covered |
| Stale/unknown slug | existing 0022 behavior test | resolves nil → unfiltered | graceful |
| AND-to-zero | integration test | existing empty state | "Nothing here wears both" |

No critical gaps: every silent failure mode above has a named test.

## NOT in scope (considered, deferred, with reasons)

- **Movement facet** — Rule 3 (decisions/0016): arrives by P135-verified artists
  via the reconciliation story, not by strings.
- **Ukiyo-e as a value** — waits for 0026's 16 nikuhitsu works; ~18 Edo paintings
  under a 306K-lookup label over-promises.
- **`/days` filtering** — chronological by design (0022 D4).
- **Description-text matching** — the Kalpa-sutra folios are identifiable from
  `description`, but culture strings already carry them via `gujarat`;
  description matching is a bigger precision risk for zero additional supply.
- **Facet-value caching** (Issue 6) — measured sub-ms; premature.
- **Manifest changes** — derivation is seed-time pure function (0022 D2 pattern).

## Deviations

**Dry run, before any UI work (2026-08-20), per plan step 2's mandate.** Shipping
table run over the committed 2,000-work manifest:

| Tradition | Shipping table | 0008 §3.5 probe | Δ | Why |
|---|---:|---:|---:|---|
| Japanese Painting | 276 | 276 | 0 | exact match |
| Chinese Painting | 180 | 180 | 0 | exact match |
| Mughal Painting | 103 | 102 | +1 | placeholder-artist union (`Painter: Mughal school`) |
| Rajput Painting | 93 | 102 | −9 | bare `rajasthan` deliberately dropped (plan call) |
| Pahari Painting | 85 | 84 | +1 | placeholder-artist union |
| Jain Manuscript Painting | 53 | ~52 | +1 | `gujarat` retained per O1; without it: **1** |
| Kalighat Painting | 44 | 44 | 0 | exact match |
| Korean Painting | 32 | 32 | 0 | exact match, Korea-first order confirmed on all 4 colonial-era rows |
| Tibetan & Nepalese Painting | 24 | 24 | 0 | exact match |
| Persian & Islamic Painting | 19 | 19 | 0 | exact match |

All 10 clear `MIN_FACET_WORKS = 5` by a wide margin (min 19). Total stamped:
909/2,000 (45.5%) — expected, since 0008's probe covered exactly these 10
buckets and nothing else. Rajput's −9 is the one deliberate departure from the
probe count, traced to the `rajasthan` drop named in step 2 — not a bug.
Placeholder-artist union verified firing correctly — and verified NARROW:
`Mewar school` and `Painter: Mughal school` are genuine `NOT_AN_ARTIST`
placeholders (country `India` alone matches no table term; the artist string
is the only signal), correctly resolving to Rajput/Mughal. `Workshop: Studio
of Ding Yunpeng` and `Baysunghur school` are NOT on the deny-list — real (if
uncredited) attributions — and correctly do NOT participate in the match;
their rows resolved via `country` (China, Iran) instead. Unit test caught
this the moment it was written (a first-draft assertion assumed `Baysunghur
school` was a placeholder like the others; it isn't), which is exactly what
the placeholder-gated design is for. A real-name false-negative check
(`Workshop or Circle of Wäldä Maryam`, Ethiopian culture) correctly resolves
nil — no tradition in the table claims Ethiopian work.

**Backfill + audit run against the dev DB (2026-08-20).** `bin/rails
tradition:backfill` stamped 910 of 2,002 rows (2 more than the manifest's 909 —
fixture rows carrying real culture strings). `bin/rails tradition:audit`:
reconciliation table matched the manifest dry-run above exactly; precision
sample of 50 rows, weighted toward the smallest bucket (Persian & Islamic, 10
of its 19), hand-checked at **49/50 correct (98%)** — clears the 95% gate.

**The one miss is the exact risk named in step 2's Persian & Islamic call:**
"Great Indian Fruit Bat" by Bhawani Das (a Mughal court painter, country
`India`, culture blank) stamped Persian & Islamic Painting purely because the
Met's own department field reads `"Islamic Art"` — an org-chart artifact, not
a tradition claim. This is very likely the same work outside voice finding O7
flagged from static reading ("one work matches only on the Met's Islamic Art
department"), now confirmed live. **Accepted, not fixed**: excluding
department-only matches would need a stronger signal than this story budgets
for (co-occurring culture/country, or a department-specific carve-out), and
one work in a 19-work bucket is 95%+ on its own count. Logged here as the
concrete instance of a risk the plan already named and gated, not a surprise.

| Review | Trigger | Why | Runs | Status | Findings |
|--------|---------|-----|------|--------|----------|
| CEO Review | `/plan-ceo-review` | Scope & strategy | 0 | — | — |
| Codex Review | `/codex review` | Independent 2nd opinion | 0 | — | Codex auth OK but usage-limited until Sep 9; Claude subagent ran instead |
| Eng Review | `/plan-eng-review` | Architecture & tests (required) | 1 | CLEAR (PLAN) | 6 issues (2 arch, 2 quality, 1 test-gap bundle of 4, 1 perf-accepted), 0 critical gaps, all folded |
| Design Review | `/plan-design-review` | UI/UX gaps | 0 | — | Skipped: UI-light (build flow step 3), noted in plan header |
| DX Review | `/plan-devex-review` | Developer experience gaps | 0 | — | — |

- **CROSS-MODEL:** Outside voice (Claude subagent, fresh context, simulated the
  mapping table over all 2,000 manifest rows) returned 7 findings: 6 accepted and
  folded (Jain bucket starved without `gujarat` — verified 1 vs 51 works;
  Korea-before-Japan precedence — 4 colonial-era works; placeholder-artist union —
  12 works; audit reconciliation instrument; plan-time dry run; word boundaries =
  agreement with in-section Issue 3), 1 partial (Persian & Islamic merge kept,
  named as an explicit call with audit attention). One tension: outside voice
  called the facet machinery reusable with "nothing new"; the review's Issue 1
  quoted the `FACETS` allowlist raise at `painting.rb:134` — resolved in the
  review's favor, FACETS addition required.
- **VERDICT:** ENG CLEARED — ready to implement. All decisions auto-resolved to
  the reviewer's recommendation on the operator's standing instruction, each
  recorded at its fold site.

NO UNRESOLVED DECISIONS
