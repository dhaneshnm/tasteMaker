# 0002 — Implementation plan
Status: Building

/ plan-design-review skipped: no new visual idiom. The overlay, the Close button, the
dark surround and the tap targets already exist and are specified in `DESIGN.md`
("Full-screen view"); this story adds no pixel that is not already reviewed.
/ plan-eng-review skipped at the user's direction (story → plan → implement in one pass).
The risks that review would have caught are named under "Risks" below and each has a test.

## Approach

The daily page's overlay is markup that sits inside `<main data-controller="artwork">` and
holds one `<img>` with the artwork's src baked in at render time. Copying that into the
archive would put one hidden full-size `<img src>` next to every one of 110 works — the
browser fetches those, so the archive would download the whole collection twice.

So the overlay becomes a **page-level singleton** whose `src` is set when a work is
tapped, and the `artwork` controller becomes a **page-level** controller instead of a
per-artwork one:

- `app/views/shared/_zoom.html.erb` — the overlay, rendered once per page. Empty `<img>`;
  `src`, `alt` and the dialog's `aria-label` are filled in on open.
- `artwork_controller.js` — `open(event)` reads the tapped trigger, lifts `currentSrc`,
  `alt` and `data-artwork-title` off it, fills the overlay, and remembers the trigger so
  focus can go back to it on close. `imageFailed(event)` stops using targets and scopes
  itself to `event.target.closest(".plate")`, so it works for one artwork or a hundred.
- `paintings/_painting.html.erb` — the image is wrapped in the same `button.plate__zoom`
  the daily page uses, and gains the `.plate__resting` fallback it never had. Without the
  fallback, a work whose image 404s becomes an empty button that opens an empty overlay —
  a defect this story would otherwise introduce.
- `paintings/index.html.erb` — `data-controller="artwork"` on `<main class="page">`, which
  is also what the lazy Turbo frames append into, so works loaded by infinite scroll are
  inside the controller and their `data-action` binds with no extra wiring.
- `daily/show.html.erb` — renders the shared partial instead of its own overlay markup.

Nothing else moves: no model, no route, no controller action, no new CSS. `.plate__zoom`,
`.plate__resting` and `.zoom*` are already in `application.css`.

## Steps

1. Extract `shared/_zoom.html.erb`; render it from `daily/show` in place of the inline
   overlay. Suite stays green — this step changes no behaviour.
2. Rewrite `artwork_controller.js` for many triggers and one overlay; drop the `trigger`
   and `placeholder` targets in favour of `closest(".plate")` lookups; keep the modal
   behaviour (focus to Close, Tab trapped, Escape closes, scroll locked, focus restored).
3. Wrap the archive's image in `button.plate__zoom`, add `.plate__resting`, add
   `data-artwork-title` for the dialog label.
4. Put `data-controller="artwork"` on the archive's `<main>` and render the overlay there.
5. Tests below, written alongside each step.
6. `bin/ci` green, then dogfood both screens in the browser at 1280 and 375.

## Tests

Integration (`test/integration/daily_test.rb`):
- every archive post renders `button.plate__zoom` with an accessible name naming the work;
- the archive renders exactly one `.zoom[role=dialog][aria-modal=true]`, and its `<img>`
  ships with no `src` (the proof that hidden full-size images are not being fetched);
- the daily page's existing zoom assertions keep passing unchanged.

System (`test/system/feed_zoom_test.rb`, new):
- tapping the second work opens the overlay showing *that* work's image, not the first;
- Escape closes it and focus returns to the work that was tapped;
- tapping a different work afterwards swaps the overlay's image;
- a work whose image errors hides its trigger and shows the resting note (the defect
  guard from step 3).

System (`test/system/daily_test.rb`): unchanged, and must stay green — it is the parity
check that the daily page did not regress.

## Risks

- **Turbo-appended works are dead.** The lazy frames append after `connect()`. Mitigated
  by declarative `data-action` (Stimulus binds new elements itself) and covered by the
  second-page click in the system test.
- **Stale overlay on Turbo restore.** The overlay keeps the last `src` in the page cache.
  It is `hidden` and `open` overwrites `src` before showing, so the stale value is never
  visible; `disconnect()` already releases `zoom-open` and the keydown listener.
- **Focus restore across pages.** The remembered trigger is a plain reference; if the
  frame it lives in is replaced while the overlay is open, focus falls back to the body.
  Acceptable — the overlay closes with the page.

## Deviations (added during build)
- 2026-08-03: **the plate itself became a shared partial** (`shared/_plate.html.erb`),
  not just the overlay. The plan had the archive growing its own copy of the daily page's
  button markup; two copies of a component the design system says is one component would
  drift by the second change. Locals: `eager:`, `describedby:`, `resting:` (the archive
  has no "today's note" to point at, so the resting line is shorter there).
- 2026-08-03: **system tests scroll before they tap.** Posts below the fold sit at
  `opacity: 0` until the reveal observer fires, and the driver reports those as not
  visible, so `find(...).click` failed on any work that was not already on screen. The
  helper scrolls the work to the middle of the viewport first, which is also what a
  reader does. Fixture order is id-derived, so tests address works by `#painting_<mia_id>`
  rather than by position.
- 2026-08-03: the daily page's dialog label moved from render time to open time
  (`"<title>, full screen"`, set from `data-artwork-title`). Same string, one source.
