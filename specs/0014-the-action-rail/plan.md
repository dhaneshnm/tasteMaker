# 0014 — Implementation plan
Status: **Eng-reviewed** (`/plan-eng-review` 2026-08-14 — 7 decisions, Codex outside voice
absorbed, 2 cross-model tensions found, 1 unbuildable test caught). Ready to implement.

**Design review: skipped, deliberately.** This story has significant UI, so the skip is
recorded rather than assumed. The design work was done up front and is settled in writing —
measured mocks in Tondo's own CSS and faces, four options priced and rejected, and three
open choices closed by the user on 2026-08-14 (no labels / filled kept state / accept the
48pt). `decisions/0010-actions-become-a-rail.md` carries the result and `DESIGN.md` is
already amended. Re-running `/plan-design-review` would re-open questions that have an
owner's answer.

## Approach

Move the actions out of the wall label into a flex row directly under the plate.

```
main.page[data-controller="artwork"]
  figure.plate                    ← unchanged, still tappable
  div.rail                        ← NEW, inline in _day.html.erb
    button.rail__act              ← Zoom.  PUBLIC. First, so nothing shifts it.
                                    Rendered only when painting.display_image?
    turbo-frame#keep_N.rail__slot ← lazy, src=/collection/:id/control
      form.rail__form             ← DEFAULT CONTENT, public, byte-identical:
        button.rail__act            the outline glyph, no count
                                  ← response swaps in filled state + count
  div.label                       ← .keep-frame at its foot is DELETED
    …
    footer.coda                   ← unchanged, still the single ending
```

**Why Zoom is first.** Keep and its count share one Turbo frame, and a frame is one
contiguous flex item. When the count arrives the frame grows, so anything to its right is
pushed right — about 60pt, on every open, for exactly the returning reader this story is
for. Putting the growing item last removes the shift by construction instead of reserving a
width nobody can predict. (D8. The alternative was spreading the row, which `DESIGN.md`
already refuses at the 680px measure.)

**Why the frame ships default content.** The un-kept outline glyph is identical for every
visitor, so it is not personal data and belongs in the cached page. Only the filled state
and the count need the private fragment. Without this the rail paints an empty 44px box
where the habit mechanic should be, for as long as the fetch takes — which is the original
bug wearing a different costume, now in the exact spot the reader is looking. (D7, found by
the outside voice. The review measured position and never measured time.)

`turbo_frame_tag` with a block renders those children until `src` resolves, so this is one
partial rendered in two places, not a duplicated glyph.

Four things make this more than moving a partial. Each has a defect behind it.

### 1. Rule 9 needs a second axis, and the placeholder needs it too

Rule 9 states `min-height: 44px` and nothing about width, because every control it names is
a `.caps-link` — words make those wide for free. A bare glyph has no words: left as written
the target is **23px across and 44px tall**. This is the shape of the assumption that
shipped 15px targets in ISSUE-002 (`866bbc2`).

`.rail__act` and `.rail__count` **join the existing rule-9 selector list** for the height
rather than restating it — one registry for the 44px bar, so a future change to it cannot
half-land. Only the genuinely new fact, `min-width: 44px` for wordless controls, gets its
own small block. (D4.)

`.rail__count` is in that list because it is a link into the collection and rule 9 applies
to it too — the old test measured `.keep__link`'s height at `favorites_test.rb:75` and the
first draft of this plan dropped that coverage. (Outside voice.)

**`button_to` generates a `<form>` wrapper**, so the form is the flex item, not the button.
`.rail__form { display: contents }` makes the button the real flex child; without it every
geometry assertion measures the form and the 44×44 test passes while the button is 23 wide.
(Outside voice. The first draft also deleted `.keep__form` while still referencing it — it
becomes `.rail__form`.)

### 2. Zoom's trigger no longer contains the image

`artwork_controller.js#open` resolves the artwork with
`trigger.querySelector(".plate__img")` — it assumes the trigger *wraps* the image, true of
`.plate__zoom` and false of a rail button.

```js
static targets = ["image", "overlay", "close", "railZoom"]

plateFor(trigger) {
  // .plate__zoom wraps its image; the rail's button does not. The fallback is
  // safe because the rail only renders on the screens with exactly one artwork.
  return trigger.querySelector(".plate__img") ?? this.element.querySelector(".plate__img")
}
```

`/feed` has ten plates in one controller scope and no rail, so the first branch always wins
there.

