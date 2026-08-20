# 0025 — What the title says — implementation plan

Date: 2026-08-20
Story: `story.md`. Direction: `decisions/0016` (sequence position 2 of 3).
Design review: **skip proposed — no UI change** (the genre row already renders; this
story only gives it data). Eng review: **done 2026-08-20 — 12 findings folded** (F1–F12
below; report at end). Outside voice: Claude subagent (Codex at usage limit); its
manifest measurements marked "OV-measured", re-measure at implement time.

## Shape

A second, lower-precedence source for the same `genre` column. Museum tags won 0022's
release; titles fill what tags left nil.

```
db/seeds.rb per work:
  genre = manifest genre (museum-tag route, 0022)   ← tags outrank titles
          || Pool::TitleGenre.infer(title)          ← this story, TITLE-ONLY (D2)
          || nil
```

### D1 — Provenance ladder, stated once

Museum tag > title inference > nil. Rationale: a tag is the museum saying what the
work *is*; a title match is us reading what the museum *called* it. The ladder lives
in two places that cannot drift — the seed expression above and `backfill!` (D4),
both the same one-line composition — and a `genre_source` column is **not** added:
provenance is derivable (manifest carries the tag-route value; anything else non-nil
is title-route). Eng review agreed — column stays out.

### D2 — The dictionary: high-precision patterns only

`lib/pool/title_genre.rb`, the `Tradition` shape exactly (F: primary donor is
`lib/pool/tradition.rb`, not just the `GenreTerms` idiom): `TABLE` of
`[value, patterns]`, first match wins, compiled to `PATTERNS` once at load.

**Title-only. Description matching is dropped entirely (F2).** OV-measured over
CMA/MIA rows: description-only matching buys ~31 fills (~1.5% coverage) and its first
sampled hit is a false positive — *"Falcon on a Perch"*, description "this painting
may be a portrait of a favorite bird" → stamped Portrait. Museum prose hedges ("may
be", "reminiscent of", "unlike his portrait of…") are exactly what anchored patterns
cannot see coming. `infer(title)` — one argument, one precision surface. This also
kills a divergence edge: `db/seeds.rb:43` preserves DB description when the
manifest's is blank, so a desc-reading backfill and the manifest-derived tests could
disagree; a title-only function cannot.

Table order (Religious FIRST — F3: 11 genre-nil titles contain "lotus", including
*"Divine couple seated in a lotus blossom"* — a deity scene that Flowers-before-
Religious would mislabel; same wrong-label-worse-than-no-label lesson as 0024's
Korea-before-Japan):

