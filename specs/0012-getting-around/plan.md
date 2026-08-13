# 0012 — Implementation plan
Status: **Design-reviewed** (`/plan-design-review` 2026-08-13 — 4 decisions, 6/10 → 9/10)
and **Eng-reviewed** (`/plan-eng-review` 2026-08-13 — 12 findings, Codex outside voice
absorbed, 2 critical regressions found). Ready to implement.

**Sequencing:** story 0011 (rename to Tondo) is uncommitted in the working tree and touches
`shared/_masthead.html.erb`, which is the file this plan edits most. 0011 lands first. This
plan assumes the single-masthead-partial world 0011 created.

## Approach

One question decides the whole shape: **where do the four doors live?**

The codas already do this work ad hoc — `/days` ends with "Your collection →" and
"Today →", `/collection` ends with "The days behind you →" and "Today →", the daily page
ends with "Wander the full gallery →". Three screens, three different subsets, three
different phrasings, and one screen (`/feed`) that got none of it because its footer is 110
works down an infinite scroll.

So the fix is: **make the set of doors one component, render it in one place on every
screen, and delete the ad-hoc footers it duplicates.**

### What the design review measured

The first draft proposed rendering *the other three* destinations in the masthead, in the
product's long voice, as a third row. Built in the real stylesheet with the real fonts and
measured at 375×667 — the viewport `ApplicationSystemTestCase` pins every system test to —
that shape does not survive:

| Shape | Masthead @375 | Plate top | `noteTop + lineHeight` @root 20px | Verdict |
|---|---|---|---|---|
| ships today, no compass | 64px | 80 | 575 ≤ 667 ✓ (92px spare) | — |
| **first draft**: other three, long voice | **192px**, 3 rows | 208 | **702 > 667 ✗** | fails `dynamic_type_test.rb` |
| long voice, four items | 192px, 3 rows | 208 | **746 > 667 ✗** | fails worse |
| two-word copy, four items | 148px, 2 rows | 164 | 658 ≤ 667 ✓ | passes, costs a permanent second row |
| **approved**: one-word copy, four items | **104px**, 1 row | 120 | 658 ≤ 667 ✓ (9px spare) | approved |
| approved @1280 | **75px** | 106 | — | rides the grid's spare right column |

**The cost is rule 9, not the copy.** `.caps-link` sets size and tracking, never height, so
every compass row costs a full 44px of target. Long labels wrap to three rows at 375px.
The number to design against is the row count, not the text width.

`dynamic_type_test.rb` asserts `noteTop + lineHeight <= viewport` at root 20px — story
0008's forcing function for the Better-bucket bar *"art and text visible together"*, the bar
the category leader fails. The first draft proposed chrome that breaks it. Its own gate
("±40px at default size") was written three times too loose because it guessed.

### The approved shape

```
Phone (< 46rem)                          Desktop (≥ 46rem)
┌────────────────────────────┐           ┌──────────────────────────────────────────┐
│ TONDO         13 AUG 2026  │           │ TONDO   TODAY DAYS KEPT GALLERY  13 AUG  │
│ Artwork of the Day         │           │ Artwork of the Day                       │
│ TODAY  DAYS  KEPT  GALLERY │           ├──────────────────────────────────────────┤
├────────────────────────────┤           104px @375, 1 row      75px @1280
```

1. **All four render, always. The current one is not a link.** Rendering only "the other
   three" moves the first slot's meaning between screens; the plan's claim was "learned
   once". The current destination renders in place, in `--ink-dim`, with
   `aria-current="page"`, **keeping `.caps-link`** — same size, same tracking, same 44px
   box, differing only in colour. As a bare `<span>` it falls out of small caps into body
   type and reads as a bug.
2. **One-word copy: `TODAY · DAYS · KEPT · GALLERY`.** The only set that fits one row at
   375px. The compass is signage; the voice stays in the note and the coda.
3. **No separator glyph.** 1.4rem gaps at 0.2em tracking already separate the words, and
   `·` is spent twice (`.label__artist-dates`, `Kept · Remove`).
4. **Wide screens use explicit named areas, all four of them.** See step 5 — the aside must
   be named, not left to implicit placement.

### `here:` is a tri-state contract, not a required local

