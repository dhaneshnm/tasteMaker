# 0018 — The names you know · implementation plan
Story: `specs/0018-the-names-you-know/story.md`.
Status: Draft

## Approach

Two releases, shippable independently. Release 1 (artist page) is pure app work against
the pool as it stands — 1,019 distinct artist strings already group into pages. Release 2
(coverage fill) is research + pipeline work and never touches app code.

### The artist is a messy free string — decisions

`paintings.artist` (no index, nullable-in-practice-empty): 2,002 works, 459 blank, 1,019
distinct strings. Repeat spellings, culture-as-artist rows ("China" ×6), compound
attributions ("Filippino Lippi; Master of Memphis, possibly…").

| Decision | Choice | Why |
|---|---|---|
| Link when | `painting.artist.present?` only | Never link the `artist_display` culture fallback — "China" is not an artist page |
| Grouping | exact `artist` string, matched by slug | No Artist model. Slug = `artist.parameterize` |
| Spelling variants | all strings sharing a slug merge into one page | "Vincent van Gogh"/"Vincent Van Gogh" parameterize identically — merging is a feature, not a collision. Heading = most frequent variant |
| Compound attributions | grouped verbatim, page heading shows the string as-is | Splitting on ";" invents attributions we can't stand behind |
| URL | `GET /artists/:slug` | Readable, cacheable. Lookup: `SELECT DISTINCT artist`, match `parameterize` in Ruby (1,019 strings — trivial), 404 on no match |
| Wall + caching | `require_reader` + `private_revalidate` ETag | Same contract as `/days` — `/` and `/you` stay the only unwalled reader pages |
| Pagination | none | ≤5 works/artist is a curator bar (`MAX_PER_ARTIST = 5`) — the quota table *is* the pagination |

### Coverage fill — the load-bearing arithmetic

Europe sits at **exactly** the region cap: 500/2,000 = 25.0%. Every net-new European
work breaks `verify!` unless TARGET grows 4× as fast (+E Euro works ⇒ TARGET ≥
4×(500+E)), and `MIN_NON_WESTERN = 0.45` must hold at the new TARGET. Whether the
mirrors hold enough qualifying non-Western works to rebalance is **unknowable without a
dry run** — so the plan proves feasibility before committing anything: `verify!` raises
`Unmeetable` and writes nothing, which is the existing R1 enforcement doing its job.
The fill's mechanism: a new fill stage for recognizable names runs *first* — before
`fill_scarce_regions` in `curate!`'s stage order — then the existing stages restore the
floors; `room_for?` enforces caps throughout.

Expected honest outcome: a large fraction of the ~200 names are copyright-walled (CC0
sources are public-domain only). The deliverable includes the four-way classification
(**covered / filled / walled / fails-bars**), committed with the pool report.

## Release 1 — the artist page (app only, same-day)

1. Migration: `add_index :paintings, :artist`.
2. Route: `get "/artists/:slug" => "artists#show", as: :artist`, slug constrained
   `/[a-z0-9\-]+/`.
3. `ArtistsController#show` — `require_reader`; resolve slug → matching artist strings
   (`Painting.distinct.pluck(:artist)` filtered by `parameterize`); 404 (linen, 0004)
   when no match; `@paintings = Painting.where(artist: matches)` ordered by
   `feed_order`; `private_revalidate` ETag on the works' cache key.
4. View `app/views/artists/show.html.erb` — masthead + heading (most frequent variant
   + `life_date` when uniform) + `render partial: "paintings/painting", collection:`.
   Reuses the feed's post markup wholesale; zoom/reveal Stimulus controllers come free.
5. Link the name where it renders as its own element:
   - `paintings/_painting.html.erb:8` — wrap `label__artist-name` in `link_to` when
     `artist.present?`.
   - `daily/_day.html.erb:144-149` — same. **Caveat for review:** `/` is public,
     `no-cache`, byte-identical for every reader behind Thruster; a link to a walled
     page from the unwalled front door is fine (wall redirects), but the link must be
     identical for all readers — it is (no per-visitor state).
   - Archive/collection rows: untouched (nested `<a>`, story non-goal).
   - On the artist page itself the name renders unlinked (no self-link loop).
6. iOS shell: nothing — web-first screen, no bridge component, no compass change.

Verify: `bin/ci`; manual — tap Vincent van Gogh on `/feed`, land on 5 works; tap a
culture-fallback label, nothing to tap.

## Release 2 — the coverage fill (research + pipeline, no app code)

7. **Name list** → `user-research/0007-recognizable-artists.md` + `data/`.
   Mine Reddit for unprompted artist mentions (favorite-artist threads across r/Art,
   r/ArtHistory, r/museum, r/painting), rank by mention frequency. Independent
   instrument control per the 0002 house style: cross-rank against Wikipedia article
   pageviews for the same names; divergences flagged, not averaged. Cut at ~200.