- `Religious Art` — the 0008 probe's deity/saint name list, each name reviewed
- `Mythological Art` — classical-deity list
- `Portrait` — `/\bportrait of\b/`, `/\bself-portrait\b/`, leading `/^portrait\b/`
- `Still Life` — `/\bstill life\b/`
- `Flowers` (new canonical value) — anchored shapes only (F3: the bare-noun
  named-flower list contradicted this section's own principle and is dropped):
  `/\bbouquet\b/`, `/\bvase of (flowers|roses|…)\b/`, `/\bbird[s]? and flower[s]?\b/`,
  and **leading-position** flower plurals (`/^(peonies|chrysanthemums|irises|lotus…)\b/`
  — a title that IS the flower name is the museum saying what the picture is;
  mid-string is not)
- `Landscape` — `/^landscape\b/`, `/\blandscape with\b/`, `/^view of\b/` — with an
  audit watch (F11): "View of Delft"-shaped city views land Landscape; with Cityscape
  unreachable (below) this is the known mislabel class the audit samples for
- `Marine Art` — `/\bseascape\b/`, `/\bshipwreck\b/`, `/\bharbou?r\b/`
- `Genre Scene`, `Nude` — anchored shapes, **conditional**: ship only if measured
  yield clears the floor deficit (today 1 and 3 works; need net ≥ 4 and ≥ 2 to ever
  render). D5's reconciliation is the check; patterns that can't light drop.

Explicitly out:
- `Cityscape` (F11) — probe ceiling 1 candidate + 1 tag-route work = 2, can never
  clear `MIN_FACET_WORKS` 5. Pattern work that ships an invisible value.
- `Animal Painting` patterns (192 hits, worst noise — birds and lions inside
  religious titles). Animal stays museum-tag-only this story.

**Vocabulary deviation, stated (F9):** 0022's constraint reads "Getty AAT terms, not
an invented taxonomy"; AAT's genre concept here is "flower pieces". `Flowers` ships
as the display value anyway — it is the reader's word (0008 §3.3: "paintings of
flowers") and the facet exists to speak reader language. Deliberate, logged here,
not a silent widening. `GenreTerms`'s header comment gets one line noting the
exception.

The 0008 probe (`scripts/0008/pool_coverage.py`) is the candidate source; every
pattern promoted from it gets a fixture.

### D3 — The CMA/MIA invariant test STANDS; derived-genre tests join it (F1, F8)

The original decision ("rewrite `pool_quota_test.rb:206`, this story falsifies it on
purpose") was wrong about its own mechanics: title-route genre is a **seed-time
derivation** — it never writes the manifest, and `GenreFill` still touches only
AIC/MET. So "no CMA or MIA *manifest row* carries a genre" remains TRUE and remains
load-bearing (it still catches a future `GenreFill` change accidentally writing
CMA/MIA). **It stays verbatim.**

What's added, mirroring `POOL_TRADITIONS`: one pass deriving genre per manifest row
(`manifest genre || TitleGenre.infer(title)`), then:
- every derived value is in the canonical vocabulary
  (`GenreTerms::DICTIONARY.values ∪ TitleGenre::TABLE` values)
- coverage floor pin (number set from measured shipped coverage; ≥ 500 per success
  signal 1, or the shortfall ships logged per the story's falsification clause)
- `Flowers` clears `MIN_FACET_WORKS` on the committed pool (success signal 3 as a
  test, 0024's floor-test shape)

The originally-proposed "every CMA/MIA genre is derivable by `infer`" assertion is
circular (F8) — it recomputes the function that produced the value, so it can only
catch seed-wiring bugs, never wrongness. It is demoted to a unit-level precedence
test (manifest value wins over a conflicting title match), not sold as an invariant.

### D4 — Backfill recomputes EVERY row, like `Tradition.backfill!` (F7)

The drafted "genre-nil rows only" runner was one-way: a wrong title-route value
shipped to prod could never be retracted by narrowing the dictionary — reruns would
skip it. `Pool::TitleGenre.backfill!` mirrors `Pool::Tradition.backfill!`
(`lib/pool/tradition.rb`): for every row,
`genre = manifest_tag_value || infer(title)`, `update_column` when changed, nil
allowed. Tag-route values come from the committed manifest (ships with the app),
loaded once as a `(source, source_id) → genre` map. Narrow the dictionary, rerun,
and the retraction lands. Museum-tag values are reproduced from the manifest map, so
the non-goal ("tag fills stand") holds by construction.

### D5 — Audit is a module method with 0024's two instruments (F5, F6)

`Pool::TitleGenre.audit` + thin `genre:audit` rake printer (the `tradition.rake`
shape — logic on the module, Minitest-coverable, callable by 0026's `fill_themes`).
Two instruments, both 0024's:

- **Precision sample — 100 rows, weighted toward the smallest bucket.** 50 unweighted
  at a 95% bar is a coin flip (F5: at true precision exactly 95%, P(≥3 errors in 50)
  ≈ 46% — a dictionary that meets the bar fails half the time). 100 rows, smallest-
  bucket weighting (`SMALLEST_BUCKET_WEIGHT` idiom — F6: 0024's hardest-won audit
  lesson, which the draft dropped), gate ≥ 95%; a 93–95% result = narrow-and-rerun,
  not ship-and-hope.
- **Reconciliation vs 0008 §3.6 probe ceilings.** Ceilings are upper bounds, not
  expectations, so the starved flag reads "well under half the ceiling" — it catches
  a pattern set silently yielding a never-rendering value (the Jain-bucket class of
  regression), including D2's conditional Genre Scene / Nude call.

## Steps

1. `Flowers` exists as a `TitleGenre::TABLE` value; the canonical-vocabulary test set
   becomes `GenreTerms` values ∪ `TitleGenre` values. **No `GenreTerms` dictionary
   change** (F4: the manifest carries no raw tags, so new tag-dictionary keys are
   dead code unless `pool:genre_fill` re-runs over AIC/MET — that re-run belongs to
   the expansion story). **No facet-ordering work** (F10: `displayed_facet_values`
   already sorts non-period facets alphabetically; `genre` is already in `FACETS` —
   there is nothing to add).
2. `Pool::TitleGenre` (`TABLE` → compiled `PATTERNS` at load, `tradition.rb` shape) +
   fixture per pattern + the negative zoo: "Portrait with a View of Delft" →
   Portrait; "Divine couple seated in a lotus blossom" → Religious, not Flowers;
   a keyword only in the description does NOT fire (title-only pinned by signature);
   "Landscape Study, verso" edge; blank/nil title; Japanese/Chinese-language title
   → nil (the language-skew risk, pinned).
3. Seed expression (D1) + `TitleGenre.backfill!` (D4) + `TitleGenre.audit` (D5) +
   thin `genre:backfill` / `genre:audit` rake printers.
4. Audit run: 100-row weighted sample, hand-check, ≥ 95% gate → result in Deviations
   (R1: the gate ships with the fill).
5. Tests: unit (every pattern, table order, negatives, precedence, backfill —
   fills nil rows, retracts on dictionary narrowing, never disturbs a tag-route
   value); `pool_quota_test` additions per D3 (old test untouched); integration
   (`?genre=flowers` filters; floor pin); system tap-through.
6. `bin/ci` → `/qa` → `/simplify` → `/code-review` → re-verify → ship, deploy +
   backfill (operator), `SHIPLOG.md` receipt: coverage before/after + audit
   precision number.

## Risks, named

- **The 500 floor leans on the Religious list (OV-measured).** Anchored title-only
  yield for Portrait/Landscape/Still Life/Flowers/Marine measures ~226
  (119/51/21/28/7); reaching 500 needs Religious to deliver ~230 of its 302 ceiling
  — and that is the list the audit is most likely to narrow. Success signals 1 and 2
  are in tension, not independent; the story's falsification clause is the pressure
  valve, and the honest shortfall ships if they collide. Re-measure at implement.
- **Precision under 95%** — patterns narrow or drop; falsification clause in the
  story rather than pressure to ship noise.
- **Title language skew** — non-English titles (Chinese, Japanese works) mostly miss
  keyword English; those works are exactly 0024's tradition facet's job. Stated so
  nobody reads title-route coverage as pool-wide.
- **Double-labeling drift between routes** — unified by both mapping into the same
  canonical values; one vocabulary, two routes.
- **R7, named plainly (F12, outside voice):** no datum yet shows readers tap
  `?genre=` at all — every success signal here is an input metric. Not a blocker
  (direction settled, `decisions/0016`), but the expansion story should not start
  without a facet-usage receipt; ask logged in `IDEAS.md` Inbox.

## NOT in scope

- `genre_source` column — provenance derivable (D1); infrastructure for later.
- Description matching — measured noise for ~1.5% coverage (D2/F2).
- `Cityscape` title patterns — cannot clear the display floor (D2/F11).
- `Animal Painting` title patterns — worst noise class; museum-tag-only (D2).
- `GenreTerms` flower keys + `pool:genre_fill` re-run — dead code without the
  network re-run; expansion story's job (Steps/F4).
- New vocabulary beyond Flowers; tradition axis; movement axis (story non-goals).

## What already exists

`lib/pool/tradition.rb` — the primary shape donor: `TABLE`→`PATTERNS` compile,
`backfill!`, `audit` with weighted sample + reconciliation, thin rake printers.
Genre column + index + facet row (0022 R1); `GenreTerms` ordered-dictionary idiom
and its canonical values; `POOL_TRADITIONS` manifest-invariant test pattern
(`test/lib/pool_quota_test.rb`); the 0008 probe as candidate list; audit-gate idiom
from 0024. The plan reuses all of them; nothing is rebuilt.

## Deviations

(filled at implement time — audit result, floor-pin number, pattern drops)

## Implementation Tasks

Synthesized from the eng review's findings. Checkbox as you ship.

- [ ] **T1 (P1, human: ~4h / CC: ~25min)** — `lib/pool/title_genre.rb` — build `Pool::TitleGenre`: title-only, Religious-first `TABLE`, compiled `PATTERNS` at load
  - Surfaced by: F2 (desc-route noise), F3 (lotus/deity ordering), D2
  - Verify: `bin/rails test test/lib/pool_title_genre_test.rb`
- [ ] **T2 (P1, human: ~2h / CC: ~15min)** — `test/lib/pool_quota_test.rb` — keep CMA/MIA manifest invariant verbatim; add derived-genre vocabulary + floor-pin + Flowers-floor tests (`POOL_TRADITIONS` shape)
  - Surfaced by: F1, F8 (D3)
  - Verify: `bin/rails test test/lib/pool_quota_test.rb`
- [ ] **T3 (P1, human: ~2h / CC: ~15min)** — `TitleGenre.backfill!` recomputes EVERY row via manifest map `|| infer`, nil allowed (retraction path) + thin `genre:backfill` rake
  - Surfaced by: F7 (D4)
  - Verify: unit test — fills nil, retracts on narrowed dictionary, never disturbs tag-route value
- [ ] **T4 (P1, human: ~3h / CC: ~20min)** — `TitleGenre.audit`: 100-row smallest-bucket-weighted sample + reconciliation vs 0008 ceilings; thin `genre:audit` rake
  - Surfaced by: F5, F6 (D5)
  - Verify: audit run output + hand-check → Deviations
- [ ] **T5 (P2, human: ~2h / CC: ~15min)** — negative-zoo fixtures: lotus deity scene, "View of Delft", desc-only no-fire, "Landscape Study, verso", blank/CJK titles
  - Surfaced by: D2 negative zoo + F3
- [ ] **T6 (P2, human: ~1h / CC: ~10min)** — drop Cityscape patterns; Genre Scene/Nude conditional on measured floor clearance via reconciliation
  - Surfaced by: F11

_No new tasks from Performance review._

## GSTACK REVIEW REPORT

| Review | Trigger | Why | Runs | Status | Findings |
|--------|---------|-----|------|--------|----------|
| CEO Review | `/plan-ceo-review` | Scope & strategy | 0 | — | — |
| Codex Review | `/codex review` | Independent 2nd opinion | 0 | — | — |
| Eng Review | `/plan-eng-review` | Architecture & tests (required) | 1 | CLEAR (PLAN) | 12 issues, 0 critical gaps |
| Design Review | `/plan-design-review` | UI/UX gaps | 0 | — (skip proposed: no UI change) | — |
| DX Review | `/plan-devex-review` | Developer experience gaps | 0 | — | — |

- **CROSS-MODEL:** Outside voice ran as Claude subagent (Codex CLI at usage limit until 2026-09-09). Its 12-point challenge overlapped 5 of this review's findings (dead-code tag terms, no-op facet ordering, sub-floor Cityscape, audit weighting, D3 mechanics) and added 7 verified against the manifest (desc-route false positive, lotus/deity ordering, 500-floor tension, sample-size statistics, one-way backfill, AAT deviation, R7 usage gap). All folded with user pre-authorization ("go with your recommendation for all decisions").
- **VERDICT:** ENG CLEARED — ready to implement (0025 starts when the WIP slot opens; 0024 is shipped and logged).

NO UNRESOLVED DECISIONS