```
here:  nil          → four links, nothing dimmed   (/days/:date, /404)
       :today       → TODAY dimmed                 (/, daily/empty, admin preview)
       :days        → DAYS dimmed                  (/days)
       :collection  → KEPT dimmed                  (/collection)
       :gallery     → GALLERY dimmed               (/feed, on the rail)
       anything else → raise
```

**`/days/:date` passes `nil` on purpose.** An archived day is a *member* of the archive, not
the archive. Dimming `DAYS` there would delete the only route from one old day back to the
list — `days/_walk` gives previous, next and today, and nothing else. `/404` is the same
shape: it is not one of the four surfaces.

**The admin preview is a seventh render path.** `admin/daily_picks_controller.rb:56` renders
`template: "daily/show"`, so `daily/_day` maps `chrome:` → `here:` for all three modes,
including `:preview` → `:today`. Without that mapping the preview raises on a missing local.

### The feed: one compass, in a sticky rail, with no JavaScript

The design review approved a 58px links-only rail. **The plan originally described it as the
masthead hiding its brand once stuck, and that is not implementable.** There is no
cross-browser stuck-state selector, iOS Safari is the target, and this app has no
scroll-observing Stimulus controller (`artwork`, `expand`, `hello`, `picker`, `reveal`,
`word_count`).

Structure instead:

```
/feed
  <header class="masthead">          ← compass: false. Scrolls away, as today.
      TONDO / The full gallery / 110 WORKS · MIA
  <nav class="rail">                 ← position: sticky, top: 0. The only compass on /feed.
      TODAY  DAYS  KEPT  GALLERY(dim)
  <main class="page">                ← turbo frames stream in here
```

At scroll 0 it reads as the compass under the masthead; once scrolled it is the 58px rail.
Zero JavaScript, zero state, nothing to observe.

**One compass per page, always.** `/feed`'s masthead passes `compass: false`; every other
screen's masthead renders it. Two `<nav aria-label="Sections">` landmarks on one page would
be a defect, not a redundancy.

Measured at 375×667 scrolled 1200px:

| Sticky shape | Height | Share of screen |
|---|---|---|
| whole masthead sticks (first draft) | 104px | 16% |
| condensed: brand + compass | 103px — **wraps, saves nothing** | 15% |
| **approved: the rail** | **58px** | **9%** |

`DESIGN.md` rule 5 ("Nothing hovers over a painting. The masthead is not sticky") protects
the screens whose job is *one artwork* — `/` and `/days/:date`. `/feed` is a corridor, not a
room. The narrowing goes into `DESIGN.md` and gets a `decisions/` entry (R4). **The
exception is spent on navigation only, never on branding** — that sentence goes in the rule.

**Stacking, read from the real CSS rather than assumed:** `.zoom` is `z-index: 20`
(`application.css:747`); `body::after`, the paper-tooth overlay, is `position: fixed;
inset: 0; pointer-events: none; z-index: 3` (`application.css:192-197`); `.sentinel` has **no
z-index at all**. The rail takes `z-index: 1` — above the page flow, below the paper tooth
like everything else, far below the zoom overlay. No transition on any property: rule 7
allows a fade and nothing else.

### What gets deleted, and what does not

| Removed | Why |
|---|---|
| `days/index` coda's `Your collection →` and `Today →` | compass carries both, unconditionally |
| `favorites/index` coda's and empty state's `The days behind you →` / `Today →` | same |
| `daily/empty`'s `Wander the full gallery →` | the compass is right above it on a nearly empty page |
| the daily masthead's conditional date **link** and its `capture` block | `DAYS` is now a labelled door that is always there |

**Kept, against the design review's first instinct** (eng review D6, outside voice):

- **`daily/_day`'s coda `Wander the full gallery →`.** The coda is the closing beat, not a
  menu — `DESIGN.md` lists a link as part of it. An invitation at the end of a reading is a
  different object from an exit sign in the top bar, even pointing at the same URL. Deleting
  it would end the daily ritual on a full stop.
- **The keep frame's `N kept →`.** The count is the only per-visitor number in the product
  and it is the reward for keeping something. The compass door is countless by necessity, so
  it cannot carry the count.
- **`days/_walk`** prev · next · today. Movement *within* the archive.

`@published_count` also stays: `daily_controller.rb:21` folds it into the page's ETag, which
is what expires a cached front door when a second day exists. Only the view local goes. Say
so in the diff — a reviewer will read the deletion as dead code otherwise.

