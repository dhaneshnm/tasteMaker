# 0013 — Implementation plan
Status: Done

**Design review:** skipped. No new screen, no new component, no layout change. The only
reader-visible diff is three attribution strings that name one museum today and must name
four. Noted per `CLAUDE.md` build flow step 3.

**Eng review:** not run — the curator asked for plan-and-implement in one pass on
2026-08-13. Recorded as a deviation from build flow step 4, not as an exemption. Anything
direction-level found while building goes to `decisions/` (R4).

## What the probes settled

Everything below is measured, 2026-08-13, not assumed. These four findings are what the
plan is shaped around.

| # | Finding | Consequence |
|---|---|---|
| F1 | Met publishes **no** curatorial text — the field does not exist in API or CSV | Met works arrive mute; the ≥70% text bar is what keeps Met from swamping the pool |
| F1b | Met PD **paintings** are **5,578**, not the 14,297 in the story — that count was paintings-with-images at any licence. Measured off the CSV, 2026-08-13 | Candidate pool is **~15,270**, not ~24,000. Still 7.6× the target, and Met can supply at most 30% of the pool under the text bar. Story's source table is corrected here, not silently |
| F2 | Met CSV is git-LFS; `raw.githubusercontent.com` returns a 130-byte pointer | Fetch from `media.githubusercontent.com/media/...` — verified, streams the real 317 MB |
| F3 | Met CSV has **no image URL column**, and PD does not guarantee an image | Curate from CSV, then resolve `primaryImage` by API for **selected works only** (~hundreds of calls, not 14,297) |
| F4 | MIA publishes per-record image rights: `rights_type`, `Rights_Image_Display`, `public_access` | The story's "MIA images may not clear" caveat is answered **in the data**. Filter on it; no blanket assumption either way |

Also measured: AIC IIIF serves `/full/1686,/` fine (level2, maxArea 124M) — an earlier 404
was my own bad identifier, not a size cap. Cleveland's `web` derivative is **never** ≥1600px
(0 of 20 sampled) while `print` is 3400px (19 of 20) — so Cleveland ingest must use `print`
or fail bar 7.

## Approach

Two commands, one boundary between them. **Metadata is mirrored wide and cheap; image bytes
are fetched narrow and slow.** That boundary is the whole design — it is what makes 2,000
images cost ~1 GB instead of 290 GB, and what makes re-curating later free.

```
bin/rails pool:mirror   → tmp/pool/*.json      (~24K painting records, gitignored)
bin/rails pool:curate   → db/seeds/paintings.json + db/seeds/pool_report.md  (committed)
bin/rails db:seed       → downloads bytes for the 2,000 selected, resumable
```

`pool:mirror` costs one 317 MB CSV plus **~28 API requests total** — Cleveland pages 1,000
at a time (4 requests), AIC 100 at a time (20), MIA 100 at a time. The rate-limit arithmetic
from the research (AIC 60 req/min → 17 hours) applied to crawling object-by-object; bulk
endpoints make it minutes. Nobody needs to crawl.

### Files

```
lib/pool.rb              Candidate struct, region mapping, year derivation, text test
lib/pool/sources.rb      four fetchers, one method each, all → Candidate
lib/pool/curator.rb      dedup, quota table, selection, bar checks
lib/tasks/pool.rake      pool:mirror, pool:curate, pool:report
db/seeds.rb              rewritten to read the new manifest; concurrent, resumable
```

Four source adapters exist because the four sources have genuinely different shapes — a
317 MB CSV, two JSON APIs with different filter grammars, and an Elasticsearch index. That
is not speculative abstraction; each is ~30 lines and none is a plugin point.

## Steps

### 1. Migration — identity stops being MIA's
`db/migrate/*_add_source_to_paintings.rb`:
- `rename_column :paintings, :mia_id, :source_id`
- `add_column :source, :string` — backfill `"mia"` for all 110 existing rows, then `NOT NULL`
- `add_column :image_license, :string` — per row, because MIA's rights are per record (F4)
- drop the renamed unique index, add unique `[:source, :source_id]`

No image re-download: the 110 rows keep their Active Storage attachments and their
`source_id` values are unchanged.

### 2. Model
- `Painting::SOURCES` — key → `{ name:, url: }` for `met`, `aic`, `cma`, `mia`. Names carry
  their own article (`"the Metropolitan Museum of Art"`) so they read correctly mid-sentence
  in "From …".
- `validates :source_id, uniqueness: { scope: :source }`; `validates :source, inclusion:`
- `#source_name`, `#source_url`, `#dom_key` (`"#{source}_#{source_id}"`)