### 3. A resting plate must not leave a live Zoom — in either direction

Two separate failures, and the first draft only had one of them:

- **Runtime**: the museum CDN 404s, `rest()` hides `.plate__zoom`. The rail's Zoom would
  survive it. `rest()` gains one line — **guarded with `hasRailZoomTarget`**, because
  `rest()` also runs for feed images and a bare `this.railZoomTarget` throws there.
  (Outside voice.)
- **Server-side**: `_plate.html.erb:6` wraps its zoom button in
  `<% if painting.display_image? %>`, and `painting.rb:30` defines that as
  `image.attached? || image_url_800.present?`. A work failing it renders the resting note
  and **no `<img>` at all**, so `rest()` can never fire — it is triggered by an `error`
  event on an element that does not exist. The rail's Zoom takes the same guard. Keep stays
  visible: a resting work is still a work you can keep. (D3.)

### 4. The reserve change must not tax `/feed`

Rule 2's third cap term is on `.plate__img`, which `/feed` uses too. Bumping
`19rem → 22rem` globally would shrink feed images on a 375×667 screen to pay for a rail
that screen does not render. Scoped with `:has()`, the idiom `.masthead:has(.compass)`
already uses — [Layer 1], a platform built-in over a JS modifier class:

```css
.page:has(.rail) .plate__img { max-height: min(55vh, 55dvh, calc(100dvh - 22rem)); }
.plate:has(+ .rail)          { margin-bottom: 0.5rem; }
```

### What the numbers say

Measured in the real stylesheet with the real faces, every `clamp()` and `vh` resolved per
device at a 16px root. The plate is a hanging scroll, 1074 × 1600 (`Birds and
Chrysanthemums in Snow`, Geiai 芸愛, MIA) — tall enough to be height-capped, the only case
where the third term can bite.

| Device | 55vh | `100dvh − 19rem` | `100dvh − 22rem` | Plate today | With rail | Δ |
|---|---|---|---|---|---|---|
| 402 × 874 | 481 | 570 | 522 | **481** | **481** | **±0** |
| 375 × 667 | 367 | 363 | 315 | **363** | **315** | **−48 (−13%)** |

`min()` picks the smallest. At 402×874 that is 55vh in both columns, so the rail is free
there — it would take a reserve over 24.6rem before the third term bites at all. At 375×667
the term already wins at 19rem (by 4px, as the stylesheet's own comment says) and 22rem
makes it win by 52. The −48pt is the accepted cost, settled 2026-08-14.

Landscape works are width-constrained on both devices and never reach either cap.

### What the rail costs above the note

Plate margin 19.2 → 8, rail 44, rail margin-bottom 12. Net **+44.8px** against a 3rem (48px)
reserve increase. The 3.2px of slack is deliberate: the reserve is the number a test
asserts and should not be tighter than the layout it describes.

## Steps

1. **`app/views/favorites/_keep_button.html.erb`** (new — the one genuine two-caller
   partial). Locals: `painting`, `kept:`, `autofocus:`. The `button_to` with its glyph
   inline. Rendered by the frame's default content *and* by the frame's response, which is
   what makes the server-side outline possible without duplicating the SVG.
2. **`app/views/daily/_day.html.erb`** — the rail, inline, between plate and `.label`.
   Zoom button + inline SVG, gated on `painting.display_image?`. The `turbo_frame_tag` with
   a block whose default content is `render "favorites/keep_button", kept: false,
   autofocus: false`. Delete the `.keep-frame` block at the foot of the label. Update the
   partial's chrome matrix comment — the `keep control` column now describes the rail; the
   `:preview` row keeps its `NO`.
3. **`app/views/favorites/_control.html.erb`** — renders `_keep_button` with the real
   `kept:`/`autofocus:`, plus the count when positive (`"#{count} kept"`, no arrow, still
   `turbo_frame: "_top"`). **Replace the header comment** — it currently argues for the
   no-glyph decision that `decisions/0010` reversed, and a comment contradicting its own
   code is worse than none.
4. **`app/views/favorites/index.html.erb:11`** — reword. `"Keep this sits under every
   artwork."` names a label that will not exist. Words only, no glyph on this screen. (D5.)
5. **`app/javascript/controllers/artwork_controller.js`** — `railZoom` target, `plateFor`
   helper, use it in `open`, and hide `railZoomTarget` in `rest` **behind
   `hasRailZoomTarget`**.
6. **`app/assets/stylesheets/application.css`** — `.rail`, `.rail__slot`, `.rail__act`,
   `.rail__count`, `.rail__form`; add `.rail__act`/`.rail__count` to the rule-9 list and
   update that block's comment (it currently says "two homes, on purpose"); the two
   `:has()` rules; delete `.keep-frame`, `.keep`, `.keep__form`, and `.keep__toggle` /
   `.keep__link` from the rule-9 list and the bare-button block. **Leave `.days__remove` in
   both** — it is not part of this story.
7. **`DESIGN.md`** — the `.rail` component note currently reads "Keep, the count beside it,
   and Zoom." D8 reorders it to Zoom, Keep, count, and the reason (the growing frame goes
   last) belongs in the note.
