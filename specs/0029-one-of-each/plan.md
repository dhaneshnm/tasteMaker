# 0029 — Plan

## The real shape of the data, checked before designing anything

`Painting::FACETS = %i[period genre tradition]` (`app/models/painting.rb:146`) — all three
dimensions the owner asked for already exist as live, computed facets;
`Painting.displayed_facet_values(facet)` already returns exactly the values that clear
`MIN_FACET_WORKS = 16` for each. This story reuses that, not a new floor.

Today's live counts (2,340 works, post-0028 — `Pool::Curator::TARGET`, matching the
committed manifest; story.md's "2,344" in its lane note is a stale draft figure, corrected
there too by this review):

| Facet | Displayed values | Known for |
|---|---:|---:|
| genre (subject) | 6 (Religious 338, Portraits 263, Landscape 140, Still Life 50, Myth 30, Flowers 29) | 896 (38%) |
| tradition | 11 (Japanese 288 … Persian 19) | 1,072 (46%) |
| period (century) | 9 (12th 17 … 20th 309) | ~2,050+ (nearly all — `period` is derived from `dated`, which almost every work carries) |

**The number that changes the design**: genre + tradition combined are known for at most
~54% of the pool (the two sets overlap, so the true union is somewhere under 896+1072).
A template built only from the 17 genre+tradition category values has **no candidate at
all for well over half the pool** on any given cycle. A fixed 15–20-slot template, as
literally described ("repeat those"), either strands the untagged majority at the tail
(the exact failure success signal 3 in `story.md` calls out) or has to dedicate roughly
half its own slots to "uncategorized," which most people wouldn't recognize as one of
"fifteen or twenty categories."

## Recommendation: a rotating lens, not a fixed value list

Three points, then the mechanism:

1. **A "template" here can't be one flat list of ~17 values** — genre, tradition, and
   period are three *independent* dimensions (a single painting is simultaneously a
   Portrait, Mughal, and 18th-century). Flattening them into one 26-value list and
   round-robin-ing across it means a painting can only ever represent ONE of its three
   true categories per appearance, arbitrarily.
2. **Bucket sizes range 19 to 794** (Persian tradition to 19th-century period) — a fixed
   small template treats a 794-work bucket and a 19-work bucket as equally "one slot,"
   which either exhausts the small bucket almost immediately (Persian: 19 works ÷ 1-per-
   cycle ≈ empty after 19 cycles, then that slot has nothing for the remaining ~130
   cycles a 2,340-work pool needs) or, if slots repeat proportionally, stops looking like
   "fifteen or twenty placeholders" at all.
3. **Recommended mechanism**: a **rotating lens** — a cycle is four consecutive BLOCKS,
   one per lens, in this fixed order: **genre block, then tradition block, then period
   block, then untagged block**, repeating. Each lens internally steps through ITS OWN
   displayed values in turn within its block (genre: Religious → Portraits → Landscape →
   Still Life → Myth → Flowers, one per position; tradition: its 11 values in turn;
   period: its 9; `untagged`: a plain seeded shuffle of whatever carries none of the
   three tags). **Block order and claim priority are the same fact stated once, not two
   independent decisions that happen to agree**: genre claims a candidate before
   tradition gets a look at it, tradition before period, period before untagged — same
   order the blocks run in, so a future edit to one order can't silently desync from the
   other. A painting is placed once, by whichever lens+value claims it first (matching
   `Recognizable`'s existing "primary slug" idea — the first dimension to need it gets
   it, everything else skips an already-taken identity, same `@taken` idiom
   `Pool::Curator` already uses).

   **Worked example, first 9 positions of a cycle** (the genre block is only 6 long, so
   position 6 already opens the tradition block):
   ```
   pos:    0          1          2          3          4        5        6         7        8
   lens:   genre      genre      genre      genre      genre    genre    tradition tradition tradition
   value:  Religious  Portraits  Landscape  StillLife  Myth     Flowers  Japanese  Chinese   Mughal
   ```
   This is exactly what "first a portrait, then a landscape, and so on" describes in the
   owner's own words — the owner's own example (portrait, then landscape) is itself two
   consecutive GENRE values, i.e. block-sequential, not axis-alternating — while staying
   honest about period (a THIRD named block, not folded into the other two) and about the
   untagged majority (its own recurring block, not silently deferred to the end).

   **Why "untagged" stays a small, short-lived block, and that's correct, not a bug**:
   `period` is derived from `dated`, which nearly every work carries. Genre and
   tradition claim their ~54% first, but almost everything left over still carries a
   `period` value — so the PERIOD block, not the untagged block, is what actually
   carries most of "known for one dimension but not genre/tradition" forward. `untagged`
   (missing all three) is the true residual, logged via the same shortfall-reporting
   idiom `fill_themes` already uses, not evidence of a bug. **Measured against the real
   committed pool (implement time): 19 works** — smaller than even the smallest named
   tradition (Persian & Islamic, 19 works, coincidentally the same count) — confirming
   the prediction, not a guess. This is also why story.md's success signal 3 ("the
   untagged majority... silently pushed to the tail") is satisfied: the 54%/54%-unknown
   works are swept by the period block, not stranded waiting on the small untagged block.