### 3. Attribution — three hard-coded strings become four museums
- `app/views/daily/_day.html.erb:71` — `From <%= painting.source_name %>`
- `app/views/paintings/_page.html.erb:17` — link text and href from `SOURCES`
- `app/views/layouts/_head.html.erb:24` — meta description no longer promises one museum
- `app/views/paintings/_painting.html.erb:1` — DOM id `painting_<%= painting.dom_key %>`;
  `mia_id` is not unique across sources and the feed anchors on it

### 4. `lib/pool.rb` — one normalised candidate
`Candidate` carries: `source, source_id, title, artist, life_date, dated, year, medium,
dimension, country, culture, department, region, description, creditline,
accession_number, image_url_full, image_url_800, image_width, image_height, image_license,
highlight`.

Three derivations live here, because all four sources need them and none provides them:
- **`year`** — max 3–4 digit run in the date string (the same rule already used to measure
  the current pool)
- **`region`** — country/culture/continent/department → Europe, US & Canada, East Asia,
  South Asia, Southeast Asia, West Asia & Islamic world, Africa, Latin America, Oceania.
  Explicit mapping table, no heuristics-by-guessing.
- **`text?`** — description present **and** longer than a tombstone. Bar 6 is a claim about
  something a reader can read, so a 40-character provenance fragment is not text.

### 5. `lib/pool/sources.rb`

| Source | Fetch | Filter | Image URL | Text |
|---|---|---|---|---|
| Met | `media.githubusercontent.com` CSV, streamed by row | `Is Public Domain == True`, `Classification =~ /painting/i` | resolved later, per selected work (F3) | none (F1) |
| AIC | API `is_public_domain` + `artwork_type_title=Painting`, 100/page | has `image_id` | IIIF `/full/1686,/0/default.jpg` | `description` \|\| `short_description` |
| CMA | API `cc0=1&has_image=1&type=Painting`, 1000/page | `share_license_status == CC0` | `images.print` — **not `web`**, which is never ≥1600px | `description` |
| MIA | `search.artsmia.org/classification:Paintings`, 100/page | `image == "valid"`, `public_access == 1`, `rights_type == "Public Domain"`, `Rights_Image_Display == "Full"` | existing `img.artsmia.org` full/800 pattern | `text` |

Each writes `tmp/pool/<source>.json`. Re-running a single source is one command; the mirror
is a cache, not a build artifact, so it is gitignored.

### 6. `lib/pool/curator.rb` — the quota table *is* the curation

Deterministic. Seeded `Random.new(1889)`, the house convention already in `db/seeds.rb`.

1. **Reject** — no title; no image; longest edge < 1600px; no artist *and* no culture.
2. **Dedup** — key on normalised `title + artist`. Winner: has text, then larger image.
   Same work in two museums enters once.
3. **Select to 2,000**, scarcest bucket first, so the floors are met by construction rather
   than by luck:
   - per-artist ceiling **≤ 5** enforced throughout (today's ceiling is 3 of 110 = 2.7%;
     this is 0.25%)
   - fill the scarce floors first: Africa, Latin America, Southeast Asia, then post-1900,
     then text-bearing works
   - then fill the remainder round-robin across sources and regions, holding every cap
   - **no source above 50%**, **highlights between 10% and 10%** — the famous works stay as
     anchors and never dominate
4. **Assert every bar.** A run that cannot meet a bar **fails loudly and writes no
   manifest.** A quota table that degrades silently is not a quota table.
5. **Resolve Met image URLs** for selected Met works only, then top up from the remaining
   Met candidates for any whose `primaryImage` comes back empty (F3).