8. **Gap analysis** — script under `lib/tasks/pool.rake` (`pool:coverage`): for each
   name, match against pool artist strings (same `parameterize` normalization as the
   app) → **covered** or gap.
9. **Availability pass** — for each gap, scan the four mirrors (`tmp/pool/*.json`,
   re-run `pool:mirror` first) for works passing the 0013 bars (title ≤100, edge
   ≥1600, licence, plate reachable). Classify: **fillable / walled / fails-bars**.
10. **Curator change** — `Pool::Curator` takes a recognizable-names seed stage before
    fills: ≥1 work per fillable name, `room_for?` enforced, then existing stages
    rebalance. New constant `RECOGNIZABLE_NAMES` sourced from the committed 0007 list.
11. **Dry-run TARGET sweep** — run `pool:curate TARGET=n` ascending until `verify!`
    passes or the mirrors run dry. If `Unmeetable` at every viable TARGET: fill the
    fillable subset that fits, log the shortfall in the pool report, story's
    falsification clause fires for the remainder. Disk check against decisions/0009
    (~0.5 MB/work — +400 works ≈ +0.2 GB, inside the ~1 GB envelope; state the real
    number in the report).
12. **Commit + seed** — new `db/seeds/paintings.json` + `pool_report.md` (report gains
    the coverage classification table); `db:seed` on prod (resumable; existing works
    keep ids — upsert by `(source, source_id)`; prune semantics per 0013, published/
    favorited works protected).

Verify: `pool:report` shows all bars green + coverage table; `pool_quota_test` green on
the new manifest; spot-check 5 filled names on `/artists/…` in prod.

## Tests (R1 — written with the code, not after)

| Test | Pins |
|---|---|
| `test/integration/artists_test.rb` (new, `behind_the_wall!`) | 200 + works for a known slug; 404 unknown slug; 404 blank-artist slug; variants merge ("Berthe Morisot" fixtures ×2 on one page); only that artist's works; ETag `private_revalidate` |
| `test/integration/daily_test.rb` (extend) | artist name on `/` links to artist page when present; plain text when painting has only `culture` |
| feed link assertion (extend `test/system/feed_test.rb` or integration) | `label__artist-name` wrapped in `<a>` on feed posts |
| `test/integration/public_cache_headers_test.rb` (extend) | `/artists/:slug` is not publicly cacheable |
| `test/models/painting_test.rb` (extend) | slug resolution: parameterize matching, unicode names (Hiroshige fixtures), no match on empty string |
| `test/lib/pool_quota_test.rb` (extend) | new manifest still passes every 0013 bar; recognizable floor: every fillable 0007 name has ≥1 work in the manifest |
| `test/lib/pool_curator_test.rb` (extend) | seed stage takes recognizable works first; `room_for?` still binds; `Unmeetable` when a name list can't fit |

## NOT in scope — considered and deferred

Artist directory page; artist search; Artist model; archive-row links (nested `<a>`);
splitting compound attributions; any change to daily-pick selection or feed order
semantics; theme filters.

## What already exists — reuse, do not reinvent

`paintings/_painting.html.erb` (whole post markup + Stimulus), `private_revalidate` /
`require_reader` (ApplicationController), linen 404 (0004), `Pool::Sources` mirrors +
`plate_reachable?`, `Pool::Curator` fill/quota machinery, `Candidate#artist_key`
normalization precedent, seeds' resumable image download.

## Known gaps, named rather than omitted

- Slug matching trusts `parameterize` — two *different* artists could theoretically
  share a slug (none in current data); they'd merge. Accepted until observed.
- Compound-attribution pages have ugly long headings. Accepted; splitting invents facts.
- Re-curation reshuffles `feed_order` for existing works (seeded shuffle over a new
  candidate set) and may prune unprotected works — 0013's established semantics.
- Reddit mining method is manual-ish research, not durable tooling — deliberately so
  (a scraper here is infrastructure-for-later).
- `country`/`culture` region assignment quirks (0013 F3) unchanged — the fill inherits
  them.

## Open questions for review

1. ~~Which compass key for the masthead?~~ Answered by code: `here` is tri-state and
   `nil` means "four links, nothing marked" — the state `/days/:date` and the 404
   already use (`application_helper.rb:59-63`). Artist page renders the masthead with
   `here: nil`. Not a question anymore; recorded as the decision.
2. Should the day page's artist link ride the existing label markup or get a
   distinguishable affordance (underline/chevron)? Design-review call — gallery tests
   say people already *expect* the tap, so maybe no affordance needed.
3. Fill depth: ≥1 work per fillable name, or target 2–3 where the mirrors allow? ≥1 is
   the floor the evidence supports; more is curator taste.

## Deviations (added during build)

- (none yet)
