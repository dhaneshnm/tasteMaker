# 0025 — What the title says — implementation plan

Date: 2026-08-20
Story: `story.md`. Direction: `decisions/0016` (sequence position 2 of 3).
Design review: **skip proposed — no UI change** (the genre row already renders; this
story only gives it data). Eng review: owed before implement.

## Shape

A second, lower-precedence source for the same `genre` column. Museum tags won 0022's
release; titles fill what tags left nil.

```
db/seeds.rb per work:
  genre = manifest genre (museum-tag route, 0022)      ← tags outrank titles
          || Pool::TitleGenre.infer(title, description) ← this story
          || nil
```

### D1 — Provenance ladder, stated once

Museum tag > title inference > nil. Rationale: a tag is the museum saying what the
work *is*; a title match is us reading what the museum *called* it. The ladder lives
in one place (the seed expression above) and a `genre_source` is **not** added —
provenance is derivable (manifest carries the tag-route value; anything else non-nil
is title-route), and a column recording it is infrastructure for later until an audit
actually needs it. If eng review disagrees, that is the one cheap reversal here.

### D2 — The dictionary: high-precision patterns only

`lib/pool/title_genre.rb`, ordered (first match wins — `GenreTerms` idiom), patterns
chosen for precision over recall. Anchored phrase shapes, not bare nouns:

- `Portrait` — `/\bportrait of\b/`, `/\bself-portrait\b/`, leading `/^portrait\b/`
- `Still Life` — `/\bstill life\b/`
- `Flowers` (new canonical value) — `/\bbouquet\b/`, `/\bvase of (flowers|roses|…)\b/`,
  `/\bbird[s]? and flower[s]?\b/`, named-flower list (`peony|lotus|chrysanthemum|…`)
  **in title only**
- `Landscape` — `/^landscape\b/`, `/\blandscape with\b/`, `/^view of\b/` (not mid-string
  "view of" — "Portrait with a View of Delft" is a portrait)
- `Marine Art` — `/\bseascape\b/`, `/\bshipwreck\b/`, `/\bharbou?r\b/` title-only
- `Religious Art` — the 0008 probe's deity/saint list, title-only, each name reviewed
- `Mythological Art` — classical-deity list, title-only
- `Cityscape`, `Genre Scene`, `Nude` — the few anchored shapes that survive audit

Explicitly out: the probe's `Animal Painting` patterns (192 hits, worst noise — birds
and lions inside religious titles). Animal stays museum-tag-only this story.

Description text participates only for `Still Life` and `Portrait` anchored phrases;
everything else is title-only. The 0008 probe (`scripts/0008/pool_coverage.py`) is the
candidate source; every pattern promoted from it gets a fixture.

### D3 — The CMA/MIA invariant test is rewritten, not deleted

`pool_quota_test.rb:206` ("no CMA or MIA work carries a genre") was true because tags
were the only route; this story falsifies it **on purpose**. It becomes two
assertions: every non-nil genre is in the canonical vocabulary, and every CMA/MIA
genre is derivable by `TitleGenre.infer` from that row's own title/description (no
value that neither route explains). The old test's intent — provenance honesty —
survives; its letter dies with the route monopoly. Eng-review flag from 0022's own
plan, now due.

## Steps

1. `Flowers` joins the canonical vocabulary (`GenreTerms` values + facet ordering);
   museum-tag dictionary gains flower terms too (AIC tags carry them).
2. `Pool::TitleGenre` + fixtures per pattern, including the negative zoo:
   "Portrait with a View of Delft" → Portrait; deity-name inside an artist name does
   not fire; "Landscape Study, verso" edge; blank title.
3. Seed expression (D1) + prod backfill runner over genre-nil rows only (0022/0024
   precedent — metadata-only, no reseed).
4. Audit script: 50 random title-route fills, hand-check, ≥ 95% gate → Deviations
   (R1: the gate ships with the fill).
5. Tests: unit (dictionary + precedence + negatives), `pool_quota_test` rewrite (D3),
   integration (`?genre=flowers` filters; coverage count ≥ 500 asserted as a floor
   pin so a future reseed can't silently regress it), system tap-through.
6. `bin/ci` → `/qa` → `/simplify` → `/code-review` → re-verify → ship, deploy +
   backfill (operator), `SHIPLOG.md` receipt: coverage number before/after.

## Risks, named

- **Precision under 95%** — patterns narrow or drop; coverage target has an explicit
  falsification clause in the story rather than pressure to ship noise.
- **Title language skew** — non-English titles (Chinese, Japanese works) mostly miss
  keyword English; those works are exactly 0024's tradition facet's job, so the two
  stories cover complementary halves. Stated so nobody reads title-route coverage
  as pool-wide.
- **Double-labeling drift between tag route and title route** for the same concept
  (tag "portraits" vs title "Portrait of") is unified by both mapping into the same
  canonical values — one vocabulary, two routes.

## What already exists

Genre column + index + facet row (0022 R1); `GenreTerms` ordered-dictionary idiom;
backfill-runner precedent (0022, 0024); the 0008 probe as candidate list; audit-gate
idiom from 0024.
