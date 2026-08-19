# 0019 — The coverage fill · implementation plan
Story: `specs/0019-the-coverage-fill/story.md`.
Seed: `specs/0018-the-names-you-know/plan.md` § "Release 2 — the coverage fill", steps 7–12.
Status: Draft.

## Approach

Research plus a re-curation. **No app code, no UI** — `/plan-design-review` is skipped and
the skip is noted here (build flow step 3 allows it for a UI-light story; this story has
no view, no controller and no route).

**Build flow step 4 was run as a workflow, not as `/plan-eng-review`.** That skill is
`interactive: true` and drives on `AskUserQuestion`; the owner was away, so running it
would have blocked the story on questions nobody was there to answer. Substituted: five
independent reviewer lenses (the C1/C3 arithmetic, the pipeline and reseed, test coverage
and R1, the research-to-code data contract, and scope against the operating rules), each
finding then handed to a separate verifier instructed to **refute** it, with only
survivors kept. Noted as a deviation rather than presented as the documented flow.

The pipeline already exists and is the whole mechanism: `pool:mirror` → `pool:curate` →
`db:seed`. This story adds one selection stage, fixes two normalizations, and adds one
reporting task. Everything else is the 0013 machinery doing what it already does.

## What the dry run changed

The seed spec called Release 2's feasibility "unknowable without a dry run". The dry run
was run first, 2026-08-19, against the committed mirrors. Three of the seed spec's
premises did not survive it.

### C1 — the load-bearing arithmetic does not bind. TARGET stays 2,000.

The seed spec says: *"Europe sits at exactly the region cap: 500/2,000 = 25.0%. Every
net-new European work breaks `verify!` unless TARGET grows 4× as fast."*

The sentence is true and irrelevant. **The fill needs no net-new European works.** It
needs *different* ones: recognizable names claim slots inside Europe's existing 500-work
budget, displacing arbitrary Europeans the quota table picked for range and text. Europe
ends at 500 either way. The seed spec's own chosen mechanism — a seed stage running
*first*, before `fill_scarce_regions` — is already substitution; the arithmetic paragraph
was a leftover worry about a different design.

Measured, TARGET 2,000, seed stage at depth 3, 35-name probe:

```
pool size                              2000 / 2000   ok      seeded 35/35 names, 95 works
sources represented                       4 / 4      ok
largest source share                    848 / 1000   ok
most works by one artist                  5 / 5      ok      ← was 9 under the old key
largest region share                    500 / 500    ok
outside Europe and North America       1058 / 900    ok      (was 1057)
dated 1900 or later                     362 / 300    ok
highlights (cap)                        200 / 200    ok
carrying museum text                   1677 / 1400   ok      (was 1691)
smallest image edge                       — resolver artifact of the dry run, see below
```

The dry run ran with `resolver: nil`, so Met candidates carried no dimensions and the
edge bar read 0. `Pool::Sources.resolve_met_image` sets `image_width`/`image_height` on
the candidate at selection time; the real run has them. Not a failure — an artifact of
skipping the plate check, and named here so the number is not read as a pass.

**Consequence:** no TARGET growth, no disk growth, no re-sizing of `decisions/0009`'s
~1 GB envelope, no `Unmeetable`. The seed spec's step 11 TARGET sweep is **withdrawn** —
there is nothing to sweep. It survives only as the fallback if the real 0007 list behaves
differently from the probe, and `verify!` remains the gate that decides.

### C2 — the classification needs more buckets than four, and a hand-set rights field.

The seed spec classifies **covered / filled / walled / fails-bars**. That mislabels a
real and separate case: **Michelangelo Buonarroti** has zero rows across all four mirrors
and died in 1564. He is emphatically not copyright-walled, and reporting him that way
would blame copyright for a collection gap.

*(The first draft of this section named Turner, Goya and Kandinsky here. All three are in
the mirrors — 7, 29 and 8 works — and all three are in the shipped manifest. The exemplars
were wrong for exactly the reason C4 below documents: exact-slug matching cannot see
"Joseph Mallord William Turner". The correction is kept visible because the same mistake
reached shipping code and a test fixture before the review caught it.)*

Final buckets:

| Bucket | Meaning |
|---|---|
| `covered` | already in the committed manifest before this story |
| `fillable` | not shipped, but the mirrors hold a qualifying work |
| `walled` | in copyright — unreachable from CC0 sources at any effort |
| `absent` | public domain, but **these four collections hold no qualifying painting** |
| `fails_bars` | held, public domain, but every candidate fails a 0013 bar (title > 100 chars, edge < 1600, no reachable plate) |

