# 0020 — Keep where you find it
Date: 2026-08-19
Lane: **Express (same-day, reversible).** One shared partial, two controllers, one CSS term.
Status: Draft — **ready to build. The WIP slot is free.**

Numbered 0020, not 0019: the coverage fill split out of 0018 took 0019 and shipped
(`specs/0019-the-coverage-fill`, deployed 2026-08-19). This spec was drafted while that
was still in flight and was renumbered on commit.

Promoted from `IDEAS.md` Inbox (captured 2026-08-18, source `/plan-design-review` D7 on
0018). Triaged and corrected on promotion — see "What the Inbox entry got wrong".

## Who

- **Jordan** — persona 2, Collector / Wishlist-keeper, the loudest pain in the review
  corpus (`specs/personas.md:33`). *"Half the reason I used it was to have a catalogue of
  great art."* For Jordan the kept collection **is** the product. Story 0014 put the keep
  control above the fold on `/`; this story is the same argument applied to the two
  screens 0014 never touched.
- **Tomás** — persona 4, Reference Browser (`specs/personas.md:70`). The reader 0018 built
  `/artists/:slug` for. He arrives at that page by exactly the motion this story serves:
  he just discovered an artist and wants what Tondo holds by that hand. Landing on 6–9
  works by one artist is the highest keep intent in the product, and it is the one screen
  where keeping is impossible.
- **Maya** — persona 1, CORE. In the app one to three minutes. Not the driver: her route
  is push → `/` → keep, which already works. She is the regression risk — the feed and
  artist page share her stylesheet, and a 44px rail under every plate shrinks pictures on
  a 375×667 screen.
- Not in this story: Amara (no curation change), Priya/Zoe (Phase 3 gate).

## Problem

**Two of the four screens that show whole artworks have no keep control, and one of them
is the screen with the most keep intent in the product.**

`app/views/paintings/_painting.html.erb` renders a plate and a wall label and nothing
else — no `.rail`, no `keep_<id>` frame. Two surfaces render it:

| Surface | Renders `_painting` via | Works on screen | Keep reachable |
|---|---|---|---|
| `/feed` | `paintings/_page.html.erb:2` | 10/page, 110 total, infinite scroll | **no** |
| `/artists/:slug` | `artists/show.html.erb:28` | 1–9 (measured max 9) | **no** |
| `/` | `daily/_day.html.erb:76` | 1 | yes |
| `/days/:date` | `daily/_day.html.erb:76` | 1 | yes |

So the only way to keep a work is to be shown it by the curator. A work the reader
*found* — which is what both missing surfaces are for — cannot be kept from where it was
found. The reader has to leave the page, which on `/feed` means abandoning an infinite
scroll position and every lazily-loaded page below it.

`CLAUDE.md` names two surviving moats: hand-written editorial voice and **habit mechanics
(daily push → open → favorite)**. Favorites is Proven-baseline item 4. It is currently
wired on 2 of 4 work-showing surfaces. This is a **baseline completeness gap**, not a new
feature — no exception argument is owed.

Not introduced by 0018. `/feed` has shipped this way since 0002; 0014 built the rail for
the single-work screens and did not extend it; 0018 inherited the partial as-is and the
gap arrived on a second surface for free.

### What the Inbox entry got wrong

The `IDEAS.md` line claims *"Zoom and Keep are unreachable from them."* **Zoom is
reachable.** `shared/_plate.html.erb:7` wraps every image in
`<button class="plate__zoom" data-action="artwork#open">`, and both surfaces already
render `<main data-controller="artwork">` plus `shared/_zoom`
(`paintings/index.html.erb:21-24`, `artists/show.html.erb:17,39`). Tapping the picture
opens the overlay today. The rail's zoom glyph on `/` is a **second** affordance for the
same action, added because that screen's plate competes with a wall label for attention.

Verified 2026-08-19 by reading the partials, not inferred. The gap is **Keep only**, and
the story is scoped to Keep only — a rail zoom on these two surfaces would ship a
duplicate control and a duplicate tab stop.

## Story

As **Tomás**, I want to keep a work from the artist page or the gallery, so that finding
something and saving it are one motion instead of two screens.

As **Jordan**, I want the collection to be buildable from every screen that shows me a
whole artwork, so that the catalogue is the product everywhere and not only on the one
page the curator chose.

## Intake