8. **Tests, written alongside each step** (R1).
9. `bin/ci`, then `/qa`.

Five source files, one new partial, plus tests.

## Tests

### CRITICAL — regressions (iron rule, non-negotiable)

**R1 — `test/system/favorites_test.rb` is a rewrite, not an assertion edit.** Its header
comment (`:3-5`) and `reveal_keep_control` (`:160-163`) both exist *because* the control is
below the fold. This story deletes that premise, so the helper and the comment are the
change, not collateral. Also breaking: `assert_button "Keep this"` (`:11, :22, :52, :146,
:156` — Capybara matches text/value/title/aria-label, and the new label is
`"Keep {title} in your collection"`), `assert_button "Kept · Remove"` (`:15, :24, :157`),
`assert_link "1 kept →"` (`:16`), and `.keep__toggle` / `.keep__link` / `.keep`
(`:34, :37, :53, :74, :75, :78-79`).

**R2 — `test/integration/favorites_test.rb:135, 140, 306`** assert button text and
`a.keep__link` that no longer exist.

**R3 — `test/integration/favorites_test.rb:266`** asserts the empty-collection copy changed
in step 4.

**R4 — `/feed` must not lose plate height.** New guard: with the `:has()` scoping in place,
a feed plate still computes against 19rem. Without this test the scoping can regress
silently and nobody would look.

### `test/system/dynamic_type_test.rb` — the forcing function this story owes

- Extend the `fold` helper with a `keep` reader returning the rail button's rect.
- **The keep control is fully on screen at open** — `rect.bottom <= innerHeight` — at all
  three root sizes the file defines (16 / 19.2 / 20), on `/` **and on `/days/:date`**.
  Same partial is not the same test; the archive route renders different chrome.
- Same assertions at **402 × 874**. `ApplicationSystemTestCase` pins every test to 375×667
  through `Emulation.setDeviceMetricsOverride`; this file gets a helper to re-issue that
  CDP call, so the class default stays the small phone and only this file opts in.
- Both content modes: the existing fixtures cover a museum-copy day; add a **hand-written
  fixture at the 180-word ceiling**, the taller page and the one that matters.

**A real landscape fixture, with landscape pixels.** `test/fixtures/paintings.yml:9-12` gives
every painting the same inline **800 × 1000** PNG via `<<: *DEFAULTS`. Setting
`image_width: 1000` on a "landscape" fixture changes nothing — the file's own comment
(`:4-8`) records that `width`/`height` only set an aspect ratio and do not override the
intrinsic size, which is how the suite once measured a layout with no artwork in it. A
landscape case needs a **second data URI with landscape pixels**, or the test passes while
measuring a portrait image. (Outside voice, confirmed.)

### `test/system/favorites_test.rb` (rewritten)

- Keep and un-keep through the rail: glyph fills, count appears, `aria-pressed` flips.
- **No horizontal shift**: Zoom's `getBoundingClientRect().left` is identical before and
  after the frame resolves, **for a reader with a positive count** — that is the case D8
  exists for, and a zero-count reader would pass vacuously.
- **The outline glyph is painted before the frame resolves** — the D7 assertion. Block or
  delay the control request, assert the glyph is in the DOM and the button is present.
- Every `.rail__act` **and `.rail__count`** measures ≥ 44 × 44 **rendered, both axes**, read
  from the box. With `.rail__form { display: contents }` in place this measures the button;
  without it, it measures the form — so this test is also the forcing function for that
  rule.
- The rail does not wrap: `offsetHeight` stays one row at 375px at root 20px.
- Keyboard: Enter on keep returns focus to the toggle (the existing `:32-37` behaviour,
  re-expressed against the new selectors).

### `test/system/feed_zoom_test.rb` / `daily_test.rb`