A sixth bucket, `unknown`, exists for one case only: **the mirrors are not on disk.**
Nothing can be classified then, and saying "Vermeer: public domain, not held" from an
empty directory is a claim about data that was never read.

`walled` and `absent` come from a **hand-decided `rights` field on each 0007 row**, not
from a death-year rule. Two reasons, both from the eng review:

1. All four sources are US institutions **already filtered to US public domain at fetch**
   (`Pool::Sources`), so absence from the mirrors cannot discriminate copyright from a
   collection gap — the mirror half of a death-year rule is vacuous by construction.
2. Life + 70 gets it backwards where it matters most. Frida Kahlo died in 1954, so the
   rule calls her public domain in 2026 while every US museum treats her as restricted
   under the 95-years-from-publication term for pre-1978 works.

`bin/rails pool:curate` and `pool:coverage` **abort** if any row lacks `rights`, rather
than defaulting to `absent` and quietly understating the walled fraction. The values are
seeded from Wikidata death years against the US anchor (published before 1931 ⇒ public
domain in 2026), then reviewed by hand — the anchor errs toward `walled`, which is the
direction that cannot invent a false collection gap.

### C3 — the per-artist ceiling was being enforced on the wrong key, and this is where it gets fixed.

`Pool::Candidate#artist_key` normalizes with `downcase.gsub(/[^a-z0-9]/, "")`, which
**deletes** accented characters instead of transliterating them: `"Paul Cézanne"` →
`paulcznne`, `"Paul Cezanne"` → `paulcezanne`. Two buckets, 5 works each, and the
9-work artist page story 0018 measured. `Painting.artist_slug_for` uses `parameterize`,
which transliterates, so the page groups what the cap does not.

This is eng review E1's diagnosis, deferred out of Release 1 because unifying the keys
changes `room_for?` bucketing and would stop `pool:curate` reproducing the committed
manifest. **This story re-curates, so that objection expires.** Both keys move to
`parameterize`, and the dry run confirms the effect: max works per slug **9 → 5**.

That is what makes story success signal 3 possible — `pool_quota_test` can finally
*assert* the slug-based ceiling instead of `pool:report` merely printing it (X2).

`dedup_key` carries the identical bug on the title (`IDEAS.md` deferred finding 2), so
accented and unaccented spellings of one painting never dedup. Same one-line fix, same
commit, because both change which works survive curation and splitting them would mean
two re-curations.

**Deny-listing stays out of `artist_key`.** `Painting.artist_slug_for` returns nil for
`NOT_AN_ARTIST` strings; if `artist_key` adopted that, six "China" works would each fall
to the `anon:` fallback and the per-artist ceiling would stop capping them entirely.
`artist_key` unifies the *normalization* only.

### C4 — exact-slug matching silently loses most of the coverage it claims to measure

Found while probing, before the eng review, and it invalidates the first version of this
plan's own numbers. `Painting.artist_slug_for(name) == painting.artist_slug` is the
obvious matcher and it is badly wrong, because museums do not spell an artist one way:

```
name                naive  aliased   the slugs the works actually land on
J. M. W. Turner         0      7     joseph-mallord-william-turner 7
Francisco Goya          0     29     francisco-jose-de-goya-y-lucientes 12, goya-francisco-de-goya-y-lucientes 10, goya 5, francisco-de-goya 2
Wassily Kandinsky       0      8     vasily-kandinsky 5, vassily-kandinsky 3
Rembrandt              17     42     rembrandt-rembrandt-van-rijn 19, rembrandt 17, rembrandt-van-rijn 6
El Greco                3     12     el-greco-domenikos-theotokopoulos 9, el-greco 3
Titian                  4      9     titian-tiziano-vecellio 4, titian 4, titian-tiziano-vecelli 1
Sandro Botticelli       3      8     botticelli-alessandro-di-mariano-filipepi 3, sandro-botticelli 3, botticelli 2
```

Two separate defects fall out of this, and they need different fixes.

**C4a — the matcher.** A recognizable name resolves to a **set** of acceptable slugs, not
one slug:

1. the name itself, plus every English Wikidata alias the 0007 list carries — this is why
   step 1 collects `altLabel`, and it is what turns Goya's 0 into 29 (`"Francisco de
   Goya"` is a Wikidata alias of Q5432, verified live);
2. for a museum string of the form `X (Y)`, the slugs of the whole string, of `X`, and of
   `Y` — `"Titian (Tiziano Vecellio)"` reaches Titian three ways;