- **Problem:** the table above — keep wired on 2 of 4 work-showing surfaces.
- **Evidence:** **Design-review inference, not user observation. Stated plainly.**
  Source is `/plan-design-review` D7 on `specs/0018-the-names-you-know/plan.md`,
  2026-08-18. The gallery runs of 2026-08-15/16 (`user-research/0006`) produced the
  artist-name evidence 0018 was built on; **they produced no keep-from-feed observation**,
  because at that time `/artists/:slug` did not exist and no participant was asked to
  build a collection.

  What carries this story instead is structural, and it is weaker evidence that happens
  to point at a stronger conclusion: **favorites is Proven-baseline item 4 and is
  half-wired.** Jordan's review corpus (~6 reviews, the loudest cluster) is about
  favorites being taken away, not about where the button lives — it argues that the
  feature matters, not that this placement is the fix. Do not overstate it at kill review.
- **Success signal (prediction, falsifiable and time-bound):**
  1. **By Aug 20:** every work rendered by `paintings/_painting.html.erb` carries a
     working keep control on `/feed` and `/artists/:slug`; keeping from either surface
     adds the work to `/collection` without a full-page navigation and **without losing
     feed scroll position or already-loaded pages**; `bin/ci` green. **Falsified if** a
     keep on `/feed` navigates the page, or if the count on `/collection` disagrees with
     what the reader pressed.
  2. **By Aug 20, measured not asserted:** a `/feed` page render issues **no more HTTP
     requests than it does today** — i.e. the keep controls cost zero extra round trips,
     not ten. Held by an integration test asserting the frame arrives with its button
     already in the body (no `src` attribute). **Falsified if** the shipped feed page
     makes one request per work.
  3. **Next gallery run** (protocol: `user-research/0006`): a participant who says they
     want to save a work while browsing the gallery or an artist page can do it without
     being told where the control is. **Falsified if** participants look for keep on
     those screens and cannot find it, or tap the plate expecting keep and get the zoom
     overlay instead.
  4. **Not instrumented, stated plainly.** Session gate 6 (analytics, error tracking) is
     still unmet — nothing counts keeps by originating surface. Signals 1 and 2 are held
     by tests; signal 3 has the gallery run as its only instrument. If analytics lands
     before Aug 31, the real measure is *share of keeps originating off `/`*, and no
     prediction is made about that number because there is no baseline to predict from.
- **In baseline?** Yes — item 4 (favorites / personal collection), plus quality bar 4
  (calm: nothing between the reader and the act). No exception argument needed.
- **R7 note.** Moves **0 of 5** `BET.md` thresholds. App-live-by-Aug-14 has already been
  missed by five days and all five thresholds sit at zero. **The two things that would
  move them are still the daily publish job and APNs push — neither exists** (no
  `solid_queue` in the `Gemfile`, no APNs in `ios/`), and push is one of the two named
  moats. That was put on the record in `specs/0018-the-names-you-know/story.md` and is
  referenced here rather than re-argued: this story does not fix it and does not claim to.
  It is a same-day baseline patch, and if it is not same-day it should be dropped.

## Non-goals

- **A rail zoom glyph on these surfaces.** The plate is already the zoom trigger
  (`shared/_plate.html.erb:7`). A second control for one action, adjacent in tab order,
  is what `daily/_day.html.erb:82-86` already had to write an accessible-name workaround
  for. One control, on the picture.
- **The keep count under every work.** `favorites/_control.html.erb:52` renders
  `"N kept"` beside the mark. Mark only on multi-work surfaces.

  **This non-goal was originally written as self-evident and it is not** — corrected by
  `/plan-design-review` 2026-08-19 (D1). The count is one of two mitigations
  `decisions/0010:98-104` bought the label-less rail with, against measured evidence that
  unlabelled app-specific icons are read correctly 34% of the time. Dropping it is a real
  cost, taken because **literacy is taught once, on the surface every reader opens every
  day** — `/` is the push destination and the only unwalled screen, and the route to the
  identity these walled surfaces require runs through it. The reasoning, the rejected
  middle option, and the falsifiable tripwire live in `plan.md` under D1.
- **Keep on `/days` and `/collection` rows.** Those render `days/_row.html.erb` —
  112px thumbnails inside a whole-row `<a>`. Nesting a form in an anchor is invalid HTML
  (same reason 0018 excluded artist links there), and `/collection` already states its
  unkeep path in its own coda. Not a "multi-work surface" in the sense this story means:
  a row is a pointer to a work, a plate is the work.
- **Changing the `/` architecture.** The front door stays a lazy-free eager frame with
  `src`, because it is `Cache-Control: public` behind Thruster and story 0007's line is
  load-bearing there. This story adds a second rendering mode for the walled surfaces; it
  does not touch the first.
- **A batched keep-state endpoint / Turbo Stream fan-out.** Considered and rejected in the
  plan — it is machinery for a problem that server-side rendering removes entirely.
- **Optimistic client-side toggling.** No Stimulus, no local state. Turbo frame swap is
  the existing contract and it is fast enough.