**A cycle** (one full pass: genre-lens visits each of its 6 values once, tradition-lens
each of its 11, period-lens each of its 9, untagged-lens some fixed count per cycle —
proposed **6**, matching the genre lens length so no single lens dominates a cycle) is
`6 + 11 + 9 + 6 = 32` positions. Not 15–20 — the real number, given three independent
facets exist today, not the two (subject + a folded-in sense of "and so on") the
original description was picturing. **This is the one open call worth confirming before
implementation**: ship the 32-position rotating lens as designed above, or fold period
out of its own lens and use it only as a same-slot tiebreak (closer to the original
15–20 estimate, weaker on the explicit "time period" ask). Recommendation is the
32-position version — it answers all three named dimensions instead of two, and the
`display_facet_values` counts it's built from already update themselves as the pool
grows, so it never goes stale the way a hand-picked list of 15–20 names would.

**Alternative considered and rejected (eng review outside voice)**: a single greedy
pass — derive each row's three facet values, then walk the pool assigning `feed_order`
one at a time, preferring whichever remaining candidate's genre/tradition/period was
NOT seen in the last K positions, periodically forcing in an under-represented value.
Simpler code (one queue, no per-lens cursor state) and it targets "no five in a row
share a category" directly. Rejected because it turns success signal 2 ("every
displayed facet value appears at least once in the first full cycle") into a
probabilistic property of the greedy+force tuning instead of a structural guarantee —
the block-lens design makes that assertion exact and trivial to test (`assert genre
block == Painting.displayed_facet_values(:genre)`), which matters more here than the
extra per-lens bookkeeping costs.

## Where this runs

A new rake task, `pool:interleave` — same shape as `pool:genre_fill`
(`lib/tasks/pool.rake`): reads the committed manifest, does **not** re-select or re-fetch
any work, only recomputes `feed_order` and physically re-sorts the manifest array into
that order (see "why the array itself must be re-sorted" below), then appends a section
to `db/seeds/pool_report.md` (lens visit counts, any lens-value that ran out before the
pool did — logged, not hidden, same idiom `fill_themes`'s shortfall reporting already
uses). **Ordering, not "or": always runs after BOTH `pool:curate` AND `pool:genre_fill`**
— genre_fill only touches the ~403 AIC/MET rows it can fetch a museum tag for
(`lib/pool/genre_fill.rb`), so running interleave before it would lens-place those rows
under a weaker (title-inferred) genre guess that a moment later becomes stale, for no
reason to accept given genre_fill already runs same-day. NOT folded into `Pool::Curator`
itself, because ordering is orthogonal to selection and `pool:genre_fill` already
establishes "a standalone enrichment pass over the committed manifest" as this
codebase's pattern for exactly this shape of problem.