- Zoom opens from the rail button and from the plate; both return focus to the control that
  opened them.
- **Resting plate leaves no live Zoom**, both paths: a work with `display_image? == false`
  renders no rail Zoom server-side, and a work whose image errors at runtime has it hidden
  by `rest()`.
- **`rest()` on `/feed` does not throw** — ten plates, no `railZoom` target,
  `hasRailZoomTarget` false. This is the guard's test.
- `/feed` still zooms from all ten plates.

### `test/integration/favorites_test.rb`

- Every glyph control has a non-empty accessible name containing the painting title.
- The count renders only above zero and carries `data-turbo-frame="_top"`.
- `chrome: :preview` renders a rail with Zoom and **no** keep frame.
- **The cached page contains the outline glyph** — the D7 contract, asserted on the public
  HTML rather than in a browser.

### Unchanged and must stay green

`test/integration/public_cache_headers_test.rb` — `/` and `/days/:date` emit
`public, no-cache` + ETag and no `Set-Cookie`. **D7 makes this load-bearing**: the frame's
default content must be byte-identical for every visitor, which is why it renders
`kept: false` and no count. If this goes red the architecture broke, not the test.

`template_etag_test.rb` / `stylesheet_etag_test.rb` will need digests refreshed — that is
the mechanism working. `application_controller.rb:46` (`etag { config.x.revision }`) already
covers template text per deploy, so the rewritten markup will not ship behind a 304.

## Failure modes

| Codepath | Realistic production failure | Test? | Error handling? | Silent? |
|---|---|---|---|---|
| Rail Zoom on a work with no image | Empty black overlay, reader must find Close | yes (new) | yes — `display_image?` guard | was silent |
| `rest()` on `/feed` | `railZoomTarget` throws, breaks all zoom on the page | yes (new) | yes — `hasRailZoomTarget` | would have been loud |
| Frame slow / fails | Glyph present but not yet interactive | yes (new) | default content is a real button | no |
| Count lands late | Zoom shifts under a thumb | yes (new) | structural — frame is last | was silent |
| `:has()` scoping regresses | Feed images shrink 13% on SE | yes (R4) | none needed | **would be silent** |
| `display: contents` missing | 44×44 test measures the form, passes wrongly | yes | none | **would be silent** |

No critical gaps: every silent failure above now has a test.

## Risks

- **`:has()` support** — iOS 15.4+, and `.masthead:has(.compass)` already ships on it. If a
  lower target ever appears the fallback is a modifier class on `.page`, not a polyfill.
- **The 402×874 assertion is new machinery.** If re-issuing the CDP override mid-test proves
  flaky, the fallback is a second test file with its own class-level viewport rather than a
  helper that mutates one.
- **Icon-only was chosen against the evidence** (34% correct prediction for app-specific
  unlabelled icons). Not re-litigated here. D5 chose words over a glyph on the empty
  collection page, so the only literacy cue in the product is the word `kept` in the count
  and that one sentence. `decisions/0010` carries the falsifier.
- **Privacy label.** The lazy frame now fetches on every open rather than only for readers
  who scrolled, so the visitor identifier reaches everyone who opens the app once. Session
  gate 6 owes an App Store privacy label that says so. (D6.)

## NOT in scope

- **Share, or any placeholder slot for it.** Infrastructure for later, refused in
  `decisions/0010`.
- **A rail on `/feed` or `/collection`.** The rail belongs to the screens whose job is one
  artwork.
- **A glyph on the empty-collection page.** Considered as the icon-literacy mitigation and
  declined at D5 — words only.
- **Deferring the frame fetch to first interaction.** Considered at D6; would ship a control
  that looks tappable before it is, on the screen this story exists to make tappable.
- **Icon labels, or a setting to turn them on.** One shape ships.
- **`flashScrollIndicators()` in the shell.** Measured and rejected in `decisions/0010`.
- **Analytics on keeps.** Session gate 6 is unmet product-wide.
- **Extracting the glyphs to `shared/icons/`.** D2: every partial in `shared/` has ≥2
  callers; these would have one. Extract when a second caller is real.

## What already exists