---

## Steps

1. **`app/helpers/application_helper.rb` — the destination list.**
   ```ruby
   COMPASS = [
     [ :today,      "Today",   :root_path ],
     [ :days,       "Days",    :days_path ],
     [ :collection, "Kept",    :collection_path ],
     [ :gallery,    "Gallery", :feed_path ]
   ].freeze
   ```
   **Route helpers cannot be frozen into the constant** — they are request-context methods,
   so the constant holds the method name and `compass_destinations` resolves it with
   `public_send` at render time. The method raises on any non-nil `here:` outside the keys.

2. **`app/views/shared/_compass.html.erb`.** One local, `here:`. Renders all four inside
   `<nav class="masthead__compass" aria-label="Sections">`; the current one is
   `<span class="caps-link" aria-current="page">`, the rest are `<a class="caps-link">`.
   No conditionals, no counts, no per-visitor anything.

3. **`shared/_masthead.html.erb` gains `here:` and `compass:` (default `true`).** Update all
   six call sites: `daily/_day` (maps `chrome:` → `here:`), `daily/empty` (`:today`),
   `days/index` (`:days`), `favorites/index` (`:collection`), `paintings/index`
   (`compass: false`), `errors/not_found` (`nil`). `daily/empty` renders the compass like
   every other screen; its brand stays a `<span>` (`test/integration/brand_test.rb`).
   **Rewrite the partial's header comment** — it documents `linked/aside/aside_html` in a
   table, `aside_html` is being deleted and `here:`/`compass:` added. A stale doc comment is
   worse than none.

4. **`daily/_day`: the date stops being a link.** Delete the `capture`, the
   `published_count > 1` branch and the `aside_html` local from the masthead partial (only
   the daily page used it; `aside:` string covers what is left). Keep `@published_count` and
   the ETag.

5. **Remove the coda links listed above.** Leave the daily page's gallery invitation and the
   keep frame alone.

6. **CSS — `application.css`, in the masthead block.**
   - `.masthead__compass`: grid row spanning both columns, `display: flex`,
     `flex-wrap: wrap`, `column-gap: 1.4rem`, `margin-top: 0.35rem`. Children get
     `display: inline-flex; align-items: center; min-height: 44px` (rule 9 — the row's whole
     cost). Extend the existing `.coda .caps-link` selector list; do not write a second
     sizing block.
   - Current item: `color: var(--ink-dim)` and nothing else.
   - `@media (min-width: 46rem)`: **name every area explicitly** —
     `grid-template-areas: "brand compass aside" "label compass aside"` with
     `grid-template-columns: 1fr auto auto`. The first draft named only brand/label/compass,
     which drops `.masthead__aside` (`application.css:274`) into implicit placement. It
     happened to render at 1280 in the review harness; that is luck, not design. **Measure
     the aside's position at 1280 after this lands.**
   - `.rail` (feed only): `position: sticky; top: 0; z-index: 1; background: var(--bg)`,
     the hairline underneath, vertical padding `0.45rem` / `0.35rem`, plus the existing
     `env(safe-area-inset-top)` term — under `viewport-fit=cover` that is what holds it
     clear of the notch (story 0008). No transitions.
   - Delete `.coda > .caps-link + .caps-link` and `.page--empty > .caps-link + .caps-link`
     if step 5 leaves no coda with two adjacent caps-links.

7. **The 9px problem, named so it does not surprise anyone.** With the compass the note's
   first line clears the fold at root 20px by **9px**; today it clears by 92. The compass
   spends 91% of the accessibility headroom. Run `dynamic_type_test.rb` **first**, before
   any CSS polish — the review's numbers come from a static harness and the real page may
   differ by a few pixels. If it fails by a small margin the lever is `column-gap`
   (1.4rem → 1rem), not the 44px target and not the plate cap.

8. **`DESIGN.md`.** Rewrite rule 5: nothing hovers over *an artwork*; the masthead is not
   sticky on `/` or `/days/:date`; `/feed` is the named exception and the exception is spent
   on navigation only, never on branding. Add `.masthead__compass` and `.rail` to Components
   with the current-item treatment and the 44px-per-row cost written down.