New module: `lib/pool/feed_interleave.rb` — `Pool::FeedInterleave.reorder!(manifest_rows)`,
pure function over the manifest's own rows, no mirror or DB read. **Correction from an
earlier draft of this plan, caught by the outside-voice review and verified against the
real `db/seeds/paintings.json`**: `period` and `tradition` are NOT literal keys on a
manifest row today (measured: 0 of 2,340 rows carry either key; only `genre` is
sometimes present, 280 rows, from `pool:genre_fill`) — both are derived at seed time,
per row, by `db/seeds.rb:52-67`, from raw fields the manifest DOES carry
(`dated`, `culture`, `country`, `department`, `artist`, `medium`). `Pool::FeedInterleave`
stays a pure function by calling the SAME derivation `db/seeds.rb` calls, not by
assuming the field already exists:
```ruby
period    = Pool::PeriodBucket.from_dated(row["dated"])
genre     = row["genre"] || Pool::TitleGenre.infer(row["title"])
tradition = Pool::Tradition.from_strings(
  culture: row["culture"], country: row["country"],
  department: row["department"], artist: row["artist"], medium: row["medium"]
)
```
This also fixes the plan's other imprecise claim that it "reuses `Painting.
displayed_facet_values`" — that method is DB-backed by default
(`Painting.facet_counts` runs `scope.where.not(facet => nil).group(facet).count`,
`app/models/painting.rb:175-178`), and `pool:interleave` runs BEFORE `db:seed`, so the
default would read stale or absent DB state, not this run's own manifest. The method
already accepts a `counts:` override for exactly this (`app/models/painting.rb:190`,
added for a different caller in story 0027) — `Pool::FeedInterleave` tallies its OWN
derived values across `manifest_rows` and calls
`Painting.displayed_facet_values(facet, counts: manifest_tally)`, reusing the real
floor-and-sort logic with zero DB access, not the DB-querying default arg.

Seeded shuffle within each lens value's own candidate list (`Pool::Curator::SEED`, same
constant, same reproducibility guarantee every other stage already has).

**Why the array itself must be re-sorted, not just the `feed_order` field**: `db/seeds.rb`'s
`LIMIT=N` quick-pass (`db/seeds.rb:25`, "first 50 of the feed only, for a quick local
pass") takes `paintings.first(N)` — the first N elements of the JSON ARRAY, in file
order. If `pool:interleave` only reassigns the `feed_order` field and leaves the array's
physical order untouched, "first 50 of the array" and "first 50 by feed_order" diverge,
silently breaking that documented quick-pass. `reorder!` returns rows sorted by their
new `feed_order`, closing this for free.

## The feed_order-stability promise this breaks — and why now is the cheap time to break it

`specs/0026-the-wider-pool/plan.md` built `feed_order` specifically so a reseed never
disturbs an existing `/feed?page=N`. This story reassigns `feed_order` for all 2,340
rows, once — a real, full break of that promise, not a corner case of it.

**Why this is the right time anyway**: every `SHIPLOG.md` entry through 2026-08-27 reads
"zero installs." There is no reader today with a real bookmarked page to break — the cost
this story pays is paid against nobody. Doing the same reorder after the first real
install would cost something; doing it now costs nothing measurable. No `decisions/`
entry proposed for this reason specifically — R4 is for direction-level calls with real
stakes, and "reorder a feed nobody has scrolled yet" doesn't clear that bar. Named here
so it's not silently assumed.

**This has to be a true ONE-TIME migration — named now so nobody re-runs it "for free"
later** (eng review, sequencing gap the first draft left open). `pool:curate`
(`lib/tasks/pool.rake:130-143`) already preserves old rows verbatim and appends new
candidates at the tail with a fresh shuffle. `pool:interleave` reassigns `feed_order` for
the WHOLE pool every time it runs — safe today only because nobody has a bookmark yet.
The second time this pool is expanded (a future story, real users, real bookmarks by
then), re-running `pool:interleave` across the whole manifest would break Jordan's
contract for real, this time against actual readers. **Decision: `pool:interleave` runs
once, now, on this story's ship. Every future `pool:curate` keeps appending new works at
the tail exactly as it does today, un-interleaved** — the composed order holds for the
2,340 works interleaved today and degrades gradually as new works accumulate at the tail
in future reseeds. Named as an accepted limitation, not solved here: keeping the
interleave property alive across future growth (e.g. inserting new works INTO the
existing lens rotation instead of appending) is real future work, captured in
`IDEAS.md` rather than built now — CLAUDE.md's own "infrastructure for later" caution
applies directly to building that today, before a second expansion actually needs it.

**The existing MANDATORY regression tests this breaks, and the fixture step that closes
it** (eng review + outside voice, both independently found this — plan's original test
plan didn't mention it at all): `test/lib/pool_quota_test.rb` already has two tests
literally named `REGRESSION`, both compared against
`test/fixtures/files/0026-prior-manifest-snapshot.json`:
- `"REGRESSION: pinned feed_order is preserved byte-for-byte across the expansion"`
  (`pool_quota_test.rb:51-60`) — asserts every previously-pinned row's `feed_order` is
  byte-for-byte unchanged from the snapshot.
- `"REGRESSION: every pre-existing genre value survives the manifest rewrite"`
  (`pool_quota_test.rb:618-635`).

`pool:interleave` changes `feed_order` for every pinned row exactly once, by design (see
above) — the first test goes red the moment this story's manifest is committed, and
stays red on every `bin/ci` run after, unless the fixture is deliberately refreshed. The
fixture's own comment already names the exact idiom this story needs: "Regenerated
deliberately at any future expansion, never silently." **Required implementation step,
not optional**: after `pool:interleave` runs and the new manifest is committed,
regenerate `test/fixtures/files/0026-prior-manifest-snapshot.json` from THAT committed
manifest (same `(source, source_id, feed_order, genre)`-only shape the comment
describes) as part of this story's own commit — so the byte-for-byte test starts
checking future reseeds against the post-interleave baseline, instead of shipping red.

**`/feed` includes out-of-pool "orphans" this reorder does not touch** (outside voice,
verified against `db/seeds.rb:73-85` and `app/controllers/paintings_controller.rb:10`):
`/feed` queries the live `Painting` table, not the manifest — and `db:seed` deliberately
KEEPS a previously-published-or-favorited work that has since dropped out of the
manifest (`spoken_for` in `db/seeds.rb:80-81`), leaving its old `feed_order` untouched.
`pool:interleave` only ever sees today's manifest rows, so a kept orphan's `feed_order`
is whatever it was before this story — never renumbered into the new scheme. No orphans
exist today (nothing has been favorited or published against a live install yet, per
`SHIPLOG.md`), so this is a zero-cost gap now, same reasoning as the stability-break
above — but worth naming so a future re-curation with real orphans doesn't get a
"why does the feed order look composed near the top and random near an old orphan"
surprise with no explanation on file.

## Test plan (for the implementation story, not run here)

- `Pool::FeedInterleave` unit tests, same style as `PoolCuratorTest`: a synthetic pool
  with known bucket sizes, assert (a) every displayed facet value appears within its
  lens's first cycle, (b) no work is placed twice, (c) untagged works are interleaved
  throughout, not clustered at the tail, (d) a lens value that runs out mid-pool degrades
  to "skip that slot" for the remainder — pool still fully placed, shortfall reported.
- `pool_quota_test.rb` gets one new assertion mirroring story success signal 1: sample the
  first 30 `feed_order` positions of a real curated pool, assert ≥ N distinct genres and
  ≥ M distinct traditions appear (N, M pinned to the actual lens-cycle math above once
  implemented, not guessed).
- Manual: `/feed` scrolled in a browser, first ~40 works, eyeballed against the report's
  lens-visit log.
- **CRITICAL (regression, eng review IRON RULE — no skipping)**: regenerate
  `test/fixtures/files/0026-prior-manifest-snapshot.json` from the post-`pool:interleave`
  committed manifest, in the same commit. Without this, `pool_quota_test.rb`'s two
  existing `REGRESSION` tests (`feed_order` byte-for-byte, genre survival) ship red — see
  "The existing MANDATORY regression tests this breaks" above.
- **New**: a derivation-parity test — assert `Pool::FeedInterleave`'s per-row
  period/genre/tradition derivation returns the exact same value `db/seeds.rb` would
  compute for the same raw row (same `Pool::PeriodBucket`/`Pool::TitleGenre`/
  `Pool::Tradition` calls, same arguments). Two call sites deriving the same three
  values from the same raw fields is exactly the kind of duplication that drifts silently
  if only one side is tested.
- **New**: assert the manifest array `pool:interleave` writes is physically sorted by
  the new `feed_order` (not just carrying the field) — otherwise `LIMIT=50 bin/rails
  db:seed`'s "first 50 of the feed" quick-pass silently stops matching the real feed
  order (see "why the array itself must be re-sorted" above).

## Non-goals (implementation-time, restated from story.md)

- No live/per-request sort — `pool:interleave` runs at curation time like every other
  pool-shaping step.
- No change to filtered views (`/feed?genre=…`) — already single-category by construction.
- No `decisions/` entry for the feed_order-stability break — reasoned above, zero
  installs make it free today.
- **Keeping the interleave alive across future pool growth** — named above as an
  accepted limitation (future `pool:curate` appends un-interleaved), not solved here.
  CLAUDE.md's "infrastructure for later" caution applies: build that mechanism when a
  second real expansion actually needs it, not speculatively now.
- **Re-deriving `tradition`/`period` at read time instead of at `pool:interleave` time**
  (i.e. moving the derivation into `Painting` and having `/feed` read it live) — the
  existing pattern (`db/seeds.rb`) already computes these once at seed time and this
  story just reuses that same computation one stage earlier; changing where derivation
  lives is a separate, unrelated refactor.

## Deviations

Implement time, 2026-08-28:

- **Mechanism simplified from "4 lenses, each cycling its own values with an arbitrary
  `untagged` weight" to one flat round-robin over every individual bucket** (27 of
  them: 6 genre values, 11 tradition values, 9 period values, plus `untagged`) —
  directly reusing `Pool::Curator#fill_remainder`'s existing round-robin-by-group
  idiom, generalized from one grouping (region) to many. **This is a code
  simplification, not a bug fix**: worked through by hand with concrete bucket sizes
  before committing to it, a correctly-implemented per-lens-cycle-with-skip design (the
  one designed above) and this flat design produce IDENTICAL placement order — the flat
  version just does it with one mechanism instead of four separate per-lens cursors,
  and drops the "`untagged` gets 6 slots per cycle so it isn't underweighted against a
  6-value genre lens" constant entirely, since every bucket (tagged or not) gets exactly
  one turn per round on equal footing regardless of how many values happen to share its
  lens. `lib/pool/feed_interleave.rb`'s `round_robin` carries the one-paragraph proof
  sketch. Cycle length is therefore **27 buckets, not 32 weighted slots** — still
  satisfies success signal 2 exactly (every displayed value appears once in the first
  27 positions), just without the extra bookkeeping the weighted version needed.