| Sub-problem | Existing code | This plan |
|---|---|---|
| Per-visitor state on a cached page | `FavoritesController` + `keep_*` frame | **Reuses.** D7 adds default content, does not change the contract |
| The zoom overlay | `shared/_zoom` + `artwork_controller.js` | **Reuses**, adds a second trigger |
| 44px touch bar | rule-9 list, `application.css:670-680` | **Extends** — joins the list, adds a width axis |
| Plate + resting fallback | `shared/_plate`, `Painting#display_image?` | **Reuses the guard** rather than inventing a second one |
| Conditional layout without JS | `.masthead:has(.compass)` | **Reuses** the `:has()` idiom |
| Template-text cache busting | `application_controller.rb:46` | **Already solved** — no work owed |

Nothing is rebuilt.

## Parallelization

Sequential implementation, no parallelization opportunity. Every step lands in
`app/views/` + `app/assets/` and the tests depend on all of them.

## Implementation Tasks

- [ ] **T1 (P1, human: ~1h / CC: ~10min)** — views — Rail markup inline in `_day.html.erb`,
      Zoom first, gated on `display_image?`
  - Surfaced by: D2 (inline, not partials), D3 (resting guard), D8 (order)
  - Files: `app/views/daily/_day.html.erb`
  - Verify: `bin/rails test test/integration/favorites_test.rb`
- [ ] **T2 (P1, human: ~1h / CC: ~10min)** — views — `_keep_button` partial + frame default
      content so the outline paints server-side
  - Surfaced by: D7 — outside voice, "visible at open" vs "fetched after open"
  - Files: `app/views/favorites/_keep_button.html.erb`, `_control.html.erb`,
    `app/views/daily/_day.html.erb`
  - Verify: `bin/rails test test/integration/public_cache_headers_test.rb`
- [ ] **T3 (P1, human: ~30min / CC: ~5min)** — js — `railZoom` target, `plateFor`, guarded
      `rest()`
  - Surfaced by: Architecture §2/§3 + outside voice (`hasRailZoomTarget`)
  - Files: `app/javascript/controllers/artwork_controller.js`
  - Verify: `bin/rails test test/system/feed_zoom_test.rb`
- [ ] **T4 (P1, human: ~1h / CC: ~10min)** — css — `.rail*`, rule-9 list join,
      `display: contents`, two `:has()` rules
  - Surfaced by: D4 + outside voice (`button_to` form wrapper)
  - Files: `app/assets/stylesheets/application.css`
  - Verify: `bin/rails test test/system/favorites_test.rb`
- [ ] **T5 (P1, human: ~2h / CC: ~20min)** — tests — Rewrite `system/favorites_test.rb`
      against the new premise
  - Surfaced by: R1 — the file's helper and header comment encode the deleted premise
  - Files: `test/system/favorites_test.rb`
  - Verify: `bin/rails test test/system/favorites_test.rb`
- [ ] **T6 (P1, human: ~2h / CC: ~20min)** — tests — Fold-budget assertions: both viewports,
      both routes, three text sizes, hand-written fixture
  - Surfaced by: Test review — the story's entire success signal
  - Files: `test/system/dynamic_type_test.rb`, `test/fixtures/paintings.yml`,
    `test/fixtures/daily_picks.yml`
  - Verify: `bin/rails test test/system/dynamic_type_test.rb`
- [ ] **T7 (P1, human: ~45min / CC: ~8min)** — tests — Landscape fixture with real landscape
      pixels
  - Surfaced by: Outside voice — `paintings.yml:4-8` records this exact past failure
  - Files: `test/fixtures/paintings.yml`
  - Verify: assert `naturalWidth > naturalHeight` in the test that uses it
- [ ] **T8 (P2, human: ~20min / CC: ~3min)** — views — Reword
      `favorites/index.html.erb:11` + its test
  - Surfaced by: D5 / R3 — copy names a deleted label
  - Files: `app/views/favorites/index.html.erb`, `test/integration/favorites_test.rb`
  - Verify: `bin/rails test test/integration/favorites_test.rb`
- [ ] **T9 (P2, human: ~20min / CC: ~3min)** — docs — `DESIGN.md` `.rail` note: reorder to
      Zoom/Keep/count, add the reason
  - Surfaced by: D8
  - Files: `DESIGN.md`
  - Verify: read-through
- [ ] **T10 (P2, human: ~15min / CC: ~2min)** — tests — `/feed` plate-height regression guard
  - Surfaced by: R4 — `:has()` scoping can regress silently
  - Files: `test/system/feed_test.rb`
  - Verify: `bin/rails test test/system/feed_test.rb`

## Deviations (added during build)