3. **attribution qualifiers are rejected outright, never matched**: `Workshop of`,
   `Follower of`, `Imitator of`, `Circle of`, `School of`, `Manner of`, `Studio of`,
   `Copy after`, `After`, `Attributed to`, `Possibly by`. "Workshop of Titian" is not
   Titian, and story 0018 already settled that this pipeline does not invent attributions
   it cannot stand behind.

Matching stays **exact after reduction** — never substring. That is what keeps `"Polidoro
da Caravaggio"` and `"Cecco del Caravaggio"` (different painters) off Caravaggio's page,
and `"Rembrandt Peale"` (an American, no relation) off Rembrandt's.

Two names can claim the same museum slug through their alias sets. Where that happens the
higher-ranked 0007 name wins and the collision is **printed** by `pool:coverage`, because
a silent alias collision would put one artist's work on another's page.

**C4b — fragmentation, and what this story does *not* fix.** Goya's 29 works land on four
different artist pages; Rembrandt's 42 on three. Filling "3 works per name" naively would
put one work on each of four thin pages instead of three on one good one.

- **In scope, and cheap:** the seed stage picks each name's **primary slug** — the
  acceptable slug with the most qualifying candidates — and fills depth from that slug
  first, so the works land together on one page.
- **Out of scope, and it goes to `IDEAS.md`:** actually canonicalising the artist *string*
  at seed time so all 29 Goya works share one page. That rewrites displayed attribution
  data for every reader and deserves its own story with its own evidence. Naming it here
  so it is a deferred decision rather than an unnoticed one.

`pool:coverage` reports both numbers — works reachable for a name, and how many pages they
are spread across — so the fragmentation stays visible instead of being averaged away.

## Steps

**1 · Research — the name list** (seed step 7). `user-research/0007-recognizable-artists.md`
plus `user-research/data/0007-*.json`. Reddit mined for unprompted artist mentions across
r/Art, r/painting, r/ArtHistory, r/museum via the pullpush and arctic-shift archives
(Reddit blocks crawlers — the method `user-research/0002` established), matched against a
Wikidata painter dictionary, ranked by mention frequency. **Instrument control per house
style:** English Wikipedia pageviews over the same 12 months, ranked independently.
Divergences flagged both ways and never averaged — a "pageview-inflated" name (lay-famous,
under-discussed) is exactly the P2 case and is kept. Copyright-walled names are kept on
the list deliberately: dropping them would hide the size of the walled gap. Cut at ~200.

**2 · `Pool::Recognizable`** (`lib/pool/recognizable.rb`) — the list plus the matcher.
`.names` is **lazily memoized, deliberately not a frozen constant**: a missing or
malformed research file must not stop the app, the test suite, or an unrelated rake task
from booting, and the two commands that genuinely cannot proceed say so themselves.
Public surface: `.available?`, `.rows_missing_rights`, `.slug_sets`, `.variant_slugs`,
`.match`, `.parse`, `DEPTH = 3`, `QUALIFIER`.

**3 · `pool:coverage`** (seed step 8) — a reporting task, runnable **before and after**
the re-curation, which is what makes success signal 1 falsifiable. For each 0007 name it
resolves the **acceptable-slug set** of C4a through `Recognizable.match` — *not*
`Painting.artist_slug_for(name) == painting.artist_slug`, which C4 measures as losing most
of what it claims to count. `artist_slug_for` is still the reduction function inside the
matcher and still decides which page a work lands on, so there is still one
implementation of that question (R1). Counts works in the committed manifest and
qualifying candidates in the mirrors, assigns a bucket, prints the table, and writes it
into the pool report.

**Met rows make `fillable` provisional, and the report says so.** The Met CSV carries no
plate URL and no dimensions, and `Pool::Curator#reject_unusable` passes Met rows through
unchecked because whether a photograph exists at all is only knowable at selection time.
So a name whose only candidates are Met rows is *provisionally* fillable; the report
prints that count beside reachable coverage, and `pool_quota_test`'s failure message
repeats it. Resolving every Met candidate inside a report would be thousands of API calls
for a number that changes nothing.

**4 · The seed stage** (seed step 10) — `fill_recognizable`, first in `curate!`'s stage
order, before `fill_scarce_regions`:

```
curate!
 ├─ fill_recognizable(queue)     ← NEW. depth 3 per name, in 0007 rank order
 ├─ fill_scarce_regions(queue)   ← unchanged; restores the range floor
 ├─ fill(post-1900) / fill(highlights) / fill(text)
 ├─ fill_remainder(queue)
 └─ verify!                      ← unchanged; still the only gate
```