9. **`decisions/0008-the-compass-and-the-sticky-rail.md`** (R4). Position: navigation is a
   web-page concern here, one component carries it on every screen, the set never changes
   shape, and the one unbounded screen gets a links-only sticky rail with no JavaScript.
   Falsifiable prediction tied to BET.md's five conversations and the Aug 31 review: no
   reader raises "how do I get back" unprompted, and no fifth navigation surface or native
   tab bar is added before the kill review. Cross-reference `decisions/0006` — this is the
   amendment its "three ways" clause needed, not a reversal.

10. **Tests (written with the code — R1).** See below.

11. `bin/ci` green → `/qa` → `/simplify` → `/code-review` → re-verify → ship + SHIPLOG line.

## Tests

**Two critical regressions — the IRON RULE applies, these are not optional.**

- **`test/system/days_test.rb:9` — CRITICAL.** The story-0003 test "two taps from the front
  door reach a past day" navigates with `find("time.masthead__aside a").click`. Step 4
  deletes that link. The test must be rewritten to click the compass's `DAYS`, and it is
  still the two-taps test — the tap count must not go up.
- **`test/system/favorites_test.rb:89-101` — CRITICAL.** "a coda with two ways out separates
  them" asserts `.coda .caps-link, count: 2` and a ≥16px gap between them. Step 5 deletes
  both links, so the test's subject disappears. **Rehome it to the compass**: four items,
  each ≥44px tall, adjacent items ≥16px apart. That is the same defect it was written to
  catch (ISSUE-002), on the element that now carries it.

New and extended coverage:

- **`test/integration/navigation_test.rb`** — the matrix and the forcing function. For `/`,
  `/days`, `/days/:date`, `/collection`, `/feed`, `/404`: assert a link to each *other*
  surface. On the four surface pages assert the current item renders **without** an `href`
  and **with** `aria-current="page"`. On `/days/:date` and `/404` assert **four links and no
  dimmed item**. **Scope every assertion to `.masthead__compass` or `.rail`** — the word
  "Today" also appears in `days/_walk`, so an unscoped assertion proves the wrong element.
  Cover the empty-artwork case, the one-published-day case, and the admin preview
  (`here: :today`).
- **`_compass` contract** — a unit-level assertion that an unknown non-nil `here:` raises,
  and that `nil` renders four links.
- **`/feed` renders exactly one `nav[aria-label="Sections"]`.** The masthead must not also
  emit one.
- **`test/system/dynamic_type_test.rb` — widened (eng review D7).** The existing root-19.2
  and root-20 fold assertions run against one fixture: a hand-written note. Extend them to a
  **museum-copy day** (`.label__text`, the `label__body` branch) and a **long-title,
  two-line-artist** fixture. With 9px of margin, one fixture is a coincidence, not a test.
- **`test/system/feed_test.rb`** (new) — scroll past the first page, assert the rail's
  `TODAY` is **in the viewport** (`getBoundingClientRect().top >= 0`), not merely in the
  DOM; a presence assertion passes today, on the broken page, via the wordmark. Assert the
  rail is under 70px tall and that the masthead's brand has scrolled out.
- **Touch targets** — the 44px assertions live in `test/system/favorites_test.rb:74-98` and
  `test/system/days_test.rb:68`, **not** `design_test.rb`, which has none. The rehomed
  favorites test covers the compass; leave `days_test.rb`'s three walk controls alone.
- **`test/integration/public_cache_headers_test.rb`** — extend: `/` and `/days` still
  `public, no-cache`, still no `Set-Cookie`, with the compass rendered.
- **`test/integration/brand_test.rb`** — unchanged, must stay green.
- **Regression sweep:** `days_test.rb`, `favorites_test.rb`, `daily_test.rb` assert coda
  links that step 5 deletes. Update them to assert the compass — do not just delete the
  assertions.

## Failure modes

| Codepath | Realistic failure | Test? | Error handling? | Reader sees |
|---|---|---|---|---|
| `compass_destinations` with a bad `here:` | typo in a call site | yes (raises) | raises loudly | 500 in dev, caught in CI |
| masthead missing `here:` on the preview path | curator previews a queued day | yes (preview case) | raises | would 500 the admin preview |
| compass row wraps at accessibility text size | reader at root 20px on a museum-copy day | **yes, after D7** | none possible | artwork with no words under it |
| `.rail` sticky under the zoom overlay | reader zooms from the feed | z-index asserted | none needed | overlay covers it (z 20 > 1) |
| two `nav[aria-label="Sections"]` on `/feed` | masthead not passed `compass: false` | yes | none | duplicate landmark for screen readers |

