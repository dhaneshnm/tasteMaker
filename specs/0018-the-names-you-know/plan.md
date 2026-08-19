# 0018 — The names you know · implementation plan
Story: `specs/0018-the-names-you-know/story.md`.
Status: Draft — **Release 1 only**. Release 2 split to its own story by eng review (E5).

## Approach

**Scope changed by eng review, 2026-08-18 (E5).** This story is now **Release 1 only** —
the artist page, pure app work against the pool as it stands. Release 2 (the coverage
fill) is research plus a re-curation whose feasibility the plan itself calls "unknowable
without a dry run"; an unbounded tail does not share a WIP slot with a same-day fix 13
days from kill review (R5). It becomes its own story, spec intact. Everything in this
file under "Release 2" is retained as the seed for that spec, not as work in flight.

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
| Pagination | none | **Corrected by eng review (E1).** The ≤5 claim was false: measured max is **9** (`paul-cezanne`), then 7 (`edouard-manet`), then 6 (`china`). `MAX_PER_ARTIST` is enforced on `artist_key`, the page groups on the slug, and the two normalizations disagree — see E1. None of the pool needs pagination at 9, but the *reason* is "measured 9", not "the bar says 5" |
| Link when | **`artist_slug.present?`** — and only on `/feed` and `/days/:date` | Final, after the outside voice (X6, X3, X11). `artist_slug` is nil for blank, deny-listed and empty-transliteration names, so the one predicate governs everything. The `>=2` rule (E3) was **reversed**: X5 made a one-work page a valid 200, so linking to it is a thin destination rather than a no-op, and E3's premise did not survive that |

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

## Eng review — the measured pool, and what it changed

`/plan-eng-review`, 2026-08-18. Every number below came from `bin/rails runner` against the
live development pool, not from reading the schema.

```
works                     2,002        blank artist            459  (22.9%)
distinct artist strings   1,019        distinct slugs        1,013
slugs holding 1 work        729  (72.0% of pages)
linkable slugs (>=2 works)  284
taps landing on a page showing ONLY the work you came from   729/1,543 = 47.2%
page-size distribution   1w:729  2w:167  3w:45  4w:22  5w:47  6w:1  7w:1  9w:1
slug merge groups             6        cross-artist collisions   0
```

### E1 — two normalizations for one concept, and the bar that cannot see it

```
lib/pool.rb:54    artist_key = artist.downcase.gsub(/[^a-z0-9]/, "")   DELETES é
this plan         slug       = artist.parameterize                     TRANSLITERATES é→e

  "Paul Cézanne"  → artist_key "paulczanne"   ┐  curator counts TWO artists,
  "Paul Cezanne"  → artist_key "paulcezanne"  ┘  MAX_PER_ARTIST = 5 each
  both            → slug "paul-cezanne"       →  ONE page, measured 9 works
```

`curator.rb:222` reports "most works by one artist" from `artist_key`, so
`pool_quota_test` reads 5 while the page renders 9. **The test structurally cannot see
this.** The same `gsub` is in `dedup_key` (`lib/pool.rb:60`), so accented and unaccented
spellings of one title never dedup — noted, not fixed here (wider blast radius).

**Fix (E1):** one shared slug function, used by the curator, the model, the controller,
link generation and the tests. Keeps `artist_key`'s anon fallback (`anon:source:id`) so
unattributed works still cannot collapse into one bucket.

### E2 — the culture rows the plan meant to exclude and did not

The decision table says *"'China' is not an artist page."* The rule — `artist.present?` —
does not do it, because these rows have `artist` literally set:

```
China 6 · Japan 5 · Islamic 5 · Tibet 5 · India 5 · Korea 4 · Nepal 2 · Egypt 2
```