6. Emit `db/seeds/paintings.json` (the manifest) and `db/seeds/pool_report.md` (committed:
   counts per source, region, era, artist ceiling, text share, every bar's pass/fail).

### 7. `db/seeds.rb` — rewritten, same contract
- upsert on `[source, source_id]`; keeps the existing "never blank out museum text we
  already hold" rule
- **concurrent**: fixed pool of 6 threads, per-host politeness delay. Serial at 2,000 is
  ~50 minutes; this is the difference between a rerunnable step and one nobody reruns.
- **resumable**: an image already attached is skipped, exactly as today. An interrupted run
  resumes; it never restarts 2,000 downloads.
- resize to 1600px longest edge (unchanged), report fetched / skipped / failed / bytes

### 8. Test-file migration
`mia_id` appears in 20 places across 8 test files, the fixtures, and `test_helper.rb`.
All move to `source_id` + `source`. Fixtures gain `source: mia`.

## Tests

Written during implementation, not after (R1).

- **`test/lib/pool_quota_test.rb` — the forcing function.** Reads the committed manifest and
  asserts all eight numeric bars from the story: ≥2,000 works, ≥4 sources, none >50%, ≤5 per
  artist, ≥45% non-Euro/US, ≥15% post-1900, highlights ≤10%, ≥70% carrying text, every image
  ≥1600px. If a future reseed regresses range, `bin/ci` goes red. This is the rule and its
  enforcement landing in the same unit of work.
- **`test/lib/pool_curator_test.rb`** — on fixed synthetic candidates: dedup keeps the
  text-bearing copy; the per-artist ceiling holds under adversarial input (one artist with
  400 works); an unmeetable floor raises rather than silently under-filling; selection is
  reproducible across runs.
- **`test/models/painting_test.rb`** — same `source_id` under two sources is valid; the same
  pair twice is not; `source_name` / `source_url` / `dom_key` per source.
- **Attribution rendering** — a CMA-sourced day says "From the Cleveland Museum of Art", not
  Minneapolis. This is the bug the story exists to prevent shipping.
- **Existing suite green unchanged** — `daily_pick_test`, `favorite_test`, `feed_zoom_test`
  (integration + system), `dynamic_type_test`. Story 0005's "neither note nor museum text is
  invalid" rule is load-bearing here and must not move.

## Risks

- **The 70% text floor may not be satisfiable at 2,000** if dedup takes more text-bearing
  works than expected. Met is 14,297 of ~24,000 candidates and contributes zero text.
  Mitigation: the curator fails loudly with the shortfall named. If it fails, the honest
  fix is a lower pool count, not a lower text bar — story 0005's contract is what makes the
  bar real.
- **African representation will be thin.** Named in the story as F2 and not solved by it.
  The report prints the number rather than hiding it.
- **Manifest size.** 2,000 records with museum text may exceed a comfortable committed JSON.
  If it does, the manifest keeps identities and quota fields and the text is refetched at
  seed time — reproducible either way. Decided on measurement, noted here.

## Deviations (added during build)

All 2026-08-13.

- **Eng review not run** before implementation, at the curator's instruction.
- **Candidate pool is 12,212, not ~24,000.** Measured after mirroring: Met 3,848 +
  Cleveland 3,956 + Minneapolis 2,550 + AIC 1,858. The story's 24,000 counted
  paintings-with-images at any licence and before per-source filtering. Still 6× the target.
- **1,730 of the Met's 5,578 public-domain paintings have no title at all** — a third of its
  supply, dropped at ingest. Real data, not a parse bug; verified against the CSV directly.
- **AIC refuses any request past the thousandth result.** `limit * page > 1000` returns
  403 `Invalid number of results`, so its 1,954 paintings cannot be paged straight through.
  Fetched by date-range slices instead, each split in half until it fits, plus one slice for
  works AIC gives no date. Recovers 1,858 (the remaining ~96 have no image).
- **Minneapolis image rights resolved in the data, not by assumption.** 2,550 of 3,782 pass
  its per-object `rights_type: "Public Domain"` + `Rights_Image_Display: "Full"` +
  `public_access` test. The story's "if MIA image terms do not clear" contingency never
  had to fire, and the pool does not depend on a blanket reading of its metadata licence.
- **Highlight bar is a hard cap, not a band.** The story wrote "≥10% and ≤10%". Cleveland
  publishes no highlight flag at all, so a floor would be enforced against a signal three
  museums give and one does not. Implemented as **≤10%**, with 10% as the fill target; the
  count lands at exactly 200. Counting Cleveland's works as ordinary understates the famous
  share rather than overstating it.
- **`csv` added to the Gemfile.** Not a default gem since Ruby 3.4, and this box runs 4.0.1.
- **The resizer had to become portable.** `db/seeds.rb` used macOS `sips` only. On the
  Linux server `system("sips", …)` silently does nothing, so 2,000 full-size museum plates
  would have landed on disk unresized — several times the ~1 GB `decisions/0009` sized the
  CX22 for. Now prefers libvips (in the Dockerfile already), falls back to `sips`, and
  **refuses to run** with neither rather than quietly blowing the disk budget.
- **Region mapping defect found and fixed by reading the first report.** `Arts of the
  Americas` — a department at both Minneapolis and the Art Institute that is mostly United
  States work — was mapped to Latin America, counting ~290 American paintings as range that
  is not there. Ambiguous departments now yield to the place, and place matching is
  whole-word, so "Indiana" is no longer India. `test/lib/pool_region_test.rb` pins both.
- **The quota table failed its first run**, five text-bearing works short of the 70% bar,
  because `fill_scarce_regions` drained a whole region before re-checking the floor and
  starved the later fills. Fixed to stop mid-region. Worth recording that the forcing
  function caught it: the first pool was never written.
- **Two dead-link defects, both invisible until something checked.**
  1. **Minneapolis image paths cannot be derived from the object id.** `img.artsmia.org`
     shards on a cache key the record carries (`083000\600\40\83645`) and names the file
     after the *rendition* (`mia_5014236.jpg`), not the object. Deriving the path from the
     id produced 983 perfectly well-formed URLs that **every one of them 403'd** — caught
     only because the seed had downloaded 108 MB without attaching a single new Minneapolis
     plate. Now built from `Cache_Location` + `Primary_RenditionNumber`; works missing
     either are skipped, which is why the Minneapolis mirror fell 2,550 → 1,547.
  2. **The Art Institute 403s a User-Agent containing an email address.** Its Cloudflare
     rejected `…contact: dhanesh.n.m19@gmail.com`; the identical string without the address
     is served. Every AIC plate in the manifest was unreachable to the mirror.
- **New forcing function: `pool:curate` proves every plate before writing.** Started as an
  8-per-museum sample, which caught defect 2 on its first run — one command after being
  written for defect 1. Sampling then proved insufficient: **43 Minneapolis works whose
  records say `rights_type: "Public Domain"` and `Rights_Image_Display: "Full"` return 403
  for the image**, and they reached the seed and stayed blank. Verification now runs on
  every candidate that clears the quota caps, so a dead plate costs its work a place in
  the pool instead of leaving a reader a blank frame. It found **77**, against 11 by
  sampling. Cost: one ranged request per work entering the pool, ~8 minutes per curation.
- **A title bar the story did not have: `MAX_TITLE = 100`.** The expansion put a
  **297-character** museum catalogue entry — a Persian folio naming both sides and every
  poem on them — on the front door, and `test/system/dynamic_type_test.rb` failed: at the
  accessibility type cap the day's first written line sat **193px below the fold**, against
  story 0008's bar and Better bar 2. Found by pointing the existing test at the new pool's
  worst case rather than at the old one. Threshold measured, not guessed: at 95 characters
  the note clears the fold by a full line, at 105 by 2px, at 140 it misses by 26px.
  **Cost, stated:** 842 candidates rejected, and they skew toward exactly the descriptive
  South Asian and Persian manuscript titles that carry the pool's range. The cheaper fix
  would be to keep long-titled works in the pool and make them ineligible for the daily
  pick only — the fold budget binds the front door, not the gallery. That is a layout
  change to story 0008's territory and wants its own spec; this story took the bar it could
  enforce from the pool side.
- **A bar the story did not have: no region above 25%.** The first pool that passed every
  written bar came out **46.4% South Asian** — the range floor was being met by draining
  whichever non-Western collection is deepest (Cleveland's Indian holdings), which answers
  persona 3's complaint with a different monoculture. `MAX_REGION_SHARE = 0.25` is the
  per-artist ceiling one level up. Final spread: South Asia 25%, East Asia 25%, Europe 25%,
  United States & Canada 21.5%.
- **An unplaced work no longer counts as range.** 156 works (7.8%) were falling through the
  region map to `unknown` and being counted toward the non-Western floor — most of them
  Dutch and Flemish. Two fixes: `unknown` is excluded from the range count, and the map
  learned the Art Institute's habit of naming a city ("Holland", "Venice", "Rajasthan")
  where the others name a country. Unplaced is now **12 works, 0.6%**.
- **`db/seeds.rb` prunes works the pool no longer holds** — re-curating drops rows that
  would otherwise sit in the feed forever with a stale order. A work that has been published
  or favorited is never deleted; the run says how many it kept and why. Measured on the
  first reseed: 19 pruned, 1 kept because it had already had its day.
- **Met plates are resolved lazily inside selection**, not in a backfill pass. A work with
  no photograph is vetoed as it is about to be taken and the next candidate fills the slot,
  so a missing plate costs range rather than count. 2 of ~86 Met works resolved this way.
- **Feed order moved from `db/seeds.rb` into `pool:curate`.** The manifest now carries
  `feed_order`, so the shipped order is decided once, with the pool, and is reproducible
  from the committed file rather than recomputed on every seed.
- **`db/seeds.rb` already had a worker pool** (5 threads); the plan said to add one. Raised
  to 6 and left otherwise as it was.
