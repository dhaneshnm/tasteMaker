# 0027 — The wing label — implementation plan

Date: 2026-08-21
Story: `story.md` (amended same day — see its "What ships" for the direction change).
Branch: `gallery-filter-6star`.
Design direction: **F + Plates**, chosen by the owner from the canvas
(`The Wing Label`, claude.ai artifact `a30286fb`): round 1 (three in-flow rows) and
round 2 A–E rejected; F (rail door, index as its own screen) picked; of three index
treatments (Plates / Catalogue / Floor plan), **Plates**.
Design review: **done 2026-08-21** (6/10 → 9/10, 19 decisions). Eng review: **done
2026-08-21** (9 findings + outside voice, folded; see the report at the end).

## Shape

The filter costs zero pixels on `/feed` until asked for. One glyph joins the sticky
compass rail; it opens `/feed/index`, a real page — the wings as plates. A tap on a
plate is a Turbo visit back to `/feed?tradition=…`. Nothing is ever stacked above the
art on the feed.

```
/feed                                  /feed/index
┌ masthead: label = the wing, in voice ┐  ┌ masthead: "The index" · N works ┐
│ aside = N works                      │  │ compass (Gallery dim — inside)   │
├ compass rail … [⌸ plan glyph] ───────┤  ├ Tradition — plates 4-across     │
│ art                                  │  │ Subject   — plates 4-across     │
│ art                                  │  │ Century   — caps row            │
└──────────────────────────────────────┘  │ coverage line(s), dim           │
                                          └─────────────────────────────────┘
   glyph filled ⇐ any facet active          every value counted in the scope
   of the OTHER facets, floored at 16;   a facet with nothing to offer says so
```