It calls `take`, so `room_for?` enforces every cap on it exactly as on every other stage —
the fill cannot break a bar, it can only fail to be complete. `queue` is already ordered
text-bearing-first then largest-plate-first, so taking the first 3 per name prefers works
a reader can read. Depth 3 (D17 asked 2–3; `MAX_PER_ARTIST` is 5). Names the mirrors can
only supply 1–2 works for get 1–2 — supply-limited, not cap-limited, and the coverage
table shows which.

**5 · The deny-list's silent gap** (`IDEAS.md` deferred finding 3) — and the first draft
of this step was measured wrong, so it is worth stating what changed.

The draft flagged **single-word artist slugs holding more than one work**. The eng review
measured that rule against the shipped manifest: **12 of 12 false positives, 0 of 30 true
positives.** It flagged Govardhan, Chokha, Fayzullah, Purkhu and Basavana — real Mughal
and Pahari painters, the exact names 0018's E2 refused to suppress — and missed every
actual place. Museums do not write culture-as-artist as a bare word; they qualify it
("India (Calcutta)") or inflect it ("Spanish", "Ancient Egyptian").

Measured properly with `Pool.place_shaped?` — reusing the `PLACES` vocabulary and the
whole-word regex `Pool.region_for` already uses, so no new vocabulary is invented —
the manifest and mirrors hold **102 distinct place-shaped strings over 580 rows**, and
**49 works over 31 strings were already live `/artists/:slug` pages in production**:
`/artists/india-calcutta` with five, `/artists/probably-mexico` with five,
`/artists/persia-iran` with five.

So step 5 is now three things:

- **Two reported lines** in `pool:report` — single-word slugs (kept, without the
  `count > 1` clause) and every place-shaped string. Reported, never assertions: "Mewar
  Stipple Master" and "Ugolino da Siena" are painters named for places, so only a human
  finishes the call. The pass extends `NOT_AN_ARTIST` before `db:seed`.
- **`Painting::NOT_AN_ARTIST` extended** with the exact strings the sweep found. Still an
  exact-string list — E2 settled that, and the sweep confirms it, because any shape rule
  that caught these would also catch the two real painters.
- **One assertion** in `pool_quota_test`, narrow enough to be green-able and to never fire
  on a painter: no artist string that **is** a place word resolves to an artist page. That
  is the forcing function the previous two rounds of this defect both lacked — it has now
  been found by hand three times (0018 E2, `/qa` ISSUE-001, this review).

**6 · Dry run, then commit** (seed steps 11–12) — `pool:curate` with the real list and the
real resolver. `verify!` raises `Unmeetable` and writes nothing if a bar fails, which is
the existing R1 enforcement doing its job. On success: new `db/seeds/paintings.json` and
`pool_report.md` (report gains the coverage table), `bin/ci`, then `db:seed` on production
— resumable, upsert by `(source, source_id)`, and 0013's prune semantics protect published
and favorited works.

**Mirrors are not re-fetched.** The committed mirrors are 2026-08-13/18, six days old, and
a museum's public-domain painting holdings do not turn over in six days. Re-running
`pool:mirror` costs a ~300 MB Met CSV plus ~60 paged API calls against four institutions
for no expected change in the answer. Stated as a deliberate skip rather than an omission;
`pool:coverage` reads the same mirrors, so the "absent" bucket is a claim about the
2026-08-13/18 mirrors and the report says so.

## Tests (R1 — written with the code, not after)