- **2026-08-14 — D7's default content cannot be the real button.** The plan had the
  lazy frame render `_keep_button` with `kept: false` in the cached page. `button_to`
  emits a CSRF token, generating one **starts a session**, and the session put a
  `Set-Cookie` on `/` — breaking story 0007's contract, caught immediately by
  `test/integration/favorites_test.rb:17`. D7's brief claimed a tap before the frame
  landed would still post; that was wrong for the same reason. The cached page now
  carries a `<span class="rail__act--waiting" aria-hidden="true">` holding the same
  glyph at the same size, and the private frame brings the machinery. **The mark is
  painted at first paint, which was the point; the control arrives a moment later,
  which was never avoidable.** The glyph moved into `favorites/_keep_glyph.html.erb`
  — a partial with two real callers, so it satisfies D2's rule rather than bending it.

- **2026-08-14 — the reserve is `19rem + 44px`, not `22rem`.** A units error, and
  `dynamic_type_test.rb` rejected it before a browser ever showed it: at the
  accessibility cap the plate gave up **28%** of its height against the 25% that file
  bounds it to (227px vs a 236px floor). `19rem` is the label's **text** budget and
  belongs in `rem` because it scales with Dynamic Type. The rail does not — its height
  is the 44px touch target rule 9 fixes in **pixels**, identical at every text size.
  Charging a fixed cost in `rem` billed the picture ~60px it never spent. The measured
  trade improved as a result: **−44px at 375×667, still ±0 at 402×874.**

- **2026-08-14 — `Capybara.enable_aria_label = true`, suite-wide.** It defaults to
  false, so `assert_button` cannot see a control whose only name is an `aria-label`.
  With icon-only controls that is every one of them. Reaching them by CSS class
  instead would have passed just as happily against a button with **no** accessible
  name, which is the regression most worth catching — now a control a test can find is
  a control a screen reader can find.

- **2026-08-14 — the landscape fixture needed an explicit `feed_order`.** Fixture ids
  are hashed rather than sequential, so `wide_harbour` with a nil `feed_order` sorted
  to the **top** of `/feed` and pushed an existing work below the scroll-in reveal,
  where Selenium stops calling it visible. Two gallery tests that never mention this
  fixture went red. `feed_order: 9000` sorts it last.

- **2026-08-14 — three integration counts derived instead of hardcoded.**
  `article.post` was `count: 5` in two files and `button.plate__zoom` was `count: 4`;
  adding one fixture broke all three. They now read `Painting.count` and
  `Painting.all.count(&:display_image?)`, which is what those tests always meant.

- **2026-08-14 — naming, noted not fixed.** `.rail` (the actions) now shares a word
  with `.compass--rail` (the gallery's sticky nav, story 0012). No selector collision —
  they are distinct classes — but the codebase vocabulary has two rails in it, and
  `feed_test.rb` says "the rail" meaning the other one. Left alone because `DESIGN.md`
  and `decisions/0010` are both already written against `.rail`; worth renaming only if
  it actually trips someone.

## GSTACK REVIEW REPORT

| Review | Trigger | Why | Runs | Status | Findings |
|--------|---------|-----|------|--------|----------|
| CEO Review | `/plan-ceo-review` | Scope & strategy | 0 | — | — |
| Codex Review | `/codex review` | Independent 2nd opinion | 0 | — | — |
| Eng Review | `/plan-eng-review` | Architecture & tests (required) | 3 | CLEAR | 11 issues, 0 critical gaps |
| Design Review | `/plan-design-review` | UI/UX gaps | 2 | CLEAR (story 0012, 6 commits stale) | score 6/10 → 9/10, 4 decisions |
| DX Review | `/plan-devex-review` | Developer experience gaps | 0 | — | — |

**CODEX:** 8 problems raised, 5 real and folded, 1 moot (D2 had already deleted the partials
it warned about), 1 confirmed against `paintings.yml:4-8` as an unbuildable test. Two became
cross-model tensions the review had missed entirely: the frame's latency (D7) and the count
shoving Zoom (D8).

**CROSS-MODEL:** The review measured *position* and never measured *time* — it proved the
keep control would be above the fold and never asked whether it would be there yet. Codex
caught it, and the fix (server-side default content in the frame) also dissolved the width
half of the shift problem. Overlap between the two reviewers was near zero; they failed in
different directions, which is the argument for running both.

**VERDICT:** ENG CLEARED — ready to implement. Design review skipped by decision, recorded
above with its reason.

NO UNRESOLVED DECISIONS