Three `_facet_row` renders and their CSS go away. `MIN_FACET_WORKS` 5 → 16
(`decisions/0017`; the story first wrote 20 — see eng review, outside voice #1).

## Steps

### 1. Model — scoped counts, one floor, one voice table

- `Painting.facet_counts(facet, scope: Painting.all)` — same `GROUP BY`, now against
  a passed scope. Existing callers pass nothing and get today's behaviour.
- `Painting.index_for(active)` → `{ tradition: [[value, count], …], genre: …,
  period: … }`, where each facet is counted **within the scope of the other active
  facets** (switching Mughal → Pahari is a replace, not an AND), filtered to
  `count >= MIN_FACET_WORKS`, ordered: period numeric, others by count desc
  (demand order — the index is a map, heaviest wing first). The active value stays
  in its own row even when it would otherwise be floored (it is "here", not an
  offer).
- `MIN_FACET_WORKS = 16` (`decisions/0017`). Comment records the measured list: 16
  keeps Persian & Islamic (19 — second-highest demand in 0008) and drops every named
  near-dead end (the next value up is 12th century at 15). **Lands last** (outside
  voice #11): step order is 2 → 3 → 1-floor, so the constant changes in the same unit
  as its test rewrites and the decision, never while the old rows are live.
- `resolve_facet_slug` unchanged in contract; it may now read distinct values
  (`distinct.pluck`) instead of counts — one cheaper query per facet on `/feed`.
- **Voice table** — `Painting::FacetVoice` (one file, two hashes, **hand-written by
  the owner**, CLAUDE.md's editorial rule): `short` for plate captions ("Mughal",
  "Jain", "Tibetan", "Still life", "17th") and `sentence` for the masthead label
  ("Mughal painting", "portraits", "eighteenth century"). `label_for(active)` joins
  the sentence forms tradition → subject → century, capitalises the first letter;
  empty → "The full gallery". Unknown value → falls back to the canonical value so a
  new tradition can never 500 the feed. **The table is the critical path** (outside
  voice #8): 12 traditions + 14 genre values + the century range, two forms each —
  the owner writes it **before step 1**, starting from the draft forms in the canvas
  mock (`build-f.mjs` SHORT/SENTENCE tables) and editing. The completeness test
  iterates the **vocabularies** — `Pool::Tradition::VALUES`, the genre dictionary,
  `Pool::PeriodBucket`'s possible outputs — not the database (fixtures carry no facet
  values, so a DB-driven test would be vacuous).
- **Representative plate per wing**: `Painting.plate_for(facet, value, scope:)` =
  first work in `feed_ordered` with **`display_image?`** (attached OR museum URL —
  eng 2.2; `image.attached?` alone made every fixture and test-created work faceless)
  carrying that value **within the same scope `index_for` counts it in** (the other
  active facets), walking at most five candidates. Design review,
  outside voice #9: unscoped, the face of "Portraits" inside the Mughal wing could
  be a Dutch portrait, and the tap lands on Mughal portraits — the face would lie
  about the door. Curation order is already the owner's order; no new column, no
  admin screen. A per-wing pin is a later story if a default ever embarrasses a
  wing — parked in `IDEAS.md`, not built (infrastructure for later). `nil` when no
  work in scope has a stored image — the view renders the empty box (Pass 2).

### 2. Route + controller + view — the index page

- `get "feed/index" => "paintings#wings", as: :feed_index` (eng review D1: a second
  action on the feed's controller, not a new controller — same wall, same params,
  same model). Walled by the inherited `require_reader`
  (`application_controller.rb:51`), private by default like `#index`.
- `PaintingsController#wings`: `@active = resolve_active` — one private method both
  actions call (the `@filter_params` lesson from `5d90908`, without a concern) —
  then `Painting.index_for(@active)`, `plate_for` per offered tradition/subject value
  (`limit(5)` walk, first `display_image?` — eng 2.2), coverage notes.
- View `paintings/wings.html.erb` (shape settled in the design review, Passes 1–3):
  - Masthead: `label: "The index"` (the screen's name, as every screen's label is),
    `aside:` the **scoped** count (`"108 works"`), `here: :gallery` — the compass
    renders Gallery dim and unlinked, because the index is inside the gallery and a
    linked Gallery would be a second way back that silently drops the filter
    (outside voice #6).
  - Summary, filtered only: the sentence in the `.coda__line` setting (Fraunces
    italic, `--ink-dim`) — *"Mughal painting · 108 works"* — then one caps row:
    `SHOW EVERYTHING · DONE`. Unfiltered: no sentence; the caps row is `DONE` alone.
    `Done` → `feed_path(**filter_params)`; `Show everything` → `feed_path`. The
    summary is the page's own sentence, louder than the label, not a reuse of
    `.masthead__label` (outside voice #7).
  - Three sections, each opened by an `<h2>` in the **`.days__month` setting**
    (0.72rem caps, `--ink-dim`, hairline under — the product's existing "new
    section" head, and the hairline is a table-header rule DESIGN.md already
    allows): `Tradition`, `Subject`, `Century`. When that facet is active the head
    row also carries, at its right end, a caps-link `EVERY TRADITION` (44px) that
    unsets it — the way out lives on the heading, never as a cell in the grid
    (outside voice #12; first-party Pass 1).
  - `_plates.html.erb` — `<ul class="plates">`, `repeat(auto-fill, minmax(80px,
    1fr))`. Each cell: an image **row** of fixed 80px height; the `<img>` is
    `height: 80px; width: auto; max-width: 100%`, centred, `--frame-edge` on the
    image itself and `--bg-lift` behind it — **the edge hugs the picture, not a
    square of linen** (outside voice #10: a letterboxed landscape inside a bordered
    square reads as a card with a thumbnail in it, the shape rule 6 refuses; `.days`
    already solved it this way). `src = artwork_src(plate, size: 200)`, `alt=""`,
    `width`/`height` attributes from the plate's stored dimensions scaled to 80,
    `loading="lazy"` after the first eight. Caption under the row: `short` form,
    `.masthead__aside` setting (0.72rem/0.18em caps), then the count in
    `--ink-faint` with a visually-hidden "works". Current value: image untouched,
    caption `--ink-dim`, cell an unlinked `<span aria-current="true">`.
  - Century: a wrapped caps row (`_row.html.erb`), `short` forms ("17th"), counts dim.
  - A facet with nothing to offer renders no section and one dim line: *"No subject
    has 16 works here yet."* (number from the constant, not typed twice).
  - Coverage lines — **for each of tradition / subject that is NOT active**, counted
    **inside the current scope**: with Mughal active, *"Subject is known for 24 of
    108 works."* (outside voice #4 — the first draft printed the *active* facet's
    pool-wide coverage, which is 100% by definition inside its own scope and says
    nothing). Unfiltered: the pool-wide lines (*"Tradition is known for 1,055 of
    2,302 works."*). Suppressed when coverage is 100%. Counts live, not typed.
  - A face with no stored image (`plate_for` nil): the 80px row holds an empty
    `--bg-lift` box with the frame edge, no text — the resting idiom; the wing stays
    tappable.
- Links: every value is `feed_path(**other_active.merge(facet => slug).slice(*FACETS))`
  — **canonical `FACETS` order in every URL** (outside voice #5: Hotwire Native's
  same-URL check on `Done` is byte equality; `@filter_params` already emits `FACETS`
  order, so every link must too — asserted in the wings tests) — plain links,
  **no `data-turbo-action`** (eng review 1.1 supersedes the design review's #20).
  The native stack is shaped by `ios/Tondo/path-configuration.json`: `^/feed/index$`
  → `"context": "modal"`, `"pull_to_refresh_enabled": false` (mirrored in
  `public/configurations/ios_v1.json`; `path_configuration_test` pins both). Native:
  the index rises as a sheet; a wing tap dismisses it and pushes the filtered feed;
  swipe-down is a free Done that keeps scroll position. Web: ordinary history — back
  from a filtered feed returns to the index, then the feed. Verify in the simulator
  (step 6).

### 3. The door — compass rail glyph

- `shared/_compass.html.erb`, `rail: true` only: append `<a class="compass__door"
  href=feed_index_path(**filter_params)>` (no `data-turbo-action`) carrying `shared/_plan_glyph` (23px, 1.4
  stroke, 44×44 target — functional glyph under the amended DESIGN rule 6).
  `margin-left: auto` so it sits at the rail's right end. New local `door:` (`nil` =
  none; a hash of current filter params = render). The masthead compass never
  renders it. **Rendered unconditionally** (eng review 1.3 supersedes design #14a:
  checking "does the index offer anything" costs three `GROUP BY`s per feed page,
  and production cannot hit the empty case — the pool assertion forbids it). The
  index owns its empty case with `.page--empty`.
- **The drawing, so nobody invents the product's third glyph** (outside voice #8).
  Same viewBox, stroke, and joins as the keep glyph and the oculus:

  ```html
  <svg viewBox="0 0 24 24" width="23" height="23" aria-hidden="true"
       fill="none" stroke="currentColor" stroke-width="1.4" stroke-linejoin="round">
    <rect x="4" y="4" width="16" height="16"/>
    <path d="M12 4v9M4 13h16"/>
    <%# set state only — the bottom-right room fills %>
    <rect x="12" y="13" width="8" height="7" fill="currentColor" stroke="none"/>
  </svg>
  ```

  Outline = four rooms. Set = the bottom-right room filled. Colour `--gold` in both
  states — fill is the entire state change, the keep glyph's rule. Goes into
  DESIGN.md's functional-glyph list with Keep and the oculus.
- **Accessible name carries the state VoiceOver cannot see in a fill** (outside
  voice #5, #17): `aria-label="Gallery index"` unfiltered; `aria-label="Gallery index
  — Mughal painting"` (the voice label) when set.
- **The glyph is unlabelled, and nothing teaches it** (outside voice #4 — the one
  finding not folded). The reviewer's fix was the masthead label as a worded door
  with the glyph as its sticky second instance — round 2's D + F, which the owner
  saw side by side and declined for one door. Held, recorded: the literacy gap is
  real and the receipt for it is the facet-usage instrumentation already in
  `IDEAS.md` (2026-08-20). **Tripwire:** if the next gallery run shows readers not
  finding the index unprompted, the label becomes the worded door (one partial, one
  test) — not a redesign.
- `paintings/index.html.erb`: drop the three `_facet_row` renders; pass `door:
  @filter_params` to the rail; masthead `label:` becomes `FacetVoice.label_for(
  @active)`, `aside:` stays `"#{@total} works"` (`· Mia` only when unfiltered —
  the museum credit belongs to the whole gallery).
- Delete `_facet_row.html.erb` and the `.facets*` CSS. The empty state ("Nothing
  here wears both") stays — reachable only by URL now.
- Width check, asserted: at 375px with Dynamic Type at its cap the four compass
  words plus a 44px glyph must still fit one row (`dynamic_type_test.rb` already
  measures this row; extend, don't duplicate).

### 4. CSS

- `.compass__door` — `--gold` in both states; the set state is the SVG's filled
  room, never a colour (design review Pass 5). The rail gains `flex-wrap: wrap` so
  the door can take its own line at the Dynamic Type cap (Pass 6).
- `.plates` grid (`repeat(auto-fill, minmax(80px, 1fr))`, 10px columns, 14px rows,
  `align-items: start`); `.plates__row` fixed 80px high; `.plates__img` `height:
  80px; width: auto; max-width: 100%`, `--frame-edge` on the image, `--bg-lift`
  behind; `.plates__name` in the `.masthead__aside` setting (0.72rem/0.18em caps);
  `.plates__count` `--ink-faint`. Targets: the whole `<a>` (80 + caption ≈ 112px
  tall, ≥ 80 wide) clears `--tap`.
- Index heads reuse `.days__month`; the summary sentence reuses `.coda__line`; the
  notes reuse the coda note size. No new type sizes — the ramp serves.
- `.facets*` removed.

### 5. Tests (with the work — R1)

- `test/models/painting_test.rb`: `index_for` scoped counts (fixtures: two
  traditions × two periods with known counts; the floor hides a 19-work value and
  keeps a 20); the active value survives the floor in its own row; period numeric
  order; others by count.
- `test/models/facet_voice_test.rb`: every value `displayed_facet_values` can offer
  has a `short` and a `sentence`; `label_for` composes and capitalises; unknown
  value falls back.
- `test/integration/feed_filter_test.rb` (14 tests today): keep the filter
  behaviour tests; retire the three row-render tests; add: `/feed` renders no
  `.facets`; rail door present with/without filter params and `--set` class when
  filtered; masthead label reads the sentence form.
- `test/integration/feed_filter_test.rb`, a `wings` section (same helper, same
  file — one place for the facet contract): walled; unfiltered lists every floored
  value under three `h2`s; filtered by tradition lists only centuries that co-occur;
  a facet with nothing to offer prints the one line; links carry the other active
  facets and no `data-turbo-action` (eng 1.1); coverage line iff tradition/subject
  active; `Done` and `Every tradition` hrefs; summary row states; empty index
  (`.page--empty`); plate with face / without face / current; query-count pins for
  `#index` (zero facet queries unfiltered) and `#wings` (≤ 20).
- `test/models/painting_test.rb` additions (eng): `scoped_to` with 0/1/3 facets;
  `plate_for` skips a pictureless work, returns nil after five, respects scope;
  NULL-column rows never counted.
- `test/integration/path_configuration_test.rb`: the `^/feed/index$` rule — modal
  context, pull-to-refresh off; byte-identical copies (existing test) now covers it.
- `test/lib/pool_quota_test.rb:294`: exact `BELOW_FLOOR` list (eng 1.2).
- **Zero reachable empty states** (story signal 2): a test walks every link the
  index offers, unfiltered and under each single-facet filter, follows it, and
  asserts `@total >= MIN_FACET_WORKS` — never the empty state.
- `test/system/feed_test.rb`: glyph → index → tap a plate → feed relabelled, count
  updated, glyph filled; "show everything" clears.
- `test/system/dynamic_type_test.rb`: **first `.plate__img` top edge inside the
  viewport at 390×844 on `/feed`** (story signal 1) — today false; after, true by
  ~190px. Also the rail-row fit at the accessibility cap with the glyph present.
- `test/lib/pool_quota_test.rb`: every value the dev pool offers clears 20 (the
  floor as a pool assertion, same shape as 0024's).

### 6. Verify + ship

- `bin/ci` green. Measure: `/feed` query count before/after (it should drop — no
  facet `GROUP BY`s on the feed any more); `/feed/index` query count (≤ 3 `GROUP BY`
  + ≤ 16 plate lookups + variants). If plates are slow on first hit, the variant is
  generated once and cached by Active Storage — note the cold-start cost, don't
  pre-warm (infrastructure for later).
- Simulator: the index visit, the replace-action return, back gesture.
- Owner re-rates on the real screen (story signal 4, ≥ 6/11) before merge.
- Commit, `SHIPLOG.md` line. Deploy is a separate step per `tondo-deploy-env`.

## Risks, named

- **Caption width in 80px cells** (re-decided in the design review: 0.72rem/0.18em,
  the aside's setting). A 10-character one-word form overflows; the hand-written
  `short` table is constrained to ≤ 9 characters or a spaced form, asserted by test.
  At the Dynamic Type cap spaced forms wrap to two lines — allowed (caption, not
  title); grid `align-items: start` keeps rows even.
- **Representative plate choice.** `feed_ordered.first` is deterministic but not
  chosen; a wrong face on a wing is an editorial embarrassment, not a bug. The
  owner reviews the 16 faces once before ship; a pin column is the escape hatch,
  parked.
- **Variant generation on a VPS** — 16 thumbnails × first request. `artwork_src`
  already guards the no-processor case (serves the 800px museum copy). Acceptable.
- **Modal context for `/feed/index` in Hotwire Native** (eng 1.1) — `Done` as a link
  is a same-URL visit the Navigator replaces rather than stacks; swipe-down is the
  native dismiss. Verify both in the simulator, record in Deviations.
- **Four compass words + glyph at the accessibility cap** on 375px. The compass
  comment documents 270px for the words; 351 − 270 − 3×13.65 = 40px left, and the
  glyph needs 44 with `margin-left: auto`. **Likely wraps at the cap.** Options, in
  order: (1) the rail's horizontal padding steps down 4px at the cap; (2) the glyph
  box is 44 tall but 40 wide with the hit area extended by negative margin —
  rejected, rule 9 is every direction; (3) at the cap only, the glyph drops to a
  second line. Decide at design review with a measurement, not here.

## What already exists (reused, not rebuilt)

- `Painting.facet_counts` / `displayed_facet_values` / `facet_slug` /
  `resolve_facet_slug` — gain a `scope:`; contracts unchanged.
- `artwork_src(painting, size:)` — the variant path with its no-processor fallback.
- `shared/_compass.html.erb` `rail:` mode; `shared/_masthead.html.erb` locals.
- `favorites/_keep_glyph.html.erb` — the fill-is-the-state idiom the plan glyph copies.
- `test/system/dynamic_type_test.rb` fold helpers.

## NOT in scope (considered, deferred, with reasons)

- Per-wing pinned plate (admin) — parked until a default face is wrong in practice.
- Remembering the last filter per device — no evidence; `IDEAS.md`.
- Hand-curated wings (tradition + period + a written line) — 7-star, borders New.
- Index on `/days` — chronological by design (0022 D4).
- Search — Tomás's ask, New-slot candidate.
- A sticky "Clear" on the feed — the rail glyph's filled state plus the masthead
  label carry the state; the index's "show everything" clears. One door.

## Design review — 2026-08-21 (`/plan-design-review`, all 7 passes)

Visual reference: the canvas (`The Wing Label`, artifact `a30286fb`), pages "F — working
mock" and "Index — three directions / P · Plates". No designer variants generated —
the owner chose from three rounds of pixel-matched mocks the same morning. Outside
voice: Codex rate-limited (third time on this project's facet work); Claude subagent ran
cold, `[single-model]`, findings folded below at their sites. Mode: every finding
auto-resolved to the reviewer's recommendation on owner instruction (D3), recorded
where it lands; no taste fork needed a stop.

### Pass 1 — Information architecture: 7/10 → 9/10

Hierarchy is right on both screens: art first, label second, controls last. Two fixes:

- **"Any" had no home.** A plate-less cell at the head of a 4-across plate grid
  breaks the grid and reads as a missing image. Decision: the section head carries
  it — `TRADITION` on the left, `EVERY TRADITION` as a caps-link at the right end of the
  same row ("every", not "any" — the dim word the story called meaningless stays out), rendered only when that facet is active (`.index__head` is a flex row,
  `justify-content: space-between`). The grid holds plates only.
- **The current wing's plate**: the image stays full (art is never dimmed), the
  caption steps to `--ink-dim` and the cell is an unlinked `<span>` with
  `aria-current="true"` — the 0022 pass-6 idiom, on a plate.

Index, top to bottom, final:

```
masthead   TONDO · 2,302 WORKS · ◎        (aside = count in scope)
           The index
compass    TODAY · DAYS · KEPT · GALLERY  (Gallery dim — you are inside it)
summary    Mughal painting · 108 works       (.coda__line, filtered only)
           SHOW EVERYTHING · DONE             (caps row; DONE alone when unfiltered)
TRADITION                                    EVERY TRADITION
[plate][plate][plate][plate]   4-across at 390, auto-fill elsewhere
SUBJECT
[plate][plate]…
CENTURY
13TH 40 · 14TH 35 · …            caps row, wraps
notes      Tradition is known for 1,055 of 2,302 works.
```

### Pass 2 — Interaction states: 4/10 → 9/10

| Feature | Loading | Empty | Error | Success | Partial |
|---|---|---|---|---|---|
| Rail door (glyph) | n/a — inline SVG | always rendered; the index owns the empty case (eng 1.3) | n/a | outline when no filter; quadrant filled when any facet active; colour `--gold` in both (see Pass 5) | — |
| Index page (coverage lines per outside voice #4: inactive facet, in scope) | HTML first paint is instant; plates arrive as variants resolve. Each image row is a fixed 80px; the `<img>` carries scaled `width`/`height` attributes and sits on `--bg-lift`, so nothing shifts. Plates past the first eight carry `loading="lazy"`. | Unfiltered: impossible (pool assertion). Filtered so far that no facet offers anything: summary line + `show everything` + one dim line per facet ("No subject has 20 works here yet.") — never a bare page. | A wing whose face has no stored image (`plate_for` → work with `image.attached?`; none → nil): the 80px row holds an empty `--bg-lift` box with the frame edge — the resting idiom, no text; the wing stays tappable. A variant that fails: `artwork_src` already falls back to the museum 800px copy. | Sections in demand order, counts dim, summary names the scope in voice. | A facet with some values floored inside the scope: only the survivors render; no placeholder for the missing. |
| Filtered feed | as today | By URL only (stale deep link): `.page--empty`, "Nothing here wears both.", then **two** doors: `See the full gallery` and `Open the index`. | as today | Masthead label in voice, aside count, glyph filled, coda "Every match, end to end." followed by a caps-link **`Another wing`** → `/feed/index` (new — the end of a wing walk offers the map, not a dead end). | — |
| First visit vs return | The glyph carries no onboarding: it is gold like every other control, 44px, `aria-label` below. Subtraction default — a tooltip or pulse would be ornament. | | | Nothing is remembered between sessions (non-goal). | |

### Pass 3 — Journey and emotional arc: 6/10 → 8/10

| Step | Reader does | Feels | Plan supports it |
|---|---|---|---|
| 1 | Opens `/feed` | calm — art above the fold | zero-pixel default |
| 2 | Notices the glyph on the rail, 40 works down | curiosity; gold says tappable | the only control that survives scrolling |
| 3 | Index opens as a page | orientation — "2,302 works, every wing"; a little delight at the faces | masthead + summary + plates |
| 4 | Taps Mughal | commitment | `replace` visit, lands at top of the Mughal feed, label confirms in voice |
| 5 | Walks the wing to the coda | satisfaction | "Every match, end to end." + `Another wing` (added this pass) |
| 6 | Reopens the index | recognition — glyph filled, summary says where they are, only co-occurring values offered | scoped counts |
| 7 | `Done` (or swipe the sheet down on iOS) | safety — nothing lost | `Done` returns to the **filtered** feed (added this pass); `show everything` is the only clear |

**The break that was in the plan:** the index's only way back was the compass `Gallery`,
which links to `/feed` unfiltered — pick Mughal, reopen the index, tap Gallery, Mughal
is gone. Decision: on the index the compass renders `here: :gallery` (dim, unlinked —
the index is inside the gallery), and an explicit `Done` caps-link at the right of the
summary row returns to `feed_path(**filter_params)`. One way back, one behaviour.
5-second: art. 5-minute: a wing walk that ends with the next door. 5-year: the index is
the map of a collection that keeps growing — it re-draws itself from counts.

### Pass 4 — AI-slop risk: 9/10 → 9/10

APP UI. Hard rejections: none — the one grid is faces of wings, uncropped, no cards,
no borders beyond the plate's frame edge, no radius, no shadows; the glyph is a stroke
icon, not an icon-in-a-circle. Litmus: brand in first screen YES (masthead); anchor YES
(plates); scannable by heads YES (Tradition / Subject / Century); one job per section
YES; cards necessary — there are none; motion — none by design (rule 7; native push
on iOS); premium without shadows YES, there are none. Copy is utility: "The index",
counts, "show everything". Kept as approved: captions centred under their plate (the
one centred text in the product; a caption under a picture is the convention the wall
label itself follows on `/feed`'s plate → label stack, left-aligned there because the
label is prose, centred here because it is a name under a thumbnail).

### Pass 5 — Design-system alignment: 8/10 → 9/10

- **Glyph colour corrected.** Plan said `--ink` when set. The keep glyph's rule: *fill
  is the entire state change — no colour shift, no second mark.* The plan glyph stays
  `--gold` in both states; the filled quadrant is the state. `.compass__door--set`
  changes the SVG, not the colour.
- **Caption size.** 0.66rem is a size the product does not have; the smallest is
  `.masthead__aside` at 0.72rem/0.18em. Captions use **0.72rem/0.18em** — the aside's
  exact treatment, so counts and captions share one small-caps voice. Consequence:
  a short form must fit 80px at that size ≈ **9 characters, or contain a space so it
  can wrap** ("Landscape" not "Landscapes"; "Still life" wraps; "Religious" 9). This is
  a constraint on the hand-written `short` table, asserted by a test over every
  offered value (`short.length <= 9 || short.include?(" ")`).
- `.plates` and `.compass__door` are the only new classes; both are the existing
  plate and masthead-glyph idioms at a new size — no new component family. Section
  heads reuse `.days__month` outright (`<h2>`, 0.72rem caps, hairline under) — the
  product's existing "new section" head; its hairline is a table-header rule DESIGN.md
  already allows, so the index invents nothing (outside voice #1).
- Tokens only; counts and notes `--ink-faint`/`--ink-dim` (rule 4); label sentence
  stays `.masthead__label` (italic, `--ink-faint`) — the filtered state does not get
  louder than the unfiltered one, the art stays first. The story's constraint line
  "the label sentence is `--ink`" is **struck** from the story (outside voice #19):
  the label is the screen's name on every screen and keeps that treatment; on the
  index the sentence gets its louder setting (`.coda__line`) because there it is the
  page's subject, not its name.

### Pass 6 — Responsive and accessibility: 5/10 → 9/10

- **Grid rule, one line for every width:** `grid-template-columns: repeat(auto-fill,
  minmax(80px, 1fr))`, `column-gap: 10px`, `row-gap: 14px`, `align-items: start`. 320px
  (iPhone Display Zoom, not just SE gen 1) → 3 across; 375–430 → 4; the 680px
  desktop measure → 7, image row stays 80px (outside voice #3, #16 — one rule, no
  breakpoint). Thumb box fixed 80×80,
  cell grows, caption centred under the thumb. Row heights even by grid even when a
  caption wraps at the Dynamic Type cap.
- **Rail at the cap — decided by arithmetic, not deferred to a measurement**
  (outside voice #2, checked against `_masthead.html.erb`'s recorded numbers):
  312px of 329 are spent at 375px at the Dynamic Type cap; a 44px glyph plus a gap
  needs 58; shortfall ≈ 41px. A padding step-down recovers ≈ 8px — it cannot work,
  so it is struck. Decision: `flex-wrap: wrap` on the rail; **at the cap only** the
  glyph wraps to its own line, right-aligned by its `margin-left: auto`. Cost: 44px
  of sticky at the cap, where every row is already taller; recorded in DESIGN.md's
  rule-5 exception paragraph. `dynamic_type_test.rb` asserts four words on row one
  and the glyph on row two at the cap, and one row at the default root. Not
  accepted: a 40px glyph (rule 9), or dropping the glyph at the cap (the one control
  that survives scrolling would vanish for the readers who scroll slowest).
- **Filtered fold at the cap** (outside voice #18): *"Mughal painting, portraits,
  eighteenth century"* at 0.86rem italic in the label column wraps to two lines at a
  large root and takes ~20px from the first plate. Accepted, not capped — the label
  is the filter state and truncating it would be lying about it (rule 3's spirit).
  `dynamic_type_test.rb` records the filtered-feed number beside the unfiltered one.
- **Cold plates are a UX, stated** (outside voice #15): `artwork_src` returns the
  variant object, which `image_tag` renders as a representation *redirect* URL — the
  HTML paints at once and each linen box fills as its transform completes on first
  request. That is the accepted loading state (the box IS the placeholder). The
  blocking `processed` form is not used anywhere and must not be introduced here.
- **Accessible names, written down:** door `<a aria-label="Gallery index">` when nothing is
  active, `aria-label="Gallery index — Mughal painting"` (the voice label) when set, SVG
  `aria-hidden`. Plate `<a>`: name = visible caption + count; the count is followed by
  a visually-hidden "works" so VoiceOver reads "Mughal, 108 works". Plate `<img
  alt="">` — decorative, the caption names it. Current plate: `<span
  aria-current="true">`. Sections: `<section aria-labelledby>` its head. `Done` and
  `show everything` are links with their visible text as names. Focus order follows
  source: masthead → compass → summary → plates. `:focus-visible` ring exists globally.
- Contrast: `--ink-faint` on linen is 5.1:1, above AA at 0.72rem caps. Targets: plate
  cell ≥ 80×108, century values 44, glyph 44, `Done` 44 (rule 9). Reduced motion: no
  motion to reduce. Landscape phones: grid auto-fills, nothing sticky but the rail.

### Pass 7 — Decisions (all resolved this pass)

| Decision | Resolved as | If it had been deferred |
|---|---|---|
| Way back from the index | `Done` → filtered feed; compass Gallery dim on the index | engineer wires Gallery → `/feed`, filter lost |
| Where "Every tradition" lives | section head, right end, only when active | a faceless cell breaks the grid |
| Glyph set-state | fill only, `--gold` both states | two idioms for one state |
| Caption size | 0.72rem/0.18em (`.masthead__aside`), short forms ≤ 9 chars or spaced | a new 10.5px size under the iOS 11pt floor; "LANDSCAPES" overflows |
| Grid | `auto-fill minmax(80px, 1fr)` | 320px phones break; desktop sparse |
| Missing face | empty `--bg-lift` box, frame edge, no text | broken-image icon |
| Cold plates | fixed box + `loading="lazy"` after 8 | layout shift; 16 eager variants |
| End of a wing walk | coda gains `Another wing` | dead end at the coda |
| Empty-by-URL feed | second door: `Open the index` | one door, to the wrong place |
| Rail at the cap | decided: glyph on its own rail line at the cap only (41px short, arithmetic) | wraps unpredictably |
| Plate face scope | `plate_for` takes the other-facets scope | a Dutch portrait fronts Mughal portraits |
| Plate frame | edge hugs the image (`.days` idiom), fixed 80px row | bordered linen squares read as cards |
| Glyph drawing | path specified in step 3; joins DESIGN.md's glyph list | a fourth glyph style |
| Index summary | `.coda__line` sentence + `SHOW EVERYTHING · DONE` caps row | filter state is the faintest text on the page |
| Section heads | `<h2>` in `.days__month` | three unlabeled grids — defect #1 again |
| Door when nothing to offer | rendered; index shows `.page--empty` (eng 1.3 superseded "not rendered") | a door to three "nothing yet" lines |
| Native stack | path-configuration modal context, no `replace` (eng 1.1 superseded the link attribute) | web history mangled to shape a native stack |
| Glyph literacy | one door held; tripwire on the facet-usage receipt | (accepted risk, recorded) |

### NOT in scope (design)

Onboarding for the glyph (ornament); remembered filter; pinned faces; hairlines under
section heads; left-aligned captions (kept centred as approved); any animation between
feed and index (rule 7 and the native push already animate).

### What already exists (design)

`.plate__img` idiom; `.masthead__aside` type; keep-glyph fill idiom; `.page--empty` +
ornament; compass `rail:`/`here:` contract; `aria-current="true"` for filters (0022);
`artwork_src(size:)` with its fallback; `:focus-visible` ring.

## Eng review — 2026-08-21 (`/plan-eng-review`, four sections)

Mode: every finding auto-resolved to the reviewer's recommendation on owner instruction
(D3), recorded at its fold site; stops reserved for schema / stack / wall — none
needed. Outside voice: Codex rate-limited until Sep 9 (third facet story running);
Claude subagent ran cold, `[single-model]`, its findings folded below with tags.

### Step 0 — scope

- **Scope reduced (D1):** no `FeedIndexController`, no `FacetParams` concern. The index
  is **`PaintingsController#wings`** at `/feed/index`; slug resolution is one private
  method both actions call. `Painting::FacetVoice` stays its own file — it is
  owner-edited content and should be findable without reading model logic. Steps 2–3
  above read with that substitution.
- Design doc: the spec folder is this project's design doc (D2) — not re-derived.
- Reuse confirmed: `facet_counts` / `resolve_facet_slug` / `facet_slug`
  (`painting.rb:157-190`), `display_image?` (`painting.rb:202`), `artwork_src(size:)`
  (`application_helper.rb:15-28`), `_compass` `rail:` mode, `.days__month`,
  `.coda__line`, `.page--empty`, `create_paintings` in `feed_filter_test.rb:12`,
  `pool_quota_test`'s manifest-driven floor assertions, `path_configuration_test`.

### 1. Architecture — 3 findings, all folded

**1.1 [P1] (confidence 9/10) — the native stack belongs to the path configuration,
not to a link attribute.** `ios/Tondo/path-configuration.json` is where this app
already decides how each URL presents natively (`^/$` → `clear_all`, `^/feed$` →
no pull-to-refresh), and `test/integration/path_configuration_test.rb:27` pins the
bundled and served copies byte-identical. The plan reached for
`data-turbo-action="replace"` on every index link to shape the stack; that is a web
mechanism doing native work, and it changes browser history as a side effect (design
review #20). Decision: **`/feed/index` gets its own rule — `"context": "modal"`,
`"pull_to_refresh_enabled": false`** — and the links carry **no `replace`**. Native:
the index rises as a sheet over the feed; tapping a wing dismisses it and pushes the
filtered feed (stack: feed → filtered feed); swiping the sheet down is a free "Done"
that keeps the feed's scroll position. `Done` as a link visits `feed_path(**params)`;
Hotwire Native replaces when the proposed URL equals the top's, so it reloads rather
than stacks. Web: plain history — back from the filtered feed lands on the index, then
the feed; the index is a page and behaves like one. **Supersedes design-review #20.**
Both JSON copies change (`ios/Tondo/path-configuration.json`,
`public/configurations/ios_v1.json`); `path_configuration_test` gains an assertion
for the rule. Note: `config/environments/production.rb:19` serves `public/` with a
one-year public cache — the served copy is a fallback; the bundled copy ships with
the binary, and the app is not in the store yet, so no cache-bust is needed now.

**1.2 [P1] (confidence 9/10) — the floor breaks three `pool_quota_test` assertions,
two of them 0026 success signals, and 20 was the wrong number.** `:294` (every
canonical tradition clears the floor), `:367` (Cityscape, 10), `:374` (Madhubani, 6).
Outside voice #1 caught what the story's table missed: **Persian & Islamic has 19** —
the second-most-searched tradition in 0008, 0026's ≥ 25 target landed at 19 — and a
floor of 20 would have dropped it by accident. Decision: **`MIN_FACET_WORKS = 16`**
(keeps Persian, drops every named dead end; 12th century at 15 is the next value up),
recorded as **`decisions/0017`** because it reverses 0024/0026 signals (R4). The
values stay in their tables (a label is a fact about the work; a floor is a fact about
the door). The three tests become one exact assertion: a dated `BELOW_FLOOR` list per
facet, `assert_equal` against the measured starved set — a value that starves or
recovers without the list changing fails the suite. `Flowers clears the floor`
(`:340`, 24) holds.

**1.3 [P2] (confidence 8/10) — "door only when the index offers something" costs the
feed the queries this story removes.** Deciding visibility needs `index_for({})` —
three `GROUP BY`s — on every `/feed` page and every lazy page fetch, the exact
duplicate-query shape story 0020 fixed. The case it guards (a pool with no value ≥ 16)
cannot occur in production: `pool_quota_test` asserts offered values on the committed
pool. Decision: **the door renders unconditionally; the index owns its empty case** —
`.page--empty`, ornament, *"Nothing here has sixteen works yet."* (number from the constant), and the coda's
museum credit. Reachable in dev on a fresh database and in tests; never in
production. **Supersedes design-review #14a.** The wall is inherited as-is
(`application_controller.rb:51 before_action :require_reader`); `PaintingsController`
sets no public cache header, so `#wings` is private by default like `#index`.

Realistic production failures per new codepath: (a) variant transform fails for a
plate → `artwork_src` rescues to the museum 800px copy, logged, box fills — covered by
existing helper behaviour; (b) a wing's first-in-scope work has a failed plate
download (the IDEAS.md inbox case, `image_url_800` present, attachment absent) →
see 2.2, the CDN copy fronts the wing; (c) a stale deep link to a value that dropped
under the floor → `resolve_facet_slug` still resolves it (it reads every value, not
just offered ones), the feed filters, the index shows the value in its own section as
current — the plan's "active value survives the floor" rule, already specified.

### 2. Code quality — 4 findings, all folded

**2.1 [P2] (confidence 8/10) — DRY: one scope builder.** `#index` composes
`scope.where(facet => value)` per active facet (`paintings_controller.rb`, the
`@active.each` loop); `index_for` needs the same composition minus one facet;
`plate_for` needs it plus one value. Decision: `Painting.scoped_to(active)` — one
class method, `active` a `{facet => value-or-nil}` hash — used by all three. The
controller's loop goes away.

**2.2 [P2] (confidence 9/10) — `plate_for` must use `display_image?`, not
`image.attached?`.** `painting.rb:202`: `display_image? = image.attached? ||
image_url_800.present?`, and `artwork_src` already serves the CDN copy when nothing is
attached (`application_helper.rb:16`). Every test-created painting
(`create_paintings`, `feed_filter_test.rb:12-19`) and every fixture has a URL and no
attachment — with the plan's predicate, every plate in the suite is the "missing face"
box and the happy path is untestable. Decision: `plate_for` walks the first five works
in scope (`with_attached_image`, `feed_ordered`, `limit(5)`) and returns the first
`display_image?`; nil after that. Explicit, one query (the preload keeps
`artwork_src`'s `image.attached?` from costing two more per plate — outside voice #9),
no `EXISTS` subselect on Active Storage tables. One test attaches a real blob
(`fixture_file_upload`) and asserts the rendered `<img>` `src`/`width`/`height`;
dimension math is nil-safe (`create_paintings` rows carry no `image_width`). Known:
dev has no libvips (`variant_transformer` nil), so the owner's re-rate sees the 800px
museum copies; production (`Dockerfile:19`) is the first place the 200px variant runs.

**2.3 [P2] (confidence 8/10) — stale comments and diagrams, named so they get
rewritten in the same commit.** `paintings/index.html.erb`'s facet-row comment block
(it describes three rows "in `Painting::FACETS` order"); `_compass.html.erb`'s header
("Four destinations, always all four" — now plus a door on the rail); DESIGN.md rule 5
("the wordmark, the label and the count do not" — add: the door does);
`paintings_controller.rb`'s comment on `counts`/`@facet_values` (the code it explains
is deleted). New diagram comments: in `painting.rb` beside `FACETS`, the other-facets
counting (`active = {t: Mughal, g: nil, p: nil}` → `counts(:p)` runs on `scoped_to(t:
Mughal)`, `counts(:t)` runs on `scoped_to({})`), and in `PaintingsController` a
request-flow sketch for `#index` vs `#wings` sharing `resolve_active`.

**2.4 [P2] (confidence 7/10) — explicit over clever in `FacetVoice`.** Century
sentence forms are hand-written entries for every century the pool can offer (12th–
20th today; the table holds 2nd–21st so a reseed cannot 500), not an ordinal
generator. `label_for` capitalises only the first character (so "ukiyo-e" → "Ukiyo-e",
"Tibetan & Nepalese painting" keeps its ampersand). Unknown value → canonical value,
**and** `Rails.logger.warn("[facet_voice] no form for #{value}")` so a silent fallback
leaves a trace; the completeness test keeps it from ever firing in CI.

### 3. Tests — coverage map and gaps

Framework: Minitest + fixtures + Capybara (CLAUDE.md). Existing:
`feed_filter_test.rb` (14), `feed_test.rb` (15), `dynamic_type_test.rb` (11),
`pool_quota_test.rb` (26), `painting_test.rb`, `path_configuration_test.rb` (5).

```
CODE PATHS                                                  USER FLOWS
[~] app/models/painting.rb                                  [+] Door → index → wing → feed
  ├── scoped_to(active)                                       ├── [GAP] [→E2E] glyph → /feed/index → tap plate → label, count, fill   feed_test
  │   ├── [GAP] no facets → Painting.all                      ├── [GAP] [→E2E] reopen index: scoped values, current plate dim         feed_test
  │   ├── [GAP] one facet                                     ├── [GAP] [→E2E] Done → filtered feed (params preserved)                feed_test
  │   └── [GAP] three facets AND                              ├── [GAP] [→E2E] Show everything → /feed                                feed_test
  ├── index_for(active)                                       └── [GAP]        Every tradition on the head unsets tradition only        feed_filter (wings)
  │   ├── [GAP] counts against OTHER facets (t set → p scoped, t unscoped)
  │   ├── [GAP] floor hides 15, keeps 16                    [+] Feed
  │   ├── [GAP] active value survives below floor            ├── [REGRESSION] no .facets rows; door present; masthead sentence      feed_filter 29/35/113/175 rewritten
  │   ├── [GAP] period numeric order, others by count         ├── [GAP] page-2 frame src still carries params (existing :87/:146 hold)
  │   └── [GAP] NULL column rows never counted                ├── [GAP] coda: "Another wing" link under a filter, absent unfiltered
  ├── plate_for(facet, value, scope:)                          ├── [GAP] empty-by-URL: two doors
  │   ├── [GAP] first display_image? in scope                  └── [GAP] door href carries current params; aria-label with sentence
  │   ├── [GAP] skips a URL-less, attachment-less work
  │   ├── [GAP] nil after five                               [+] Index page
  │   └── [GAP] scoped: Mughal portraits face ≠ Dutch portrait ├── [GAP] walled (401/redirect unauth)                                  feed_filter (wings)
  ├── MIN_FACET_WORKS = 16                                     ├── [GAP] unfiltered: three h2, every offered value, counts
  │   └── [REGRESSION] pool_quota :294/:367/:374 exact BELOW_FLOOR lists  ├── [GAP] filtered: only co-occurring centuries; subject → one line
  └── facet_counts(scope:) default unchanged                   ├── [GAP] coverage line iff tradition/subject active
[+] app/models/painting/facet_voice.rb                         ├── [GAP] plate with face: img, alt="", width/height, lazy after 8
  ├── [GAP] short + sentence for every offered value           ├── [GAP] plate without face: empty box, still a link
  ├── [GAP] short ≤ 9 chars or spaced                          ├── [GAP] current plate: span[aria-current], caption dim
  ├── [GAP] label_for: 0/1/3 facets, capitalisation            ├── [GAP] Every tradition link only when active; href drops that facet
  └── [GAP] unknown → canonical + warn                         ├── [GAP] summary sentence + SHOW EVERYTHING · DONE (filtered); DONE alone
[~] app/controllers/paintings_controller.rb                    ├── [GAP] empty index (no value ≥ floor): .page--empty + line + coda
  ├── #index: [GAP] no facet queries when unfiltered (query count)  └── [GAP] zero reachable empty states walk (fixtures)           feed_filter (wings)
  ├── #wings: [GAP] 3 GROUP BY + ≤16 plate lookups (query count)
  └── resolve_active: [GAP] unknown slug → nil, shared by both  [+] Native / responsive / a11y
[+] views: feed_index, _plates, _row, _plan_glyph               ├── [REGRESSION] path_configuration: ^/feed/index$ modal, no PTR, copies identical
[~] _compass (door), index.html.erb, _page.html.erb              ├── [GAP] dynamic_type: first plate in viewport at 390×844 unfiltered
[~] ios/Tondo/path-configuration.json + public copy              ├── [GAP] dynamic_type: filtered fold recorded at the cap
                                                                ├── [GAP] dynamic_type: rail one row at default, glyph on row two at cap
                                                                ├── [GAP] design_test: plates grid 3/4/7 columns at 320/390/680, no x-scroll
                                                                └── [GAP] design_test: every plate/glyph/value target ≥ 44px

COVERAGE: 0/41 new paths tested (0%) — new feature; 3 REGRESSIONS named  |  GAPS: 41 (5 E2E)
```

All gaps are written into step 5 as the test list (it already named most; this map
adds: `scoped_to` unit tests, `plate_for` predicate + five-work limit, NULL rows,
page-2 frame params under the new door, empty index page, path-configuration rule,
query-count assertions, grid column counts, target sizes). **Regressions (iron rule,
no question): `feed_filter_test` 29/35/113/175 rewritten for the door + sentence;
`:74` (the coda test) requests `page: 2` — at MIN > PER_PAGE the coda never renders
on page 1; the three `assert_select ".facets", count: 0` at `:22/:29/:128` are
vacuous after deletion and retarget at the door/label; `dynamic_type_test:368`
(measures `.facets .caps-link`) retargets at `.compass__door`; `feed_test` ~84/109/136
(click inside `.facets`, `click_on "All"`) rewritten for glyph → index → plate;
`pool_quota_test` `:294/:367/:374` → one exact below-floor list per facet;
`path_configuration_test` new rule + byte-identical copies (outside voice #3).**

The zero-reachable-empty-states walk is tractable on fixtures: `create_paintings(MIN,
tradition: "A", period: "17th century")`, `create_paintings(MIN, tradition: "B",
period: "18th century")`, `create_paintings(MIN - 1, tradition: "A", period: "18th
century")` — the walk follows every link the index offers, unfiltered and under each
single-facet filter, and asserts `assert_select ".page--empty", count: 0`, the aside
count ≥ MIN, **and that the count printed on the plate equals the landing page's
`@total`** (outside voice #10 — the one assertion that catches a scope drift between
`index_for` and the controller's filter; without it the walk re-proves arithmetic). On the committed pool, the floor assertion in `pool_quota_test`
plus the by-construction scoping is the guarantee; no pool-wide walk is needed.

### 4. Performance — 2 findings, folded

**4.1 [P2] (confidence 8/10) — the feed gets cheaper; assert it.** Today `#index` runs
three `GROUP BY`s per request, eleven times per full scroll (the `counts =` line).
After: zero facet queries unfiltered; one `distinct.pluck` per *present* param
filtered. `assert_queries_count` (or the project's existing query-count idiom) pins
both in `feed_filter_test`. Indexes exist on `genre`, `period`, `tradition`,
`feed_order` (`schema.rb:102-106`).

**4.2 [P2] (confidence 7/10) — the index's cost is bounded and stated.** Three
`GROUP BY`s on indexed columns over 2,300 rows + ≤ 16 `limit(5)` plate lookups + 16
signed redirect URLs, no transform in the request; each plate's first image request
transforms once via libvips (`Dockerfile:19` installs it; `resizing_available?`
guards the no-vips case) and Active Storage keeps the variant. Ceiling ≈ 20 queries,
all indexed, all sub-millisecond at this size; pinned by a query-count assertion so
growth is noticed. A window-function single query for faces (`ROW_NUMBER() OVER
(PARTITION BY …)`) was considered and declined — explicit over clever at 2,300 rows;
revisit if the count assertion ever moves. No caching added (Solid Cache is not in
the Gemfile yet, and nothing here earns it).

### NOT in scope (eng)

Solid Cache for facet counts; a window-function face query; pre-warming variants; a
`FacetParams` concern (reduced away, D1); moving facet values into a table (strings
stay — 0022 D1); the `data-turbo-action="replace"` approach (superseded by the path
configuration, 1.1); a cache-bust for `public/configurations/ios_v1.json` (not needed
before the store).

### Failure modes (new codepaths)

| Codepath | Realistic failure | Test | Handling | User sees |
|---|---|---|---|---|
| `plate_for` | first-in-scope work has no picture at all | yes (2.2) | skip to next, nil after 5 | empty box, wing tappable |
| variant request | libvips error on one file | existing helper rescue | CDN 800px copy | a plate, slightly larger file |
| `resolve_active` | stale slug after a rename | existing :22/:128 | nil → unfiltered | full gallery, no error |
| `index_for` | a facet column all-NULL (fresh db) | yes (empty index) | `.page--empty` | honest empty page |
| path config | served copy drifts from bundled | `path_configuration_test:27` | CI fails | n/a |
| rail at cap | fifth item wraps | `dynamic_type_test` | `flex-wrap` | glyph on its own line |
| `Done` in native | same-URL visit | manual (simulator) | Navigator replaces | feed reloads at top |

No failure mode is untested, unhandled, and silent — **0 critical gaps**.

### Worktree parallelization

| Step | Modules | Depends on |
|---|---|---|
| Model (`scoped_to`, `index_for`, `plate_for`, floor, `FacetVoice`) | `app/models/`, `test/models/`, `test/lib/` | — |
| Controller + views (`#wings`, partials, door, coda, empty-state door) | `app/controllers/`, `app/views/`, `config/routes.rb`, `test/integration/` | Model |
| CSS + DESIGN.md + glyph | `app/assets/`, `DESIGN.md`, `app/views/shared/` | — (shares `app/views/shared/` with Controller lane) |
| Path configuration | `ios/Tondo/`, `public/configurations/`, `test/integration/` | — |
| System tests (fold, grid, flow) | `test/system/` | Controller + CSS |

Lane A: Model → Controller + views (sequential). Lane B: CSS + glyph + DESIGN.md.
Lane C: path configuration. Launch A, B, C in parallel; merge; then system tests.
Conflict flag: Lanes A and B both touch `app/views/shared/` (`_compass`,
`_plan_glyph`) — give the glyph partial to Lane A and keep Lane B to CSS + DESIGN.md.

### Outside voice (Claude subagent, cold, `[single-model]`) — 12 findings

Codex: rate-limited until Sep 9. The subagent read the plan against the code and
returned twelve findings; eleven folded at their sites above, one went to the owner
as a cross-model tension:

| # | Finding | Disposition |
|---|---|---|
| 1 | Floor 20 drops Persian & Islamic (19), 2nd-highest 0008 demand | **Folded — floor 16**, `decisions/0017` |
| 2 | `pool_quota_test` :294/:367/:374 break; two are 0026 signals → R4 | Folded — exact below-floor lists + the decision |
| 3 | Unnamed breakage: `feed_filter_test:74` coda, `dynamic_type_test:368`, `feed_test` ×3, vacuous `count: 0` ×3 | Folded into step 5 regressions |
| 4 | Coverage line scoped to the active facet is meaningless; show the inactive facet in scope | Folded — supersedes the design wording |
| 5 | `Done`'s same-URL check needs canonical param order | Folded — `slice(*FACETS)` on every link, asserted |
| 6 | `/feed/index` needs a path-configuration rule | Agreed — already 1.1 (modal context) |
| 7 | Door-visibility check defeats the feed's query win | Agreed — already 1.3 (unconditional door) |
| 8 | `FacetVoice` is 88 owner-written strings on the critical path; DB-driven test is vacuous | Folded — table first, test over vocabularies |
| 9 | Plate lookups undercounted without `with_attached_image`; dev has no libvips; dimensions nil-unsafe | Folded — 2.2 extended, blob test added |
| 10 | The walk test re-proves arithmetic | Folded — asserts plate count == landing `@total` |
| 11 | Step order: floor lands last, with its tests and decision | Folded — 2 → 3 → 1-floor |
| 12 | **Strategic:** split the deletion out as Express today; gate the index on a usage receipt | **Tension → owner (D4): kept whole.** The rows came from observed theme-seeking; the index is that evidence made usable; gating on usage of a 3/11 surface measures the defect, not demand. Recorded, not re-argued. |

Checked and fine (their words): the wall is inherited; no public cache header on
`PaintingsController`; `here: :gallery` valid; `lib/pool/report.rb:70` and
`title_genre.rb:248` survive a `scope:` kwarg default; no NULL trap in the scoped
`GROUP BY`.

**CROSS-MODEL TENSION** — one: scope (#12). Review said keep whole; outside voice said
split and gate. Owner decided: whole. Everything else: agreement or a fold.

## Deviations

Implemented 2026-08-21, step order as planned (2 → 3 → 1-floor). `bin/ci` green
throughout (610 unit/integration + 66 system tests, rubocop, brakeman, bundler-audit,
importmap audit). `/simplify` ran a 4-agent pass (reuse, simplification, efficiency,
altitude) against the full diff before commit; findings and dispositions below.

**Verified, not implemented — the canonical-param-order fix (eng review 1.1/outside
voice #5) turned out to be unnecessary.** `Hash#to_query` (what `feed_path(**hash)`
uses to build a query string) sorts keys alphabetically regardless of the hash's own
insertion order — confirmed empirically (`bin/rails runner`, both
`feed_path(tradition:, period:)` and `feed_path(period:, tradition:)` produced the
byte-identical `?period=…&tradition=…`). Every link in this app is built through a
route helper, never a hand-assembled string, so two links to the "same" filtered feed
are already always byte-equal — the `Done` same-URL check Hotwire Native's Navigator
needs was never actually at risk. `Painting.scoped_to`/the shared `resolve_active` path
still landed (worth having on their own merits), but the `.slice(*FACETS)` ordering
step named in the plan was dropped as solving a problem Rails already solves.

**`/simplify` (4 agents, applied before commit):**
- **Reuse:** `.plates__img` now joins the shared `.plate__img, .days__thumb img`
  selector (`application.css`) instead of restating `object-fit`/`background`/`border`
  — the exact duplication class `.plate__img` exists to prevent. `Painting.scoped_to`
  simplified from a hand-rolled `reduce` to `where(active.compact)` — Rails already
  ANDs a multi-key hash in one call.
- **Altitude:** `_compass.html.erb`'s `door:` local changed from a hash of filter
  params (with the partial building `feed_index_path(**door)` itself) to a caller-
  resolved path string, plus an explicit `door_filled:` boolean — the partial is
  rendered from non-gallery pages too and had no business knowing the gallery index's
  route. `FACET_LABEL` and the plate-vs-row facet split (`PLATE_FACETS`) moved off
  `PaintingsController` onto `Painting::FacetVoice` — a view reaching into a
  controller constant (`wings.html.erb` read `PaintingsController::FACET_LABEL`) was
  an inverted layer, and the facet vocabulary belongs beside the rest of it
  (`LABEL_ORDER`, `SHORT`, `SENTENCE`).
- **Simplification + efficiency (same finding, two angles):** `#wings` recomputed
  `Painting.scoped_to(@active).count` a second time inside `coverage_lines` — an
  identical `COUNT(*)` twice per request. `coverage_lines` now takes the already-built
  scope and count as keyword args. `#index`/`#wings` also duplicated the same four
  lines of filter setup; both now call one private `load_active_filter`.
- **Simplification:** `create_paintings` existed only in `feed_filter_test.rb`, and
  four new `painting_test.rb` tests hand-rolled the identical shape inline. Moved to
  `test_helper.rb`'s `ActiveSupport::TestCase` block (alongside `publish_day`), shared
  by both files.
- **Skipped, named rather than silently dropped:**
  - Efficiency flagged the N+1 in `plate_for` (one query set per offered tradition/
    subject value, ~3 queries × ≤16 values). Not fixed — the reviewer's own read
    confirmed this is deliberate and already measured: the plan's step 6 and the
    `feed_filter_test.rb` "bounded number of queries" test (≤ 30) name this exact
    shape and accept it (eng review 4.2: "explicit over clever at 2,300 rows;
    revisit if the count assertion ever moves").
  - Simplification's soft note (wings.html.erb's period row could use the same
    `capture`-then-branch pattern `_plates.html.erb` uses) — explicitly flagged as
    not a hard finding by the reviewer (the two rows render different markup
    shapes). Left as two small, readable branches.
  - The `@plates` block in `#wings` rebuilds `Painting.scoped_to(@active.except(
    facet))`, which `index_for` also builds internally per facet for its own
    `GROUP BY`. This is relation-object construction in Ruby, not a duplicated
    database round trip — merging it would mean changing `index_for`'s return shape
    (rows *and* scopes) for a negligible win. Left alone.

**Browser-verified, not just test-verified.** Signed in via `/dev/sign_in` against the
real seeded dev database (2,302 works) and drove the full golden path in Chrome:
unfiltered `/feed` → door (outline, unfilled) → `/feed/index` → tap Mughal → filtered
`/feed` (label "Mughal painting", aside "108 WORKS", door filled — quadrant solid gold)
→ reopen index (Mughal marked current/dim/unlinked, Subject scoped to Portraits alone,
Century scoped to 16th/17th/18th, coverage line "Subject is known for 24 of 108 works.",
no Tradition coverage line) → `Done` → same filtered feed → scrolled to the last page →
coda "Every match, end to end." + "Another wing" → back to the index. Also drove
`tradition=korean-painting&genre=nude` (a real AND-to-zero) → the empty state, ornament,
"Nothing here wears both.", both doors ("See the full gallery", "Open the index"), and
confirmed the rail door still reads filled with the correct aria-label even on the
empty page. Every number matched the manual DB queries taken before implementation
(1,055 / 2,302 tradition coverage; 879 / 2,302 subject; Mughal 108; Persian 19).

**Observed, not chased further — a screenshot-tool rendering artifact.** In the browser
session, several `.plates__img` thumbnails (small, cross-origin museum CDN images in a
tight grid) rendered blank in Chrome DevTools Protocol screenshots on first paint, even
though direct DOM/JS inspection confirmed each was fully loaded (`naturalWidth`/
`naturalHeight` nonzero, `complete: true`, `opacity: 1`, correctly positioned, no
overlapping element via `elementFromPoint`). The same cross-origin images rendered
correctly in screenshots elsewhere on the same page (row 1 of the grid) and on the
unmodified `/feed` page's large plates. Reproduced across reloads; resolved on its own
within a few seconds each time. Read as a CDP screenshot/compositing timing quirk with
many small concurrent cross-origin loads, not a real defect — but not independently
confirmed against a second tool, so worth a glance on a real device before ship (the
existing `plate_for`/`with_attached_image` tests and the manual click-through both
prove the underlying data and links are correct regardless of this).

**Performed — iOS simulator (2026-08-21).** Xcode 26.5 was present the whole time; an
earlier pass in this session wrongly reported no access without checking. Built the
`Tondo` scheme Debug config for iPhone 17 (`xcodebuild ... -destination 'platform=iOS
Simulator,name=iPhone 17'`, ad-hoc "Sign to Run Locally"), installed, and drove it by
screenshotting the Simulator window and clicking through `System Events`.

First launch's device registration came back `401 Unauthorized` in the Rails log — a
real, pre-existing wiring bug, not a fixture problem: `DeviceRegistrationsController
.expected_app_secret` prefers Rails credentials `tondo.app_secret` (a long generated
value) over `ENV["TONDO_APP_SECRET"]`, but `Debug.xcconfig` never included
`Secrets.xcconfig` the way `Release.xcconfig` does — only Release ever picked up the
credentials-matching secret, so no Debug simulator build could ever register. Fixed by
adding `#include? "Secrets.xcconfig"` as the last line of `Debug.xcconfig`, mirroring
Release's pattern (comment updated to explain the credentials-over-ENV precedence).
Rebuilt, reinstalled, relaunched: registration succeeded (`Device` row created, no more
401), confirming the fix. Out of scope for story 0027 itself — a standing app/server
secret-wiring gap from story 0015 that happened to block this story's own verification
step — so fixed directly rather than worked around.

With a registered device, drove `/feed` → tap the rail door → `/feed/index` → `Done`:

- **`context: "modal"` renders correctly.** `/feed/index` came up with rounded top
  corners on the content card and a dimmed/grayed status-bar area above it — the
  standard iOS sheet-presentation signature — confirming Hotwire Native is reading the
  `^/feed/index$` → `context: "modal"` rule from `path-configuration.json` and
  presenting it as a sheet, not a pushed full-screen view.
- **`Done` collapses, does not stack.** Tapping `Done` (same-URL Turbo visit back to
  the unfiltered `/feed`) dismissed the sheet cleanly back to the exact prior scroll
  position (same painting, same scroll offset) with no flash of a duplicate screen and
  no back-stack artifact.

Both eng-review-1.1 open questions are now confirmed on-device, not just by JSON
byte-equality. Plate thumbnails loaded correctly once fetched (a mid-load screenshot
briefly showed placeholder boxes before images arrived — expected, not a defect).

**`/code-review` (10-angle pass, plus a live browser verification of its own top
finding): 7 findings, all fixed.**

- **[Critical] A CSS cascade bug the `/simplify` fix itself introduced.** Joining
  `.plates__img` to the shared `.plate__img, .days__thumb img` selector (the
  `/simplify` reuse fix, above) put the override block for `.plates__img`'s fixed
  80px height BEFORE that shared rule in the file. Two selectors of equal
  specificity: the LATER one wins the cascade, so the shared rule's `max-height:
  min(55vh, 55dvh)` and `width: auto` silently won, and every plate rendered at its
  natural aspect-ratio height (**measured live: 131.78px**, not 80px) — worse for
  `.plates__img--none` (the no-picture resting box, an empty `<span>`), which
  collapsed to a 2px sliver with no content to give it height. Fixed by moving the
  override block to AFTER the shared rule, the same placement `.days__thumb img {
  max-height: 100% }` already uses two rules down for the identical reason. Caught
  in the same pass: `.plates__img--none`'s own `width: 60px` had the identical bug
  one level down (it lost to `.plates__img { width: auto }`, also later in the
  file) — found by re-checking with a synthetic element after fixing the first
  instance, not by the reviewer; fixed the same way. Both re-verified live in the
  browser post-fix: 80×82 for a real plate, 80×60 for a synthetic
  `.plates__img.plates__img--none` element.
- **Two links dropped the active filter, inconsistent with the rail door's own
  behaviour on the same screens.** `_page.html.erb`'s "Another wing" (end of a
  filtered walk) and `index.html.erb`'s "Open the index" (the AND-to-zero empty
  state) both called bare `feed_index_path` instead of `feed_index_path(**
  filter_params)` / `feed_index_path(**@filter_params)` — a `filter_params` local
  already threaded through the same partial one call earlier for the pagination
  frame `src`. Fixed both. Reasoned through, not just patched: preserving the
  filter on "Open the index" from an AND-to-zero URL (e.g. `?tradition=korean-
  painting&genre=nude`) is actually the MORE useful behaviour — the reopened index
  shows Korean's real subjects (scoped by tradition alone) instead of a blank,
  unscoped page. Both re-verified live: `Another wing` on the last page of a
  Mughal-filtered walk links to `/feed/index?tradition=mughal-painting`; `Open the
  index` from the Korean+Nude empty state carries both `tradition=` and `genre=`.
- **`plate_for`'s doc comment overstated its own search depth.** It reads "the
  first work in curation order... that actually has a picture" without naming the
  five-candidate cap the code enforces (`.limit(5)`) — accurate as "the first
  among the first five," not "the first, full stop." Tightened the comment; also
  measured directly (not asserted) that this is not currently a live gap: swept
  every tradition and genre value in the committed pool for five consecutive
  picture-less works at the front of `feed_order` — zero found.
- **`index_for`'s active-value backfill can show a "0 works" current wing on a
  direct AND-to-zero URL** (two facets in the query string whose combination has
  no matches — distinct from a stale single-value deep link, which the design
  already names). Considered a full `.page--empty`-style treatment for `/feed/
  index` to match `/feed`'s; declined — the index degrades gracefully around it
  already (facets that are NOT the zero-count one stay populated, scoped only by
  the working facets), and `wings.html.erb`'s summary line already prints the true
  "· 0 works" count above every section, so nothing is hidden. Documented the
  reasoning directly on `index_for` rather than changing behaviour.
- **Re-flagged, already accepted: the N+1-shaped `plate_for` loop in `#wings`**
  (one query set per offered value). Same finding `/simplify`'s efficiency angle
  raised and the plan's own step 6/eng review 4.2 already named and bounded
  (≤ 30 queries, tested). Not changed a second time.

`bin/ci` green after every round: 611 unit/integration (up 1 for the new genre
floor-vocabulary test) + 66 system tests, 0 rubocop/brakeman/bundler-audit/
importmap warnings, throughout.

## Implementation Tasks

Synthesized from the design review's findings. Each task derives from a specific
finding above. Checkbox as you ship.

- [ ] **T1 (P1, human: ~1h / CC: ~10min)** — `paintings#wings` / `_compass` — `Done` → filtered feed; compass `here: :gallery` on the index
  - Surfaced by: Pass 3 + outside voice #6 — the only way back dropped the filter
  - Files: `app/views/paintings/wings.html.erb`, `app/views/shared/_compass.html.erb`
  - Verify: `feed_filter_test` (wings) — filtered index's `Done` href carries the params; Gallery unlinked
- [ ] **T2 (P1, human: ~1h / CC: ~10min)** — `Painting.plate_for` — face chosen within the other-facets scope, `display_image?`, `with_attached_image`
  - Surfaced by: outside voice #9 — a Dutch portrait fronting Mughal portraits
  - Files: `app/models/painting.rb`, `test/models/painting_test.rb`
  - Verify: model test with fixtures where the unscoped first work differs from the scoped one
- [ ] **T3 (P1, human: ~2h / CC: ~15min)** — `.plates` — auto-fill grid, fixed 80px image row, edge on the image, aside-size captions
  - Surfaced by: Pass 6 (320px overflow), outside voice #10 (card-shaped boxes), #11 (10.5px type)
  - Files: `app/assets/stylesheets/application.css`, `app/views/paintings/_plates.html.erb`
  - Verify: system test at 320, 390, 680 — column count 3/4/7; no horizontal scroll
- [ ] **T4 (P1, human: ~1h / CC: ~10min)** — rail door — `flex-wrap` at the cap, `--gold` both states, aria-label with state, hidden when nothing to offer
  - Surfaced by: Pass 5 (glyph colour), Pass 6 (rail arithmetic), outside voice #5 #8 #14a
  - Files: `app/views/shared/_compass.html.erb`, `app/views/shared/_plan_glyph.html.erb`, `application.css`, `DESIGN.md`
  - Verify: `dynamic_type_test` — one rail row at default root, two at the cap; `feed_filter_test` — aria-label text, door absent on an empty-index fixture set
- [ ] **T5 (P2, human: ~1h / CC: ~10min)** — index summary — `.coda__line` sentence + `SHOW EVERYTHING · DONE` row; `<h2 class="days__month">` heads with `EVERY <FACET>` at right when active
  - Surfaced by: Pass 1, outside voice #1 #7 #12
  - Files: `app/views/paintings/wings.html.erb`
  - Verify: `feed_filter_test` (wings) — three `h2`s; `Every tradition` present only when tradition active
- [ ] **T6 (P2, human: ~30min / CC: ~5min)** — `FacetVoice` short forms — ≤ 9 chars or spaced, asserted
  - Surfaced by: Pass 5 caption constraint
  - Files: `app/models/painting/facet_voice.rb`, `test/models/facet_voice_test.rb`
  - Verify: the test over every offered value
- [ ] **T7 (P2, human: ~30min / CC: ~5min)** — coda `Another wing` + empty-state `Open the index` doors
  - Surfaced by: Pass 2/3 — dead end at the coda; one door on the empty state
  - Files: `app/views/paintings/_page.html.erb`, `app/views/paintings/index.html.erb`
  - Verify: `feed_filter_test` — both links present in their states
- [ ] **T8 (P2, human: ~30min / CC: ~5min)** — plates a11y — `alt=""`, visually-hidden "works", `aria-current` on the current plate, `<section aria-labelledby>`
  - Surfaced by: Pass 6, outside voice #13 #17
  - Files: `app/views/paintings/_plates.html.erb`
  - Verify: `feed_filter_test` (wings) assertions on the markup
- [ ] **T9 (P2, human: ~30min / CC: ~5min)** — `dynamic_type_test` — filtered-feed fold recorded at the cap
  - Surfaced by: outside voice #18
  - Files: `test/system/dynamic_type_test.rb`
  - Verify: the recorded number
- [ ] **T10 (P3, human: ~15min / CC: ~2min)** — QA note: on web, back from a filtered feed lands on the index, then the feed (modal context native)
  - Surfaced by: design outside voice #20, revised by eng 1.1
  - Files: `/qa` run notes
  - Verify: not filed as a bug

_Eng review tasks:_

- [ ] **T11 (P1, human: ~2h / CC: ~15min)** — `PaintingsController#wings` + route; `resolve_active` shared private method; no concern, no new controller
  - Surfaced by: Eng Step 0 / D1
  - Files: `app/controllers/paintings_controller.rb`, `config/routes.rb`, `app/views/paintings/wings.html.erb`
  - Verify: wings integration tests; `#index` behaviour unchanged
- [ ] **T12 (P1, human: ~1h / CC: ~10min)** — path configuration: `^/feed/index$` → modal context, pull-to-refresh off; both copies; drop all `data-turbo-action`
  - Surfaced by: Eng 1.1 (+ outside voice #6)
  - Files: `ios/Tondo/path-configuration.json`, `public/configurations/ios_v1.json`, `test/integration/path_configuration_test.rb`
  - Verify: new rule test; byte-identical test; simulator: sheet rises, wing tap pushes, swipe-down keeps scroll
- [ ] **T13 (P1, human: ~1h / CC: ~10min)** — `MIN_FACET_WORKS = 16`, lands LAST; exact `BELOW_FLOOR` lists replace `pool_quota_test` :294/:367/:374; `decisions/0017` committed in the same unit
  - Surfaced by: Eng 1.2 + outside voice #1 #2 #11
  - Files: `app/models/painting.rb`, `test/lib/pool_quota_test.rb`, `decisions/0017-the-floor-is-sixteen.md`
  - Verify: `bin/ci` green with the lists exact
- [ ] **T14 (P1, human: ~1h / CC: ~10min)** — `Painting.scoped_to(active)` used by `#index`, `index_for`, `plate_for`; canonical `slice(*FACETS)` on every facet link
  - Surfaced by: Eng 2.1 + outside voice #5
  - Files: `app/models/painting.rb`, `app/controllers/paintings_controller.rb`, views
  - Verify: model tests for 0/1/3 facets; URL-order assertion in wings tests
- [ ] **T15 (P1, human: ~2h / CC: ~20min)** — regression rewrites: `feed_filter_test` :22/:29/:74/:113/:128/:175, `feed_test` ~84/109/136, `dynamic_type_test:368`
  - Surfaced by: Test review + outside voice #3
  - Files: `test/integration/feed_filter_test.rb`, `test/system/feed_test.rb`, `test/system/dynamic_type_test.rb`
  - Verify: suite green; none of the rewritten tests is vacuous
- [ ] **T16 (P1, human: ~2h owner / CC: n/a)** — `FacetVoice` table written by the owner before step 1 (start from the canvas draft); completeness test over vocabularies
  - Surfaced by: Eng 2.4 + outside voice #8
  - Files: `app/models/painting/facet_voice.rb`, `test/models/facet_voice_test.rb`
  - Verify: every vocabulary value has both forms; short ≤ 9 chars or spaced
- [ ] **T17 (P2, human: ~30min / CC: ~5min)** — coverage lines: inactive facet, counted in scope; suppressed at 100%
  - Surfaced by: outside voice #4
  - Files: `app/views/paintings/wings.html.erb`, controller
  - Verify: wings test — Mughal active → "Subject is known for N of 108 works."
- [ ] **T18 (P2, human: ~1h / CC: ~10min)** — query-count pins: `#index` zero facet queries unfiltered; `#wings` ≤ 20; one plate test with a real blob; nil-safe dimensions
  - Surfaced by: Perf 4.1/4.2 + outside voice #9
  - Files: `test/integration/feed_filter_test.rb`, `test/models/painting_test.rb`
  - Verify: the assertions
- [ ] **T19 (P2, human: ~1h / CC: ~10min)** — stale comments rewritten: `paintings/index.html.erb` facet block, `_compass` header, `paintings_controller` counts comment, DESIGN.md rule 5 + glyph list; new diagrams in `painting.rb` and the controller
  - Surfaced by: Eng 2.3
  - Files: as listed
  - Verify: `/code-review` reads them against the code

## GSTACK REVIEW REPORT

| Review | Trigger | Why | Runs | Status | Findings |
|--------|---------|-----|------|--------|----------|
| CEO Review | `/plan-ceo-review` | Scope & strategy | 0 | — | — |
| Codex Review | `/codex review` | Independent 2nd opinion | 0 | — | rate-limited until Sep 9 (third facet story running); Claude subagent ran as the outside voice both times |
| Eng Review | `/plan-eng-review` | Architecture & tests (required) | 1 | CLEAR (PLAN) | 9 issues (arch 3, quality 4, perf 2) + 41 test gaps mapped, 3 regressions named; scope reduced (one controller, two actions); 0 critical gaps |
| Design Review | `/plan-design-review` | UI/UX gaps | 1 | CLEAR (FULL) | score: 6/10 → 9/10, 19 decisions |
| DX Review | `/plan-devex-review` | Developer experience gaps | 0 | — | — |

- **CROSS-MODEL:** `[single-model]` both reviews — Codex unavailable; Claude subagents
  ran cold each time. Design: 20 findings, 10 new folded, 1 held with a tripwire. Eng:
  12 findings, 11 folded (the load-bearing ones: floor 20 would have dropped Persian &
  Islamic at 19 → **floor 16, `decisions/0017`**; coverage line must name the inactive
  facet inside the scope; canonical param order for the native same-URL check; five
  breaking tests the plan had not named), 1 tension (split the deletion out and gate
  the index on a usage receipt) → owner kept the story whole (D4). Two eng findings
  superseded two design decisions, on the record: the native stack moves from
  `data-turbo-action="replace"` to the path configuration's modal context (eng 1.1 over
  design #20); the door renders unconditionally and the index owns its empty state
  (eng 1.3 over design #14a).
- **VERDICT:** DESIGN + ENG CLEARED — ready to implement. Build order: step 2 → step 3
  → step 1's floor last (with its test rewrites and `decisions/0017` in one unit);
  `FacetVoice` table written by the owner first. Mode FULL_REVIEW with scope reduced
  per D1; all findings auto-resolved to the reviewer's recommendation on owner
  instruction (D3), each recorded at its fold site; one owner decision (D4) recorded.

NO UNRESOLVED DECISIONS