The design review's D11 misses them too: it guards `artist_display`'s *fallback*, a
different code path. **Fix:** a frozen `NOT_AN_ARTIST` set checked by the model method
that owns the slug — the argument `painting.rb` already makes for `normalizes
:description` ("on the model … a source added later cannot reintroduce this by forgetting
a call (R1)"). Single-word suppression was rejected: it would also kill Govardhan, Chokha,
Fayzullah, Basavana and Purkhu, real Mughal painters with 2–4 works each.

### E3 — 47.2% of taps would show the reader what they were already looking at

729 of 1,543 linkable works belong to an artist with no second work. **Fix:** link only
when `artist_works_count >= 2`. Gold then means *"there is more by this hand"*, which is
the honest reading of D11's rule, and the no-op tap rate goes to zero.

### E4 — the heading rule prints a misspelling on the flagship page

```
paul-cezanne (9 works)   Paul Cezanne 5   |  Paul Cézanne 4     "most frequent" → WRONG
jean-honore-fragonard    Jean Honoré F. 2 |  Jean-Honoré F. 1    "most frequent" → WRONG
edouard-manet (7 works)  Édouard Manet 4  |  Edouard Manet 3     correct
chaim-soutine            Chaïm Soutine 2  |  Chaim Soutine 1     correct
edouard-vuillard         Édouard Vuillard 2 | Edouard V. 1       correct
jean-baptiste-camille-corot  Jean-Baptiste-Camille Corot 4 | … 1 correct
```

No ties, so "most frequent" is deterministic — just wrong twice, including the h1 in
Fraunces display on the largest artist page. **Fix:** prefer the variant with the most
accented characters (accents are information; their absence is loss), then frequency, then
string sort. Fixes 5 of 6. The Fragonard hyphenation stays wrong and is stated rather than
hidden. `pool:report` gains a merge-group listing so a future re-curation surfaces new
groups instead of hiding them.

### E5 — Release 2 leaves this story

See the Approach note above. Release 1 blocks nothing and ships same-day; Release 2's
feasibility is explicitly unproven until a dry run.

### Data model — the shape all of the above needs

```
paintings
  + artist_slug   string, indexed, NULL when the artist is blank,
                  deny-listed, or transliterates to an empty string

  ArtistsController#show:  where(artist_slug: params[:slug])   ← one index hit
  link rule:               artist_slug.present?                ← one column read
  artist_key:              UNCHANGED in Release 1 (X2)
```

Replaces step 1's `add_index :paintings, :artist`, which no query would have used. It also
removes the plan's original resolve — `distinct.pluck(:artist)` plus 1,019 `parameterize`
calls **per request**, and one `parameterize` per work per feed render (110 a page).

**The cache hazard that justified a count column is gone with E3.** It was real while the
rule existed: `/` is `Cache-Control: public` behind Thruster and ETags on `[@pick,
@pick.painting]`, so under a `>=2` rule one painting's link state would have depended on
another painting's existence, which that ETag cannot see. With the rule withdrawn, link
state is a function of the painting's own `artist_slug` — on the row, covered by the
existing ETag, nothing to drift. X3 removes the question from `/` entirely anyway.

### Controller shape — copied from `DaysController#index`, not invented

```
show
 ├─ require_reader              ← bounces first, so an unwalled visitor cannot
 │                                enumerate the pool's artists (positive finding)
 ├─ private_revalidate
 ├─ aggregates: count + MAX(updated_at) for the matching works
 ├─ return unless stale?(...)   ← 304 here does NO attachment or blob work
 └─ @paintings = Painting.with_attached_image.where(artist_slug:).feed_ordered
```

`days_controller.rb:14-18` states the rule this follows: *"Aggregates first, then bail …
loading every pick, painting, attachment and blob only to discard them on a 304 is the
bulk of the work."* The plan's original step 3 loaded first and ETagged after, and omitted
`with_attached_image` that `paintings_controller.rb:7` already uses — roughly 18 extra
queries on the 9-work Cézanne page.

## Outside voice — what two reviews missed

Independent Claude subagent, fresh context, 2026-08-18. Codex was rate-limited until
Sep 9. **Single-model, not cross-model** — the verifications below are what make these
findings load-bearing, not the second opinion itself. Every claim was checked against the
code before being accepted.

| # | Finding | Verified by |
|---|---|---|
| X1 | This story moves 0 of 5 BET.md thresholds and holds the only WIP slot | `BET.md:11` — "App live on App Store: yes, by **Aug 14, 2026**", missed by 4 days. No `solid_queue` in Gemfile, only `application_job.rb`, no APNs in `ios/` → Proven-baseline items 1 and 2 do not exist. **Owner was shown this and chose to ship Release 1, then submit.** |
| X2 | The slug-based quota assertion goes red on day one | `pool_quota_test.rb:31-38` recounts from the committed manifest; slug max is 9 against `MAX_PER_ARTIST = 5` |
| X3 | A public page linking to a walled one bounces anonymous readers | `daily_controller.rb:7` — `skip_before_action :require_reader`. `/` is public; `/artists/:slug` is not |
| X4 | `artist_works_count` had no writer | `db/seeds.rb:32` sets `artist:` only; 0013's prune deletes works without decrementing siblings |
| X5 | 200-or-404 for a one-work page was undefined | Neither review decided it; the interaction-state table claimed "Empty cannot occur" |
| X6 | D11's gold rule was decided at 23% and E3 moved it to 61% | 459 blank + 729 one-work + ~34 culture = 1,222 of 2,002 |
| X7 | `story.md` still carries Release 2's success signals | E5 edited `plan.md` only |
| X8 | D8/D9/T7 still cite the ≤5 bar E1 disproved; T11 was orphaned Release 2 work | Hidden WIP under R5 |
| X10 | D10's `inline-block` changes wrap behaviour on a line documented as wrapping | `application.css:630-632` |

### What the outside voice reversed

**E3 is withdrawn.** The `>=2 works` link rule was accepted, then reversed once X5 settled
that a one-work page returns 200. With a valid destination at the other end, the tap is
thin rather than empty, and E3's cost — a count on every render, a denormalized column
with no writer (X4), and 61% of artist names dimmed (X6) — stopped being worth paying.
**Everything E3 pulled in goes with it: no `artist_works_count` column, no grouped count
query, no counter maintenance.**

**`artist_key` is left alone in Release 1.** E1's diagnosis stands and is correct — two
normalizations, and `pool_quota_test` structurally cannot see a 9-work page. But unifying
them changes `room_for?` bucketing, so `pool:curate` would stop reproducing the committed
`db/seeds/paintings.json`, and the slug-based assertion would go red with no way to fix it
in an app-only release. Release 1 adds `Painting.artist_slug` for the app and **reports**
the slug-based max in `pool:report`. It becomes a bar when Release 2 re-curates.

### The surface rule, after X3 and X11

```
/                 public   artist name --ink-dim, NOT linked   ← link_artists: false
/days/:date       walled   artist name --gold, linked          ← same template, local differs
/feed             walled   artist name --gold, linked
/artists/:slug    walled   artist name is the h1, never a self-link
/days, /collection         row artist stays --ink-dim, unchanged
```

`/` and `/days/:date` render the same template (`DaysController#show` does `render
template: "daily/show"`). The difference is a **per-page local, not per-visitor state** —
`/` stays byte-identical for every reader, so story 0007's public-cache contract is intact.
They already diverge this way: `/` closes with "See you tomorrow", `/days/:date` closes
with `.walk`.

Why `/` does not link: an anonymous visitor — every first-timer, every gallery-test
participant — would tap the gold name and land on a sign-in bounce. Today they get plain
text. Linking there would make the P1 dead end **worse** on the one page every new reader
sees. Dimming keeps "gold means tappable" literally true on every screen.

## Release 1 — the artist page (app only, same-day)

1. Migration: add `artist_slug` (string, indexed) to `paintings`; backfill. **Not**
   `add_index :paintings, :artist` — no query uses it. **No `artist_works_count`** —
   withdrawn with E3 (X4/X6).
2. Route: `get "/artists/:slug" => "artists#show", as: :artist`, slug constrained
   `/[a-z0-9\-]+/`.
3. `ArtistsController#show` — `require_reader`; `where(artist_slug: params[:slug])`, one
   indexed lookup; raise `ArtistsController::NotFound < ActiveRecord::RecordNotFound` when
   empty — **not bare `RecordNotFound`**, see D6; then the aggregates-first shape in the
   Controller shape diagram above, ending in
   `Painting.with_attached_image.where(artist_slug:).feed_ordered`.
4. View `app/views/artists/show.html.erb` — see **Screen spec** below. The step-4 line
   this replaced claimed the partial reuse brought "zoom/reveal Stimulus controllers
   … free". **Reveal does. Zoom does not** — D5.
5. Extract `app/views/shared/_artist_line.html.erb` and link the name there. The markup
   is currently duplicated verbatim — `paintings/_painting.html.erb:7-11` and
   `daily/_day.html.erb:144-148` are the same five lines — and this story adds four
   conditions to it at once while D2 adds a `show_artist:` local to one copy only. One
   partial, following the precedent `days/_row_body.html.erb:1-2` already set: *"Split out
   so the linked and unlinked shapes cannot drift apart."* The rule inside it:
   - `paintings/_painting.html.erb:8` — wrap `label__artist-name` in `link_to` when
     `artist.present?`. The link needs **no new affordance** (D16) but does need a
     **44px tap box** (D10) — the element is 22.85px tall today.
   - The `else` branch is not "render the same thing unlinked". When `artist` is blank
     `artist_display` falls back to `culture` or `"Unknown artist"` — **459 of 2,002
     works, 23% of the pool** — and those must step back to `--ink-dim` (D11), or gold
     stops meaning "tappable" on nearly one work in four.
   - `daily/_day.html.erb:144-149` — same. **Caveat for review:** `/` is public,
     `no-cache`, byte-identical for every reader behind Thruster; a link to a walled
     page from the unwalled front door is fine (wall redirects), but the link must be
     identical for all readers — it is (no per-visitor state).
   - Archive/collection rows: untouched (nested `<a>`, story non-goal).
   - On the artist page itself the name renders unlinked (no self-link loop).
6. iOS shell: nothing — web-first screen, no bridge component, no compass change.

Verify: `bin/ci`; manual — tap Vincent van Gogh on `/feed`, land on 5 works; **tap an
artwork on the artist page and the zoom overlay opens** (D5); a culture-fallback label
is dim and has nothing to tap (D11); `/artists/pablo-picasso` 404s **without saying
"on that day"** (D6).

### Screen spec — `/artists/:slug`

Settled by `/plan-design-review`, 2026-08-18 — 17 decisions, D1–D17. The three marked
**[defect]** were verified against the partials this page reuses, not inferred from
plan prose.

```
┌──────────────────────────────────────────┐
│ Tondo                            ◎ corner  │  shared/masthead
│ Artist                          5 works    │  label: / aside:            D1
│ TODAY · DAYS · KEPT · GALLERY              │  compass, here: nil    (settled)
├──────────────────────────────────────────┤
│ Vincent van Gogh                           │  h1 — the subject, said ONCE
│ 1853–1890                                  │  life_date when uniform
│                                            │
│ [plate]                        × 1–5        │  paintings/_painting
│ Title (h2)                                 │  artist line SUPPRESSED     D2
│ meta · text · credit                        │
│ ──────────────────────────────             │
├──────────────────────────────────────────┤
│                  ✦                         │  .coda                     D3
│  <count-aware line — copy owed, D9>        │
└──────────────────────────────────────────┘
```

First, second, third: **the name, the works, the ending.** Nothing else earns the page.

| # | Decision | Choice | Why |
|---|---|---|---|
| D1 | Masthead locals | `label: "Artist"`, `aside: pluralize(n, "work")`, `here: nil` | Daily-page shape: the bar says what kind of screen this is, the h1 carries the subject. Aside copies `favorites/index.html.erb:5` |
| D2 | Repeated artist name | `_painting` gains `show_artist:` (default `true`); artist page passes `false` | Name renders 6× otherwise — once as h1, once per work. One optional local, so feed and artist page cannot drift |
| D3 | Ending | `.coda` — ornament + one line | Every other screen in the product has one. Without it the last thing on screen is a hairline with nothing after it |
| D4 | Return path | None. Compass + browser/native back | `here: nil` leaves GALLERY and TODAY one tap away; Turbo restores feed scroll on back; the shell pushes a screen with a native chevron. A coda "back to the gallery" would duplicate the compass, land at page 1 top, and lie when the reader arrived from `/` |
| D5 | **[defect]** Zoom | `<main class="page" data-controller="artwork">` + `render "shared/zoom"` | `artwork_controller.js` is a **page-level singleton**; its overlay targets live in `shared/_zoom`, mounted at `paintings/index.html.erb:21,24`. Without them `.plate__zoom` is a dead 44px target on every work — the story's own P1 defect — **and** `error->artwork#imageFailed` never fires, so a dead CDN image leaves `.plate__resting` stuck `hidden`: blank space, no sentence |
| D6 | **[defect]** 404 copy | `ArtistsController::NotFound`, own `MESSAGES` entry | `errors_controller.rb:18` maps `ActiveRecord::RecordNotFound` → *"There was no artwork on that day."* A reader at `/artists/pablo-picasso` would read that. `MESSAGES.fetch` is exact-class, so a subclass separates them — which is what that file's `:11-16` comment says the map is for |
| D7 | Keep rail | Out of scope, named in Known gaps | `/feed` ships without one today; inherited, not introduced here |
| D8 | The ≤5 ceiling | ~~The coda states it~~ **Withdrawn (X8).** | E1 measured the real max at **9**, so there is no ≤5 ceiling to state. The `.coda` keeps its ornament and its ending beat |
| D9 | Coda copy | **Ornament only. No count sentence, no copy owed (X8).** | The drafts claimed "the most Tondo keeps by anyone" — false for `paul-cezanne` (9), `edouard-manet` (7), `china` (6). Rewriting them is hand-written editorial only the user can supply (CLAUDE.md), on the days the binary needs uploading |
| D10 | **[defect]** Tap target | **Revised (X10):** plain inline `padding-block` — no `inline-block`, no negative margin | `.label__artist` is `1.02rem × 1.4` = **22.85px**; `--tap` is 44px. DESIGN.md rule 9's comment cites ISSUE-002 (commit 866bbc2) for exactly this. Padding on an **inline** element extends the hit area without affecting line box height, so there is no atomic box, no wrap change on a line `application.css:630-632` documents as wrapping, and no fold-budget question. **Measure** the budget before and after rather than asserting it unchanged |
| D11 | Gold semantics | `--ink-dim` for the blank/culture fallback, deny-listed strings, **and every artist name on `/`** (X11) | Keeps gold = tappable literally true on every screen. Also what rule 4 already says: `"China"` is metadata, not a name a person wrote. `.days__artist` already precedents an artist in `--ink-dim` |
| D12 | DESIGN.md | Amended in the same commit (R1) | Token table gains "gold on a work label means tappable"; rule 9 gains the inline-link target technique so the next inline link does not relearn it |
| D13 | Long artist heading | Mirror rule 3's step-down (`--long` modifier, same clamp) | Compound attributions run to four display lines above the first picture at 375px. Reuses the shipped answer instead of inventing one |
| D14 | Page title | `content_for :title` **and** `:description` | Pattern from `favorites/index.html.erb:1`. The Hotwire Native shell reads the title for its pushed-screen heading — without it the native nav bar is wrong too |
| D15 | Link purpose (a11y) | Plain accessible name; context carries it (WCAG 2.4.4) | The link sits in a wall label under a titled work. An `aria-label` would override visible text (breaking voice control) and double every announcement across 110 works. **Pinned by a test**, not assumed |
| D16 | Plan Q2 — affordance | **Closed. None needed.** | `.label__artist-name` is already `--gold`, the product's link colour — which is *why* gallery participants tapped it. The work is the inverse (D11). An underline would be the product's first, against a global `text-decoration: none` |
| D17 | Plan Q3 — fill depth | Target 2–3 where mirrors allow; floor ≥1 | **Moves to the Release 2 spec with E5.** Argument weakened by X5/X6: a one-work page is a valid 200 and its artist still links, so depth is curator taste rather than a correctness bar |

### Interaction states

| State | What the reader sees | Comes free? |
|---|---|---|
| Loading | `--bg-lift` behind each plate; first two works eager (`painting_counter < 2`), rest lazy | Yes — partial + tokens |
| One work | **Reachable and valid (X5).** 200 — h1, life dates, the single work, coda. 729 of 1,013 slugs are this shape, and all of them link | — |
| Empty | **Cannot occur.** A slug resolves only when ≥1 work matches; zero matches is the 404 path | n/a — record it so nobody builds one |
| Error — unknown slug | Linen 404, masthead "Not here", *"No artist by that name here."* | **No** — D6 |
| Error — image fails | `.plate__resting`: "This work is resting." | **No** — needs D5's controller |
| Error — not signed in | `require_reader` bounce, same as `/days` | Yes |
| Success | h1 → 1–5 plates → coda | — |
| Partial | None. No pagination — the ≤5 quota is the pagination | Yes |

### Responsive & accessibility

- Heading order `h1` (artist) → `h2` (work titles, `_painting.html.erb:6`). Correct, and
  the artist page is the only multi-work screen that has an `h1` at all.
- `:focus-visible` gold outline (`application.css:213`), `--gold` 5.3:1, `--ink-dim`
  6.0:1, `reveal` off under `prefers-reduced-motion` — all inherited.
- Narrow width: the page renders a compass over a non-empty `.page`, so it takes the
  normal `0.4rem` rule. **No `--empty` carve-out needed** — checked against the
  `page-empty-padding-loses-to-compass-sibling-rule` learning (9/10, 2026-08-17).
- Touch targets: D10 is the only one on this screen that is not already at `--tap`.

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
    fills: **target 2–3 works per fillable name where the mirrors allow, floor ≥1**
    (D17), `room_for?` enforced, then existing stages rebalance. New constant
    `RECOGNIZABLE_NAMES` sourced from the committed 0007 list. Depth is a *design*
    constraint as well as a curation one — a filled name that lands one work ships an
    artist page that reads as failure (D8).
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

Added by design review (D5, D6, D10, D11, D15 — the defects need forcing functions, R1):

| Test | Pins |
|---|---|
| `artists_test.rb` (same new file) | page renders `data-controller="artwork"` **and** the `shared/zoom` overlay — D5, the dead-tap regression |
| `artists_test.rb` | unknown slug 404 body does **not** match `/on that day/` and does match the artist sentence — D6 |
| `artists_test.rb` | artist name renders **once**: exactly one occurrence outside the `h1` is a failure — D2 |
| `artists_test.rb` | `content_for :title` carries the artist name — D14 |
| `daily_test.rb` (extend) | a work with blank `artist` renders the fallback **unlinked and not `--gold`** — D11, the 23%-of-pool case |
| `test/system/dynamic_type_test.rb` (extend) | the artist link's box is ≥ 44px in both axes, and the label's contribution to the fold budget is **unchanged** by D10 — the negative-margin technique proves itself or the `19rem` ration is being spent |
| accessibility assertion in `artists_test.rb` / `feed_test.rb` | the artist link's accessible name is the plain artist string — D15, pinning the "context carries it" choice rather than assuming it |

**Fixture caveat** (learning `fixture-image-is-one-800x1000-data-uri`, 10/10): every
painting fixture shares one 800×1000 data URI, so the `dynamic_type_test.rb` row above
measures that one shape. Any assertion needing a different aspect ratio must add a
second data URI with real pixels.

Added by eng review (E1–E5, T1–T3). **Fixtures come first — six of these branches cannot
be exercised by the current `paintings.yml`, which has no artist with two works, no accent
pair, no culture-as-artist row, and no blank artist:**

| Test | Pins |
|---|---|
| `test/fixtures/paintings.yml` (extend) | an artist with 2 works; an accent pair sharing a slug; a culture-as-artist row; a blank artist; a 1-work artist; a name that transliterates to an empty slug |
| `painting_test.rb` (extend) | `artist_slug` is nil for blank / deny-listed / empty-transliteration, and equals the shared function otherwise — for **every** fixture (T3 invariant) |
| `painting_test.rb` (extend) | canonical name prefers the accented variant; `paul-cezanne` resolves to "Paul Cézanne" not "Paul Cezanne" (E4) |
| `artists_test.rb` (extend) | `assert_queries_count` bounds the 200 render as work count grows — catches a dropped `with_attached_image` (E-A2) |
| `artists_test.rb` (extend) | the 304 path does **zero** attachment/blob queries (E-A3) |
| `artists_test.rb` (extend) | a deny-listed slug (`/artists/china`) 404s (E2) |
| `daily_test.rb` / `feed_test.rb` (extend) | a 1-work artist renders dim and unlinked; a 2-work artist renders as a link (E3) |
| `pool:report` — a **reported number, not an assertion** (X2) | prints the slug-based max beside the `artist_key` one so the 9 is visible and dated. Asserting it would go red on day one: `pool_quota_test.rb:31-38` recounts from the committed manifest, 9 > `MAX_PER_ARTIST` 5, and an app-only release cannot fix it |
| `daily_test.rb` (extend) | artist name on `/` is **dim and unlinked**; the same template at `/days/:date` renders it **gold and linked** (X3/X11) |
| `public_cache_headers_test.rb` (extend) | `/` stays byte-identical for every reader with the new local in place — story 0007's contract |
| `artists_test.rb` (extend) | a one-work slug returns **200**, not 404 (X5) |

**Regression tests — mandatory, no negotiation (IRON RULE).** Both were found by reading
the existing suite, and both assert against markup this story rewrites:

| Test | What breaks it |
|---|---|
| `test/integration/daily_test.rb:11` | `assert_select ".label__artist .label__artist-name", text: …` — the `_artist_line` extraction (E-Q1) and the `link_to` wrap (D10) both change this structure |
| `test/system/dynamic_type_test.rb:184` | `"a long title over a two-line artist line"` — D10's `inline-block` + negative margin changes `.label__artist` box metrics, and this test measures fold budgets |
| `test/system/design_test.rb` | fails if any screen drifts; `/artists/:slug` is a new screen and the wall label changed on two existing ones |

## NOT in scope — considered and deferred

Artist directory page; artist search; Artist model; archive-row links (nested `<a>`);
splitting compound attributions; any change to daily-pick selection or feed order
semantics; theme filters.

Design decisions considered and deferred (design review 2026-08-18):

- **A `.rail` on the artist page** — `/feed` has the same gap; habit-mechanic scope (D7).
- **An underline on artist links** — gold already is the affordance (D16).
- **A `.walk`-style previous/next artist** — no meaningful order over 1,019 free
  strings, and it invents the browse model the story lists as a non-goal (D4).
- **An `aria-label` on the artist link** — overrides visible text, breaks voice
  control, doubles every announcement across the gallery (D15).
- **Making `.label__artist` a block 44px row** — correct-looking, but it spends ~21px of
  rule 2's `19rem` label ration that `dynamic_type_test.rb` already polices (D10).
- **Archive-row artist links** — unchanged, and it needs no fix: `.days__artist` is
  `--ink-dim`, so unlike the wall label it never claims to be a link.

Deferred by eng review (2026-08-18):

- **Release 2, the coverage fill** — its own story (E5). Retained below as that spec's seed.
- **Fixing `dedup_key`'s normalization** — same bug as E1, but it changes which works
  survive curation. Belongs with the re-curation, not with an app-only release.
- **Pagination on the artist page** — measured max is 9 works; a bounded 9-plate page does
  not need it. Revisit only if a re-curation raises the ceiling.
- **An explicit canonical-name map** — rejected in favour of the accent rule (E4): a map
  needs a human pass after every re-curation, and a stale map mislabels silently.
- **Extracting the whole wall label** (title + meta + credit, not just the artist line) —
  the day page carries a note/museum-copy branch the feed does not, so it is a bigger
  refactor than this story needs.

## What already exists — reuse, do not reinvent

`paintings/_painting.html.erb` (post markup + the `reveal` controller — **but not
zoom**, D5), `private_revalidate` / `require_reader` (ApplicationController), linen 404
(0004), `Pool::Sources` mirrors + `plate_reachable?`, `Pool::Curator` fill/quota
machinery, `Candidate#artist_key` normalization precedent, seeds' resumable image
download.

Added by eng review — precedents the plan should copy rather than reinvent:
**`DaysController#index`** (aggregates-first ETag, `days_controller.rb:14-19`),
**`PaintingsController#index:7`** (`with_attached_image`), **`days/_row_body.html.erb:1-2`**
(split-so-shapes-cannot-drift, the model for `_artist_line`), **`Painting.normalizes
:description`** (normalization owned by the model so no future source can forget it), and
**`Pool::Candidate#artist_key`** (`lib/pool.rb:54`) — which is the function E1 unifies with,
not a separate thing to build.

Added by design review — the closest analogue the plan had not cited:
**`app/views/favorites/index.html.erb`** is a walled list of works with a masthead
label, a work-count aside, and a coda. It answers D1 and D3 by precedent rather than by
invention. Also `shared/_zoom` + `artwork_controller.js` (D5), `errors_controller.rb`'s
`MESSAGES` map (D6), and `.days__artist`'s `--ink-dim` treatment (D11).

## Known gaps, named rather than omitted

- Slug collisions between *different* artists: **measured, not assumed** (eng review E4).
  6 merge groups across 1,019 strings as of 2026-08-18, all six the same artist with and
  without diacritics, **0 cross-artist collisions**. `pool:report` gains a merge-group
  listing so a re-curation that does create one surfaces instead of being found by a reader.
- `dedup_key` (`lib/pool.rb:60`) carries the same non-transliterating `gsub` as
  `artist_key`, so accented and unaccented spellings of one *title* never dedup — the pool
  may hold duplicate works right now. Named by eng review E1, **not fixed here**: changing
  dedup changes which works survive curation, which is Release 2's blast radius.
- `_masthead.html.erb:57` says the corner rides "eight of them, seven with a compass".
  This story makes it nine and eight; the comment is updated in the same commit.
- Compound-attribution pages have long headings. **No longer just "accepted"** — the
  heading mirrors rule 3's step-down (D13). Splitting the string still invents facts.
- **No `.rail` on the artist page**, so a reader who just discovered an artist cannot
  Keep from there — they must open `/` or a day page. `/feed` has the same gap today,
  so this is inherited, not introduced by 0018 (D7). Fixing it is a habit-mechanic
  decision that deserves its own spec.
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
2. ~~Distinguishable affordance for the artist link?~~ **Closed by design review, D16.**
   No. `.label__artist-name` is already `--gold`, the product's link colour, which is
   why gallery participants tapped it. What the review changed is the *inverse*: the
   unlinkable culture fallback loses gold (D11), and the link gains a 44px box (D10).
3. ~~Fill depth ≥1 or 2–3?~~ **Closed by design review, D17.** Target 2–3 where the
   mirrors allow, floor ≥1. The plan was missing the design half of the argument.

## Deviations (added during build)

Implemented 2026-08-19. All of Release 1 (T1-T10, T12-T20; T11 and T21 are Release-2/
IDEAS.md work, not this branch). `bin/rails test`, `bin/rails test:system`, `bin/rubocop`,
`bin/brakeman`, `bin/bundler-audit`, `bin/importmap audit`, and a full
`db:seed:replant` all green.

- **T2's formula, measured and corrected.** D10/X10's `padding-block: calc((var(--tap) -
  1.02rem * 1.4) / 2)` targets the wrong baseline — `.label__artist`'s line-height, not
  the inline `<a>`'s own content box. Measured directly (`getBoundingClientRect`): an
  inline element's box for hit-testing tracks font content-area metrics (~16px here), not
  the paragraph's declared line-height (22.85px); line-height set on the element itself
  changes nothing. The formula now targets 46px against a ~16px baseline (not 44px against
  22.85px), landing at 45.4-45.66px measured across the Dynamic Type range — margin, not
  luck. `application.css` and `DESIGN.md` rule 9 both carry the corrected reasoning.
- **T7 delivers the withdrawn version, not its own title.** X8 withdrew the count-aware
  coda line (D8/D9) before implementation started; T7 as built is ornament-only, matching
  the plan body, not its own task-list summary text.
- **A fourth file, not in any task's file list: `config/application.rb`.**
  `ActionDispatch::ExceptionWrapper.rescue_responses` keys on exact class NAME, not
  ancestry — `ArtistsController::NotFound < ActiveRecord::RecordNotFound` rendered a 500,
  not the intended 404, until `config.action_dispatch.rescue_responses` carried its own
  entry. Neither review's D6/T4 anticipated this; found by running the tests T19 asked
  for, which is the R1 forcing function doing its job.
- **story.md's X7 amendment shipped in this commit, not held for the Release 2 spec.** It
  was written during review but not yet applied to the file; applying it here keeps the
  intake card in sync with what actually shipped rather than leaving it to drift further.
- **Fixture `feed_order`, following the file's own documented precedent.** The four new
  story-0018 fixtures (`cezanne_plain`, `cezanne_accented`, `culture_as_artist`,
  `unparseable_artist`) needed `feed_order: 9001-9004` — `wide_harbour`'s comment already
  named this exact failure mode (a nil-`feed_order` fixture can push an existing one below
  the fold and fail an unrelated Selenium test) and it fired on the first system-test run
  before the fix.

## Failure modes — new codepaths, one realistic production failure each

| Codepath | Realistic failure | Test? | Error handling? | What the reader sees |
|---|---|---|---|---|
| `artist_slug` backfill | migration half-applies on prod SQLite; some rows keep a nil slug | T3 invariant + `pool:report` line | none | **Silent.** Those artists simply 404. The report line is the only thing that surfaces it |
| `artist_works_count` | count drifts after a re-curation that does not reseed | `pool_quota_test` extend | none | Silent, mild: a link appears or vanishes one release late |
| zoom not mounted | `.plate__zoom` renders, taps do nothing | D5 assertion | none | **Silent.** Dead 44px target on every work |
| broken museum CDN image | `error->artwork#imageFailed` never fires without the controller | D5 assertion | `.plate__resting` | **Silent** without D5: blank space, no sentence |
| empty-transliteration slug | `artist_path("")` raises `UrlGenerationError` | fixture + model test | slug stores nil, never linked | Loud 500 on `/feed` — **prevented**, not handled |
| missing `with_attached_image` | N+1 on blobs | `assert_queries_count` | none | Silent: page renders, just slower |
| deny-list misses a new culture string | a future ingest adds "Bhutan" as an artist | **none** | **none** | **Silent: a country gets an artist page** |

**Critical gap: 1.** The deny-list has no test, no handling, and fails silently for a
culture string a *future* source introduces. It cannot fire during Release 1 — no ingest
runs here — so it is carried into the Release 2 spec, where the fix belongs: a
`pool:report` line flagging single-word artist slugs with more than one work, for a human
pass before seeding.

## Worktree parallelization strategy

| Step | Modules touched | Depends on |
|---|---|---|
| Foundation | `app/models/`, `lib/pool/`, `db/migrate/` | — |
| Presentation tokens | `app/assets/stylesheets/`, `DESIGN.md` | — |
| Request layer | `app/controllers/`, `config/routes.rb` | Foundation |
| Views | `app/views/` | Foundation, Presentation tokens |
| Tests | `test/` | all of the above |

```
Lane A  Foundation ──────────┬──> Lane C  Request layer ──┐
                             │                            ├──> Lane E  Tests
Lane B  Presentation ────────┴──> Lane D  Views ──────────┘
```

Launch **A + B in parallel worktrees** — they share no module directory. Merge both, then
run **C + D in parallel**. Then E. No conflict flags: no two parallel lanes touch the same
directory. Tests are last on purpose, because T1's fixture rows are what make six of the
new branches assertable, and they need Foundation's API to exist first.

## Implementation Tasks
Synthesized from the design review's findings. Each task derives from a specific
decision above. Checkbox as you ship.

- [x] **T1 (P1, human: ~30min / CC: ~5min)** — artists/show — wire the zoom overlay
  - Surfaced by: D5 — `artwork_controller.js` is a page-level singleton; step 4's "comes free" claim is false
  - Files: `app/views/artists/show.html.erb`
  - Verify: tap an artwork on `/artists/:slug`, overlay opens; kill an image src, resting note appears
- [x] **T2 (P1, human: ~45min / CC: ~10min)** — .label__artist-name — 44px tap box
  - Surfaced by: D10 — element is 22.85px against `--tap: 44px`; DESIGN.md rule 9, ISSUE-002 precedent
  - Files: `app/assets/stylesheets/application.css`
  - Verify: `bin/rails test test/system/dynamic_type_test.rb` — target ≥44px both axes, fold budget unchanged
- [x] **T3 (P1, human: ~30min / CC: ~5min)** — demote the unlinkable artist fallback to `--ink-dim`
  - Surfaced by: D11 — 459/2,002 works (23%) would render gold and dead
  - Files: `app/views/paintings/_painting.html.erb`, `app/views/daily/_day.html.erb`, `app/assets/stylesheets/application.css`
  - Verify: a blank-artist fixture renders unlinked and not gold
- [x] **T4 (P1, human: ~20min / CC: ~5min)** — `ArtistsController::NotFound` + its own 404 sentence
  - Surfaced by: D6 — bare `RecordNotFound` makes `/artists/pablo-picasso` say "There was no artwork on that day."
  - Files: `app/controllers/artists_controller.rb`, `app/controllers/errors_controller.rb`
  - Verify: unknown-slug 404 body does not match `/on that day/`
- [x] **T5 (P2, human: ~20min / CC: ~5min)** — `show_artist:` local on the post partial
  - Surfaced by: D2 — the name renders 6× on its own page
  - Files: `app/views/paintings/_painting.html.erb`, `app/views/artists/show.html.erb`
  - Verify: exactly one occurrence of the artist string outside the `h1`
- [x] **T6 (P2, human: ~20min / CC: ~5min)** — masthead locals + `content_for` title/description
  - Surfaced by: D1, D14 — both unspecified; the native shell reads the title for its screen heading
  - Files: `app/views/artists/show.html.erb`
  - Verify: tab title carries the artist name; aside shows the work count
- [x] **T7 (P2, human: ~30min / CC: ~10min)** — `.coda` with a count-aware line
  - Surfaced by: D3, D8, D9 — no ending beat, and nothing explains the ≤5 curation bar
  - Files: `app/views/artists/show.html.erb`
  - Verify: coda renders on 1-work and 5-work artists with the right sentence. **Copy owed by the user** — CLAUDE.md bans AI-written editorial
- [x] **T8 (P2, human: ~20min / CC: ~5min)** — step-down for long artist headings
  - Surfaced by: D13 — compound attributions run to four display lines at 375px
  - Files: `app/views/artists/show.html.erb`, `app/assets/stylesheets/application.css`
  - Verify: render the longest compound attribution in the pool at 375px
- [x] **T9 (P2, human: ~30min / CC: ~10min)** — amend DESIGN.md (token table + rule 9)
  - Surfaced by: D12 — this story changes what `--gold` means on a work label (R1: same commit)
  - Files: `DESIGN.md`
  - Verify: `bin/rails test test/system/design_test.rb`
- [x] **T10 (P2, human: ~2h / CC: ~20min)** — the seven review-added test assertions
  - Surfaced by: R1 — the three defects need forcing functions, not just prose
  - Files: `test/integration/artists_test.rb`, `test/integration/daily_test.rb`, `test/system/dynamic_type_test.rb`
  - Verify: `bin/ci`
_**T11 deleted (X8).** It was Release 2 work left in this story's task list after E5 —
hidden WIP under R5. It travels with the Release 2 spec in `IDEAS.md`._

### Added by eng review (2026-08-18)

- [x] **T12 (P1, human: ~3h / CC: ~20min)** — models/migrate — `artist_slug` column + function
  - Surfaced by: E1 — `artist_key` deletes non-ASCII, `parameterize` transliterates; they disagree on accented names
  - Files: `db/migrate/`, `app/models/painting.rb`
  - Verify: `painting_test.rb` invariant over every fixture; `pool:report` prints rows-with-slug vs rows-linkable
  - _No `artist_works_count` (X4, withdrawn with E3). `lib/pool.rb`'s `artist_key` is **not** touched in Release 1 (X2) — unifying it would stop `pool:curate` reproducing the committed manifest._
- [x] **T13 (P1, human: ~2h / CC: ~15min)** — models — `NOT_AN_ARTIST` deny-list
  - Surfaced by: E2 — China 6, Japan 5, Islamic 5, Tibet 5, India 5, Korea 4, Nepal 2, Egypt 2 have `artist` literally set
  - Files: `app/models/painting.rb`
  - Verify: `/artists/china` 404s; Govardhan, Chokha, Fayzullah, Basavana, Purkhu still resolve
- [x] **T14 (P1, human: ~2h / CC: ~15min)** — views — the surface rule: link on /feed and /days/:date, dim on `/`
  - Surfaced by: X3/X11 — `daily_controller.rb:7` makes `/` public while the artist page is walled, so a link there bounces every anonymous reader
  - Files: `app/views/shared/_artist_line.html.erb`, `app/controllers/daily_controller.rb`, `app/controllers/days_controller.rb`
  - Verify: `/` dim + unlinked; `/days/:date` gold + linked; `/` still byte-identical for every reader
  - _Supersedes the withdrawn `>=2` rule (E3, reversed by X6)._
- [x] **T15 (P2, human: ~1h / CC: ~10min)** — views — extract `shared/_artist_line.html.erb`
  - Surfaced by: E-Q1 — `_painting.html.erb:7-11` and `_day.html.erb:144-148` are the same five lines, and D2 adds a local to one
  - Files: `app/views/shared/_artist_line.html.erb`, `app/views/paintings/_painting.html.erb`, `app/views/daily/_day.html.erb`
  - Verify: `daily_test.rb:11` still passes; both surfaces render identically
- [x] **T16 (P2, human: ~2h / CC: ~15min)** — models — canonical name prefers accents
  - Surfaced by: E4 — "most frequent" titles the 9-work page "Paul Cezanne"
  - Files: `app/models/painting.rb`, `lib/tasks/pool.rake`
  - Verify: `paul-cezanne` heading is "Paul Cézanne"; `pool:report` lists all 6 merge groups
- [x] **T17 (P2, human: ~1h / CC: ~10min)** — controllers — aggregates-first ETag + `with_attached_image`
  - Surfaced by: E-A2/E-A3 — plan loaded before ETagging and omitted the preload `paintings_controller.rb:7` already uses
  - Files: `app/controllers/artists_controller.rb`
  - Verify: `assert_queries_count` flat as work count grows; 304 path does zero blob queries
- [x] **T18 (P1, human: ~2h / CC: ~20min)** — tests — the six fixture rows
  - Surfaced by: T1 — six accepted branches cannot be exercised by the current `paintings.yml`
  - Files: `test/fixtures/paintings.yml`
  - Verify: `bin/ci`; confirm the existing fold-budget tests still pass with the new rows present
- [x] **T19 (P1, human: ~2h / CC: ~15min)** — tests — the three mandatory regressions
  - Surfaced by: IRON RULE — `daily_test.rb:11` and `dynamic_type_test.rb:184` assert against markup this story rewrites
  - Files: `test/integration/daily_test.rb`, `test/system/dynamic_type_test.rb`, `test/system/design_test.rb`
  - Verify: `bin/ci` green before and after the `_artist_line` extraction
- [x] **T20 (P3, human: ~10min / CC: ~2min)** — views — fix the masthead screen count
  - Surfaced by: E-Q2 — `_masthead.html.erb:57` says "eight of them, seven with a compass"
  - Files: `app/views/shared/_masthead.html.erb`
  - Verify: read the paragraph; nine and eight

## GSTACK REVIEW REPORT

Branch `main`, commit `80f01ab`. Two reviews, 2026-08-18.
`/plan-design-review` (17 decisions) then `/plan-eng-review` (24 findings, SCOPE_REDUCED).

| Review | Runs (7d) | Last run | Status | Findings |
|---|---|---|---|---|
| Eng Review (PLAN) | 5 | 2026-08-19T00:5xZ | **CLEAR** | 24 findings, all folded; 1 critical gap deferred |
| Design Review (FULL) | 4 | 2026-08-19T00:08Z | CLEAR | 17 decisions, 3 code-verified defects |
| Outside Voice | 5 | 2026-08-19T00:5xZ | **issues_found** | 10 findings, `source: claude` — Codex rate-limited |
| CEO Review | 0 | — | not run | — |
| Adversarial | 0 | — | not run | — |

### Eng review sections

| Section | Findings | Outcome |
|---|---|---|
| Step 0 · Scope challenge | 3 | Release 2 split out (E5); `>=2` link rule (later reversed); normalization diagnosed |
| 1 · Architecture | 4 + 1 positive | Deny-list, `with_attached_image`, aggregates-first ETag, `artist_slug` column |
| 2 · Code quality | 4 | `_artist_line` extraction, accent-preferring heading, stale masthead count, measurement recorded |
| 3 · Tests | 26 gaps, **3 mandatory regressions** | Six fixture rows, query bounds, backfill invariant |
| 4 · Performance | 1 | Resolved by dropping E3 rather than adding a column |
| Outside voice | 10 | 2 accepted decisions reversed, 1 new front-door defect |

### What the outside voice changed

It did not merely add findings. It **reversed two decisions this review had already
accepted**, and both reversals were verified against code before being taken:

- **E3 (`>=2 works` link rule) withdrawn.** Once a one-work page was settled as a valid
  200 (X5), the tap became thin rather than empty. Withdrawing it also removed
  `artist_works_count` — a column with **no writer**: `db/seeds.rb:32` sets `artist:`
  only, and 0013's prune deletes works without decrementing siblings (X4).
- **E1's unification deferred.** The diagnosis stands (two normalizations; `curator.rb:222`
  reads `artist_key`, so `pool_quota_test` structurally cannot see a 9-work page). But
  unifying it in an app-only release would stop `pool:curate` reproducing the committed
  manifest, and the slug-based assertion this review put in the test table **would have
  gone red on day one** — `pool_quota_test.rb:31-38`, 9 > `MAX_PER_ARTIST` 5 (X2).

