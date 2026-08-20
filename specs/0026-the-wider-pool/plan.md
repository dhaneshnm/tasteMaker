# 0026 — The wider pool — implementation plan

Date: 2026-08-20
Story: `story.md`. Direction: `decisions/0016` (executes its predictions 1–2).
Depends on: 0024 + 0025 shipped (their pure functions stamp the new works' tradition
and genre at seed time — expansion rides the findability machinery, which is the
whole point of the sequencing).
Design review: **skip proposed — no UI change** (facets light via existing floor
logic). Eng review: owed before implement; the pinning mechanism (step 2) is the part
that most needs its eyes.

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

### 2. Pinning — the new invariant

`Curator#curate!` takes the committed manifest's `(source, source_id)` pairs and
`take`s those candidates first, before any fill stage, bypassing none of
`reject_unusable` (a pinned work that lost its image upstream must surface loudly,
not silently drop — that is a human decision, listed by the report, same idiom as
the deny-list flow).

- **Pin assertion in `pool_quota_test`:** every pair in the previous committed
  manifest appears in the new one. The previous manifest is the fixture (committed
  file, so the test needs no network and no DB).
- Feed order: existing works keep relative `feed_order`; new works interleave after —
  exact scheme is an implement-time detail noted back here, with the constraint that
  a reader's bookmarked `/feed` page must not reshuffle wholesale.

### 3. `fill_themes` — the demand stage

New stage, `fill_recognizable`'s sibling (same structure: want-list, take-until-met,
report shortfall):

- **Target list** (theme → matcher → want), committed as data
  (`lib/pool/theme_targets.rb` or `.yml`), quotas from story success signal 2.
  Matchers reuse `Pool::Tradition` (0024) and `Pool::TitleGenre` (0025) against
  candidate fields — **the same functions that will stamp the facets at seed time**,
  so "counted toward the quota" and "lights the facet" cannot disagree (the 0023
  `queue_healthy?` lesson, applied in advance).
- Strict-ukiyo-e and Madhubani matchers are small additions to `Pool::Tradition`'s
  table (`ukiyo`, `floating world`; `madhubani`, `mithila`) — added in this story,
  flagged `MIN_FACET_WORKS`-gated exactly like every other value.
- **Madhubani rights check by hand** before the quota fills: 9 CMA candidates,
  20th-century folk works — CC0 status verified per object against CMA's own API
  field, recorded in Deviations. If any fail, the quota shorts and the report says
  so (story falsification 2).
- Order inside the stage: description-bearing candidates first (protects the text
  bar), then blurbless up to each theme's want.

### 4. Curation run + audit

- `pool:curate` against the 2026-08-13/18 mirrors (refresh mirrors first if stale —
  operator call; the probe numbers came from these files, so same-vintage is the
  honest default).
- The pool report gains a per-theme table: want / took / shortfall / reason — the
  0019 report idiom extended, and the artifact decisions/0016 prediction 2 is read
  against on Sep 20.
- Plate cache: `pool:plates` (or the existing image-fetch task) pulls ~1,000 new
  plates ≈ +0.33 GB under `storage/` on the volume. Met candidates resolve images at
  selection time via `resolve_met_image`, existing behavior.

### 5. Seeds, deploy, backfill

- `db/seeds/paintings.json` → 3,000 works; `pool_report.md` updated alongside
  (R1: measurement ships with the artifact).
- Deploy via Kamal (operator — agent shell lacks secrets). Prod backfill: additive
  seed of the 1,000 new rows + plates; existing rows untouched (no destructive
  reseed against live favorites/picks — the pin makes this safe by construction,
  and the runner asserts counts before/after).
- 0023 interplay check, post-deploy: `DailyPick.auto_fill!` candidate scope now
  draws from 3,000; spacing ladder gets more room; nothing to change, one smoke
  query to confirm the queue still fills (recorded in Deviations).

### 6. Tests (with the work — R1)

- Pin assertion (step 2) — the one test that guards Jordan.
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
  the proof, not this sentence.
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

## What already exists (reused, not rebuilt)

Curator stage pattern (`fill_recognizable`), bars-as-shares, `verify!`/`Unmeetable`,
pool report idiom (0019), `resolve_met_image`, plate cache task, `Pool::Tradition` +
`Pool::TitleGenre` (0024/0025 — the dependency), 0008 probe data as the want-list
source, deny-list/report flow for human-decision surfacing.