No failure mode is silent-and-untested-and-unhandled. **Zero critical gaps.**

## What already exists — reuse, do not reinvent

- `.caps-link` — the one link style. The compass adds no second one.
- `.coda .caps-link` — already carries the 44px min-height. Extend the selector list.
- `.masthead` grid — already `1fr auto`, which is why the wide-screen layout is nearly free.
- `application_controller.rb:47` — `etag { config.x.revision }` already busts conditional
  GETs on template-text changes. **The compass needs no cache work**; that line exists
  because story 0011 would otherwise have shipped a rename behind unchanged ETags.
- `days/_walk` — its `aria-label` ("Move between days") already differs from the compass's
  ("Sections"), so the two landmarks are distinguishable.
- `✦`, `--ink-dim`, `--gold`, `--hairline` — no new token, no new ornament.

## NOT in scope — considered and deferred, with reason

- **A Stimulus scroll observer for a shape-changing sticky bar.** The structural rail gets
  the same 58px with no JavaScript.
- **A separator glyph between compass items.** `·` is spent twice already.
- **A condensed sticky bar keeping the wordmark.** Measured at 103px — it wraps, saving
  nothing.
- **Repeating the compass between feed pages instead of sticking it.** Ten navigation rows
  inside the artwork stream reads as an interruption.
- **Dropping the keep frame's `N kept →`, or the daily coda's gallery invitation.** Both
  reviewed and kept.
- **`paintings_controller.rb:8-9` runs `Painting.count` twice per feed request** — once for
  `@next_page`, once for `@total`, on every lazy infinite-scroll frame. Pre-existing, not
  caused by this story, and not fixed here. Captured as T9 below rather than lost.
- **Animating the rail.** Rule 7 allows a fade; nothing else.
- **A kept count in the masthead**, a fifth surface, breadcrumbs, search, artist directory.

## Parallelization

Sequential implementation, no parallelization opportunity. Every step touches
`app/views/shared/` or `application.css`; the test updates depend on the view changes
landing first.

## Approved renders

| Screen | Path | Direction |
|---|---|---|
| Daily, approved shape | `…/scratchpad/dr0012/shot-daily-B.png` | four items, one-word copy, current dimmed |
| Daily, rejected first draft | `…/scratchpad/dr0012/shot-daily-A.png` | three long labels, three rows, fails the fold |
| Feed rail | `…/scratchpad/dr0012/shot-feed-C.png` | 58px links-only rail over the stream |

Harness (real `application.css`, real woff2, throwaway):
`/private/tmp/claude-501/-Users-dhaneshneelamana-projects-tasteMaker/0de7c058-fd63-45b4-812c-dc2788d7fdde/scratchpad/dr0012/`.
The renders show the current item as a bare `<span>` — that is the harness, not the spec.
Step 2 puts `.caps-link` on it.

## Implementation Tasks
Synthesized from both reviews. Each task derives from a specific finding.

- [ ] **T1 (P1, human: ~20min / CC: ~4min)** — helper — `COMPASS` constant + `compass_destinations`, route helpers resolved at render
  - Surfaced by: Eng review / Codex — route helpers cannot be frozen into a constant
  - Files: `app/helpers/application_helper.rb`
  - Verify: unknown non-nil `here:` raises; `nil` returns four linked destinations
- [ ] **T2 (P1, human: ~15min / CC: ~3min)** — compass — Partial renders all four, current unlinked with `aria-current`
  - Surfaced by: Design review Pass 1 — rendering "the other three" moves link positions between screens
  - Files: `app/views/shared/_compass.html.erb`
  - Verify: `test/integration/navigation_test.rb`
- [ ] **T3 (P1, human: ~30min / CC: ~6min)** — masthead — `here:` tri-state + `compass:` flag across six call sites, header comment rewritten
  - Surfaced by: Eng review D4/D5 — `/days/:date` and `/404` pass `nil`; admin preview is a seventh render path
  - Files: `app/views/shared/_masthead.html.erb`, `daily/_day`, `daily/empty`, `days/index`, `favorites/index`, `paintings/index`, `errors/not_found`
  - Verify: admin preview renders; `/feed` emits exactly one `nav[aria-label="Sections"]`