It also found a defect neither review saw: `daily_controller.rb:7` skips `require_reader`,
so **`/` is public while `/artists/:slug` is walled** — every anonymous first-timer would
have tapped a gold name into a sign-in bounce, making the P1 dead end worse on the one page
every new reader sees (X3).

**CODEX: unavailable** — `ERROR: You've hit your usage limit … try again at Sep 9th, 2026`,
on both attempts. **CROSS-MODEL: not absorbed.** The outside voice was a Claude subagent,
authorized by the user for this call because `CLAUDE.md` forbids the Agent tool by default.
Same model family, so it shares blind spots; what makes its findings load-bearing is that
each was verified against `daily_controller.rb`, `pool_quota_test.rb`, `db/seeds.rb`,
`Gemfile`, `ios/` and `BET.md` before being accepted.

### Strategic dissent — recorded, overruled, and kept on the record

The outside voice argued this story should not be built now. Verified: `BET.md:11` set
"app live by **Aug 14, 2026**" and that date passed four days ago with the binary never
uploaded; all five thresholds are at zero; no `solid_queue` in the `Gemfile`, only
`application_job.rb`, no APNs in `ios/`, so **Proven-baseline items 1 and 2 do not exist**;
session gate 6 is unmet, so nothing can measure this feature's success signal.