- **Real bucket sizes, measured by running `bin/rails pool:interleave` against the
  committed 2,340-work manifest** (full report: `db/seeds/pool_report.md`, "Feed
  interleave (story 0029)"): genre buckets 29–338, tradition buckets 3–252, period
  buckets 1–351, untagged 19. Notably, several DISPLAYED values (which clear
  `MIN_FACET_WORKS = 16` on their RAW, pre-claim count) end up with far fewer than 16
  actual candidates after genre/tradition claim their share first — `period:12th
  century` had only 3 post-claim, `period:13th century` only 1 — because most works
  tagged with a rare century ALSO carry a genre or tradition tag that claims them
  first. Not a bug: `displayed_facet_values` answers "does this value clear the floor
  for `/feed/index`'s own facet-door display," a different question from "how many
  works does this lens's bucket actually end up holding here," and the report logs the
  real number either way (`exhausted_early` correctly flags all of these).
  `period:19th century` (351, post-claim) turned out to be the single largest bucket —
  larger than genre's Religious Art (338) — so it's the one bucket present in every
  round of the run; every other bucket (26 of 27) ran out before it did, exactly as
  the round-robin design expects and reports.
- **`test/fixtures/files/0026-prior-manifest-snapshot.json` regenerated** from the
  manifest AFTER `pool:interleave` ran (the required step named above) — `(source,
  source_id, feed_order, genre)` only, same shape the file already used.
- **`/simplify` (4 parallel agents), all real findings applied:** bucket keys changed
  from formatted `"facet:value"` strings (decoded two different ways in the rake task)
  to structured `[facet, value]` tuples / a bare `:untagged` symbol, carried straight
  through; the report-building block moved out of the rake task into
  `Pool::Report.feed_interleave_section`, matching `theme_recount_section`'s existing
  idiom (the `genre_fill` task two blocks up already follows this pattern — the first
  draft of `interleave` didn't); a dead `.to_i` on `sizes.values.max` (never nil, since
  `UNTAGGED` always adds one key) removed; `pool_quota_test.rb`'s new assertion stopped
  re-deriving genre/tradition for the same 30 rows twice; added a test asserting
  `Pool::FeedInterleave::LENS_ORDER` and `Painting::FACETS` name the same facets (order
  may differ, membership may not) so the two can't silently drift. **Two findings
  skipped, logged to `IDEAS.md` Inbox instead**: extracting `round_robin` and
  `Pool::Curator#fill_remainder`'s shared "drain N queues" shape into one primitive
  (would mean touching Curator, a stable, heavily-tested selection method, for a
  same-story DRY win outside this story's scope) and precompiling
  `Tradition::UKIYO_E_ARTISTS`'s per-call regex compiles (pre-existing, not introduced
  by this story, just exercised a second time per curation cycle now).
- **Caught by manual re-verification, not a real risk**: running `pool:interleave`
  twice in a row (checking the refactor preserved behavior) gave a DIFFERENT result the
  second time — the shuffle is deterministic given a fixed input array order and seed,
  not invariant to re-ordering the input, and the second run fed it its own
  already-sorted output. Confirms the "runs once, ever" framing above is load-bearing,
  not just a cost argument: manifest and fixture were restored via `git checkout` and
  regenerated from ONE correct run before committing anything.

## What already exists (reused, not rebuilt)

`Painting::FACETS`/`MIN_FACET_WORKS`/`displayed_facet_values` (with its existing
`counts:` override — story 0027, not new for this story), `Pool::Curator::SEED` and the
`@taken` idiom, `Pool::PeriodBucket.from_dated` / `Pool::TitleGenre.infer` /
`Pool::Tradition.from_strings` (the exact three functions `db/seeds.rb` already calls —
this story calls them a second time, does not reimplement them), the `pool:genre_fill`
standalone-enrichment-pass pattern (`lib/pool/genre_fill.rb`) as the template for
`pool:interleave`'s shape, `fill_themes`'s shortfall-reporting idiom for the interleave
report, and the `(source, source_id, feed_order, genre)`-snapshot-fixture idiom
`specs/0026-the-wider-pool` already established for exactly this "deliberately
regenerated, never silently" situation.

## GSTACK REVIEW REPORT

| Review | Trigger | Why | Runs | Status | Findings |
|--------|---------|-----|------|--------|----------|
| CEO Review | `/plan-ceo-review` | Scope & strategy | 0 | — | — |
| Codex Review | `/codex review` | Independent 2nd opinion | 1 | issues_found (codex, ready) | 7 findings, all folded into this plan |
| Eng Review | `/plan-eng-review` | Architecture & tests (required) | 1 | CLEAR (PLAN) | 9 issues, 0 critical gaps open (1 flagged — MANDATORY `pool_quota_test.rb` regression tests going red — closed via required fixture-regeneration step) |
| Design Review | `/plan-design-review` | UI/UX gaps | 0 | — (skip: no UI change — story.md line 4-6, `/feed`'s scope untouched) | — |
| DX Review | `/plan-devex-review` | Developer experience gaps | 0 | — | — |

- **CROSS-MODEL:** Strong convergence, no tension — the eng review's own file reads
  (manifest JSON, `db/seeds.rb`, `paintings_controller.rb`) independently confirmed
  every one of Codex's findings before folding them in: manifest rows carry no literal
  `period`/`tradition` key (0 of 2,340, measured), `displayed_facet_values` is DB-backed
  by default, the 32-position mechanism was ambiguous between block and round-robin
  reading, the existing `pool_quota_test.rb` regression tests were unaddressed, and the
  2,344/2,340 figures disagreed. Two items Codex raised did not change the design:
  the `/feed`-orphans gap and the LIMIT=50 array-order gap are both named and closed
  with a one-line fix each rather than a redesign; the greedy-sliding-window
  alternative was considered and rejected (reasoning above) rather than adopted.
- **VERDICT:** ENG CLEARED — ready to implement. All decisions auto-resolved per owner
  instruction ("go with your recommendations for all decisions"); recommended option
  taken on every finding.

NO UNRESOLVED DECISIONS