- [ ] **T4 (P1, human: ~30min / CC: ~6min)** — CSS — Compass row, explicit wide-screen areas including `aside`
  - Surfaced by: Codex — naming only brand/label/compass drops `.masthead__aside` into implicit placement
  - Files: `app/assets/stylesheets/application.css`
  - Verify: aside position measured at 1280; masthead 104px @375 / ~75px @1280
- [ ] **T5 (P1, human: ~30min / CC: ~5min)** — feed — Structural sticky `.rail`, no JavaScript
  - Surfaced by: Eng review D3 — no cross-browser stuck-state selector exists
  - Files: `app/views/paintings/index.html.erb`, `app/assets/stylesheets/application.css`
  - Verify: new `test/system/feed_test.rb` — TODAY in viewport at scroll 1200, rail < 70px
- [ ] **T6 (P1, human: ~30min / CC: ~6min)** — tests — Rewrite `days_test.rb:9` off the deleted date link
  - Surfaced by: Codex — the story-0003 two-taps test navigates via `time.masthead__aside a`
  - Files: `test/system/days_test.rb`
  - Verify: still two taps, now through the compass
- [ ] **T7 (P1, human: ~25min / CC: ~5min)** — tests — Rehome `favorites_test.rb:89-101` to the compass
  - Surfaced by: Eng review — step 5 deletes both links the test counts
  - Files: `test/system/favorites_test.rb`
  - Verify: four items, each ≥44px, adjacent items ≥16px apart
- [ ] **T8 (P1, human: ~40min / CC: ~8min)** — a11y — Widen `dynamic_type_test.rb` to museum-copy and long-title fixtures
  - Surfaced by: Eng review D7 — 9px of margin verified against one friendly fixture
  - Files: `test/system/dynamic_type_test.rb`
  - Verify: fold assertions green at root 19.2 and 20 on all three page shapes
- [ ] **T9 (P2, human: ~20min / CC: ~4min)** — tests — `navigation_test.rb` matrix, scoped to `.masthead__compass` / `.rail`
  - Surfaced by: Codex — "Today" also appears in `days/_walk`, so unscoped assertions prove the wrong element
  - Files: `test/integration/navigation_test.rb`, `test/integration/public_cache_headers_test.rb`
  - Verify: `bin/ci`
- [ ] **T10 (P2, human: ~20min / CC: ~4min)** — docs — `DESIGN.md` rule 5 amendment, Components entries, `decisions/0008`
  - Surfaced by: Design review Pass 5 — the sticky exception and the 44px-per-row cost are undocumented
  - Files: `DESIGN.md`, `decisions/0008-the-compass-and-the-sticky-rail.md`
  - Verify: rule 5 names `/feed` and says navigation-only
- [ ] **T11 (P2, human: ~20min / CC: ~4min)** — cleanup — Delete the coda duplicates and the conditional date link
  - Surfaced by: Approach — the compass makes them duplicates; the daily gallery invitation and `N kept →` stay
  - Files: `days/index`, `favorites/index`, `daily/empty`, `daily/_day`
  - Verify: `days_test.rb`, `favorites_test.rb`, `daily_test.rb` updated to assert the compass
- [ ] **T12 (P3, human: ~10min / CC: ~2min)** — feed — Collapse the duplicate `Painting.count`
  - Surfaced by: Performance review — `paintings_controller.rb:8-9` counts twice per request
  - Files: `app/controllers/paintings_controller.rb`
  - Verify: one `SELECT COUNT` per feed request in the log. Pre-existing; safe to defer.

## Deviations (added during build)

All found by building the thing and measuring it. `bin/ci` green at the end of
each.

- **2026-08-13 — the review's measurements were taken 125px too wide.**
  `ApplicationSystemTestCase` says 375×667 and was running at **500×667**:
  headless Chrome on macOS will not size a window below ~500px and
  `window.resize_to` clamped silently. Every fold assertion in this product had
  been looser than the phone it named, in the direction that hides bugs. Fixed
  with `Emulation.setDeviceMetricsOverride`, which no window minimum applies to.
  This is what turned a passing compass into a wrapping one.