| Test | Pins |
|---|---|
| `test/lib/pool_quota_test.rb` (extend) | **the slug-based ceiling, as an assertion**: no `Painting.artist_slug_for` slug holds more than `MAX_PER_ARTIST` works in the committed manifest. Red today at 9 — this is success signal 3 |
| `test/lib/pool_quota_test.rb` (extend) | recognizable-coverage floor: every 0007 name classified `fillable` has ≥ 1 work in the manifest. Guards the fill against a later reseed silently dropping it |
| `test/lib/pool_curator_test.rb` (extend) | `fill_recognizable` takes recognizable works **first**, before `fill_scarce_regions` gets the queue |
| `test/lib/pool_curator_test.rb` (extend) | depth is capped at 3 per name even when the queue holds 10 by that artist |
| `test/lib/pool_curator_test.rb` (extend) | `room_for?` still binds *inside* the seed stage — a recognizable work is refused when its region is full |
| `test/lib/pool_curator_test.rb` (extend) | a name with no candidate is skipped without raising, and a name with 1 candidate takes 1 |
| `test/lib/pool_test.rb` (new or extend) | `artist_key` unifies `"Paul Cézanne"` and `"Paul Cezanne"`; a blank artist still falls to `anon:source:id`; a `NOT_AN_ARTIST` string still groups (is **not** anon-scattered) — the C3 regression |
| `test/lib/pool_test.rb` | `dedup_key` unifies accented and unaccented spellings of one title |
| `test/lib/pool_coverage_test.rb` (new) | the five-bucket classifier: one name per bucket, and `walled` vs `absent` decided by death year, not by absence alone |
| `test/models/painting_test.rb` (extend) | the 0007 JSON parses, every `name` is non-blank, every name resolves to a non-nil `artist_slug_for` (one that transliterates to nothing would silently never match), and every row carries a `rights` value |
| `test/lib/pool_recognizable_test.rb` (new) | the whole C4a matcher: parenthetical expansion, qualifier rejection, alias recovery, exact-after-reduction (never substring), primary-slug ordering, rank-resolved alias collisions, and a missing or malformed list |
| `test/lib/pool_quota_test.rb` (extend) | **no artist string that is simply a place word resolves to an artist page** — the assertion 0018's E2 and `/qa` ISSUE-001 both lacked. Green only after `NOT_AN_ARTIST` is extended |
| `test/lib/pool_quota_test.rb` (extend) | the coverage block **skips loudly** when `tmp/pool` is absent. It must never pass at 1.0 — `tmp/pool` is gitignored, so CI is exactly where this would have gone vacuously green |
| `test/lib/pool_coverage_test.rb` (extend) | with no mirrors, every row is `unknown` and `reachable_share` is `nil` — not `absent` rows and a perfect score |

**No system tests, no integration tests.** This story renders nothing. Release 1 already
pins `/artists/:slug`, and its tests must stay green across the reseed — that is the
regression surface.

**6b · Queue hygiene** — `IDEAS.md`: move the coverage-fill entry from Considering to
Promoted with this spec number, delete its `artist_works_count` dependency clause (that
column was withdrawn by 0018's X4/E3 and never existed), drop the three deferred-finding
bullets this plan consumes, and file the C4b artist-string canonicalisation into the
Inbox. Listed as a step because plan prose promised it and nothing enforced it (R1).

## Deviations (added during build)

- **Build flow step 4** ran as an adversarial workflow rather than `/plan-eng-review` —
  see § Approach. 49 findings raised, 11 survived independent refutation, 8 changed this
  plan or the code.
- **`pool:mirror` was not re-run.** The committed mirrors are 2026-08-13/18. A museum's
  public-domain painting holdings do not turn over in six days, and re-fetching costs a
  ~300 MB Met CSV plus ~60 paged API calls against four institutions. Every "absent" and
  "fails_bars" verdict is therefore a claim about those mirrors, and the report says so.
- **Implementation ran ahead of the review** for the parts the dry run had already
  settled (C3's key unification, the C4a matcher). The review then found four defects in
  that code — the vacuous CI pass, the false Turner exemplar, the death-year rule, and the
  single-word slug rule that was 12/12 false positive — all of which are fixed here. Noted
  because the order is not the documented one and the findings are the argument for why
  the documented order exists.

## Risks

| Risk | Handling |
|---|---|
| The real 0007 list behaves unlike the 48-name probe (e.g. 200 names × 3 = 600 works, over Europe's 500) | `room_for?` refuses the overflow; the fill comes out incomplete and the coverage table says by how much. The bars cannot break. If coverage lands poor, depth drops to 2 before TARGET is touched |
| Re-curation churns the pool and drops works a reader has kept | 0013's prune already protects published and favorited works, and `db/seeds.rb` warns about kept works left without an image. Unchanged behaviour, exercised harder |
| The reseed downloads image bytes for every newly selected work on production | Resumable by design; only *new* works download. Expect a few hundred, ~0.5 MB each. Disk checked against `decisions/0009` before seeding |
| `pool_quota_test`'s new assertions go red on a future source | Intended. That is the forcing function E1 asked for and X2 could not install — **once finding 1 is fixed**. As first written the coverage assertion passed vacuously in CI, because `tmp/pool` is gitignored and an empty mirror scored a perfect 1.0. It now skips loudly instead, and `reachable_share` returns `nil` rather than 1.0 on an empty denominator |
| Reddit is not a representative sample of App Store readers | Named as a limitation in 0007 §4, and the pageview control is the independent instrument. The list is a prior, not a measurement of Tondo's readers |