**The owner was shown this and chose to ship Release 1, then submit.** That is their call
and this review proceeded in full. It is recorded because the Aug 31 kill review reads
these files, and because neither review raised it — `CLAUDE.md` R9 says to spend the
challenge budget on scope drift and kill discipline, and both reviews spent it on
architecture instead.

### Critical gap: 1

The `NOT_AN_ARTIST` deny-list has no test, no handling, and fails silently for a culture
string a *future* source introduces. It cannot fire in Release 1 (no ingest runs here), so
it is carried into the Release 2 spec in `IDEAS.md` with its fix: a `pool:report` line
flagging single-word artist slugs holding more than one work.

### Artifacts

- `specs/0018-the-names-you-know/plan.md` — 9.6KB → 48KB
- `specs/0018-the-names-you-know/story.md` — signals and R7 note amended (X7)
- `IDEAS.md` — Release 2 → Considering (top); Keep rail → Inbox
- `~/.gstack/projects/tasteMaker/tasks-eng-review-*.jsonl` — 10 tasks
- `~/.gstack/projects/tasteMaker/…-eng-review-test-plan-*.md` — for `/qa`

**VERDICT: CLEAR — 24 findings folded, 0 unresolved, 1 critical gap deferred with its fix.**
Implementation order is in the parallelization section: Lanes A + B in parallel, then C + D,
then E. Next gate is implementation with Minitest coverage as you go (build-flow step 5),
then `/qa`.

NO UNRESOLVED DECISIONS