- **2026-08-13 — the plate cap now yields to the text** (user decision, D1 at
  build time). The plan assumed the compass would fit in the front door's
  headroom. Measured, the page had **43px** and the row needs 44 — it failed by
  1px with every scrap of padding already squeezed out. `.plate__img` gained a
  third cap term, `min(55vh, 55dvh, calc(100dvh - 19rem))`, so the picture yields
  height at large text sizes rather than the note going off the bottom.
  `DESIGN.md` rule 2 rewritten to say so: smaller, never cropped.
- **2026-08-13 — `19rem`, not the `17rem` that passed first.** The widened fold
  test caught the real worst case: the seed data holds 18 titles over 60
  characters and one of 104, and 17rem missed the long one by 10px.
- **2026-08-13 — the compass gap is clamped, not `1.4rem`.** A `rem` gap grows
  with Dynamic Type at exactly the moment there is least room, so the row wrapped
  at the accessibility cap. `clamp(0.7rem, 3.5vw, 1rem)`.
- **2026-08-13 — the component is `.compass`, not `.masthead__compass`.** It
  renders in two places (the masthead, and `/feed`'s rail), so naming it after
  one of them was a lie. `.compass` / `.compass--rail` / `.compass__here`.
- **2026-08-13 — `@published_count` is gone entirely**, where the plan said to
  keep it for the ETag. Its whole purpose was expiring a cached front door when
  the date link appeared; the compass links the archive unconditionally, so
  nothing on that page depends on the count any more and keeping it in the key
  would be invalidation with no reader behind it. `days_test.rb`'s backfill test
  now asserts the opposite thing, and says why.
- **2026-08-13 — the masthead kept a `<time>`**, via a new `aside_datetime:`
  local rather than the deleted `aside_html:`. Dropping to a plain string would
  have lost `<time datetime>`, which four integration tests assert and which is
  the correct markup for a date.
- **2026-08-13 — `here:` is read with `local_assigns.fetch(:here)`**, no default.
  A forgotten local would otherwise render as "nothing is marked", which is the
  same silent failure the helper raises about.
- **2026-08-13 — `bundle update brakeman` (8.0.5 → 8.0.6).** Unrelated to this
  story: `bin/ci` runs brakeman with `--exit-on-error` and it exits 5 on any
  version that is not the newest. Verified pre-existing by stashing this story's
  work and re-running. Named here rather than folded in quietly.

## GSTACK REVIEW REPORT

| Review | Trigger | Why | Runs | Status | Findings |
|--------|---------|-----|------|--------|----------|
| CEO Review | `/plan-ceo-review` | Scope & strategy | 0 | — | — |
| Codex Review | `/codex review` | Independent 2nd opinion | 1 | issues_found (2026-08-13) | 9 findings on this plan, 4 novel |
| Eng Review | `/plan-eng-review` | Architecture & tests (required) | 1 | CLEAR (PLAN, 2026-08-13) | 12 issues, 0 critical gaps |
| Design Review | `/plan-design-review` | UI/UX gaps | 1 | CLEAR (FULL, 2026-08-13) | score: 6/10 → 9/10, 4 decisions |
| DX Review | `/plan-devex-review` | Developer experience gaps | 0 | — | — |

- **CODEX:** ran on this plan at high reasoning effort. Nine findings, four of which the
  Claude review missed and all four verified against source: `/feed` would emit two
  `Sections` landmarks; the wide-screen grid drops `.masthead__aside` into implicit
  placement; `days_test.rb:9` navigates through the date link this plan deletes; and the
  `z-index` numbers in the draft were invented (`.sentinel` has none — the 3 belongs to
  `body::after`). All folded in.
- **CROSS-MODEL:** one tension, resolved by the user (D6). The design review deleted the
  daily coda's "Wander the full gallery →" as a duplicate; Codex argued the coda is the
  ritual's closing beat, not a menu. Kept, on the same reasoning that kept the `N kept →`
  count: an invitation is not an exit sign. Both models agreed independently on the sticky
  mechanism (no CSS stuck-state selector) and on the `design_test.rb` misreference.
- **VERDICT:** DESIGN + ENG CLEARED at HEAD (`abc74f3`) — ready to implement, after story
  0011 lands. Two CRITICAL regressions are named and must be fixed in the same unit of
  work: `days_test.rb:9` and `favorites_test.rb:89-101`.

NO UNRESOLVED DECISIONS
