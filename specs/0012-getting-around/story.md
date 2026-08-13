# 0012 — Getting around
Date: 2026-08-13
Lane: Full (core, target ≤ 1 day)
Status: Draft

## Who
**Maya** — Daily Ritual Learner, persona 1, the CORE persona (`specs/personas.md`). 33,
pediatric nurse in Columbus, three 12-hour shifts a week. Opens the app with her morning
tea for one to three minutes and closes it. She is the reader who taps "Wander the full
gallery →" at the bottom of today's artwork because she has five spare minutes, scrolls
through a dozen works, and then wants to be back where she started.

Secondary: **Jordan**, persona 2, whose collection is the product. Today the collection is
the least reachable screen in the app — one conditional link inside a lazily-loaded frame,
plus one line in the archive's footer.

## Problem
The product has four reader surfaces. The links between them are a one-way funnel, and the
end of the funnel is the one screen with no exit anybody can see.

| Screen | Doors out, as built today |
|---|---|
| `/` — Artwork of the Day | wordmark → `/`; date → `/days`, **only when `published_count > 1`**; `N kept →` → `/collection`, **only inside the lazy keep frame, only when count > 0**; coda → `/feed` |
| `/days` — Past days | wordmark → `/`; coda → `/collection`, `/` |
| `/days/:date` — one archived day | wordmark → `/`; walk → previous · next · today |
| `/collection` — Your collection | wordmark → `/`; coda → `/days`, `/` |
| `/feed` — The full gallery | **the wordmark, and nothing else** |

Four defects fall out of that table.

**D1 — the gallery is where the ritual goes to die.** `/feed` streams 110 works with
infinite scroll. Its only exit is the serif wordmark in the masthead, which reads as a
brand string rather than a control, and the masthead is never sticky (`DESIGN.md` rule 5).
Two flicks in, there is no exit on screen at all. The feed's own coda — which carries a
"Back to the beginning ↑" and no destination — renders only on the **last** page, so a
reader who stops at work 12 never sees even that. The screenshot that opened this story is
that screen: a full-bleed work, a wall label, and no way to today, the archive, or a
collection.

**D2 — `/feed` has no door to `/days` or `/collection` at all.** Not a hidden one. None.

**D3 — the collection is reachable by accident.** From the front door, the only link is
inside the `keep_*` turbo-frame and only once the count is positive. A reader who has kept
nothing — every reader, on their first day — can reach it from exactly one place in the
whole product: one line in the archive's footer.

This class of defect has been shipped and fixed here once already: **ISSUE-001**
(`test/integration/favorites_test.rb:270`) was the empty collection page offering only
"Today →", stranding a first-time reader who arrived from the archive. It was patched one
screen at a time. `/feed` is the same bug on a bigger screen, and patching it one screen at
a time is what produced the table above.

**D4 — the archive's door from the front page is conditional and unlabelled.** It is the
date, and only when more than one day has been published. Nothing on that page says the
word "archive" or "days".

### The written prediction this stands against
`decisions/0006-shell-shows-no-native-chrome.md` hid the native navigation bar and paid for
the missing back button three ways: `masthead__brand → root_path` on every screen, the
`days/_walk` prev · next · today, and a rescued swipe-back gesture. Its falsifiers include
*"any screen has to be reached by a route that has no in-page way back."*

This is the near-miss version of that: `/feed` **has** a way back, and it is invisible from
the second screenful onward. The decision is not falsified — no reader from BET.md's five
conversations has raised it, because there have been no conversations. It was found by
dogfooding the built app on 2026-08-13. The remedy belongs in the web page, not in native
chrome; decisions/0006 stands and this story does not reopen it.

## Story
As Maya, I want every screen to show me the way to today's artwork, the days behind me, my
collection, and the full gallery, so that I can wander without losing the ritual I came for.

## Intake
- **Evidence:** dogfood of the built app, 2026-08-13 (screenshot of `/feed`), plus the
  table above, which is the code as it stands. Persona 1 spends one to three minutes in
  this app; a reader who has to hunt for the way home is finished for the day. `CLAUDE.md`
  Better bucket item 4 — *calm, nothing between push and art* — is the same requirement
  read from the other end: a lost reader is not a calm one. Baseline items 1, 3 and 4 are
  all built and one of them (the gallery, story 0002) strands you inside it.
- **Success signal (prediction), hand-checkable on ship day, no analytics required:**
  1. From each of `/`, `/days`, `/days/:date`, `/collection`, `/feed`, the **other three**
     reader surfaces are each reachable in one tap.
  2. On `/feed`, scrolled to roughly the sixtieth work, a link to today's artwork is
     **visible on screen without scrolling up**. This is the specific defect in the
     screenshot and the one a matrix test cannot prove.
  3. `curl -sI /` and `curl -sI /days` return the same `public, no-cache` + ETag and **no
     `Set-Cookie`** as before the change. Navigation adds no per-visitor state to a cached
     page (story 0007's line holds).
  4. The daily page still opens on the artwork. Nothing new sits between the top of the
     screen and the plate on a phone.
- **In baseline?** No new feature and no new surface. This is a **defect in the
  reachability of baseline items 1, 3 and 4**. It spends no "New" slot and is not the
  differentiator, which stays deferred to the Phase 3 gate (`BET.md`).
- **R7, stated plainly:** this is not one of BET.md's five thresholds. The App Store submit
  target is **tomorrow, Aug 14**, nothing is deployed, and the scoreboard is 0 live / 0
  posts / 0 keywords / 0 conversations / 0 installs. Shipping this is an input metric and
  must not be argued as progress.

## Acceptance
- Every reader screen — `/`, `/days`, `/days/:date`, `/collection`, `/feed`, and the
  no-artwork-yet empty state — offers a one-tap route to each of the other three surfaces.
  A screen never links to itself.
- The route to each surface sits in **the same place on every screen**, so it is learned
  once. A reader who found "Past days" on the daily page finds it in the same spot in the
  gallery.
- **On `/feed`, that route stays on screen while the stream scrolls.** Reaching it never
  requires scrolling back to the top or forward to the end of 110 works.
- Nothing hovers over an artwork on the screens whose job is one artwork (`/`,
  `/days/:date`). `DESIGN.md` rule 5 keeps its teeth there; any narrowing of it is written
  into `DESIGN.md` and into `decisions/` with its reason (R4).
- **`test/system/dynamic_type_test.rb` stays green.** The note's first line clears the fold
  at root 20px — story 0008's forcing function for "art and text visible together." Design
  review measured a first-draft shape that broke it by 35px; the bar is not negotiable and
  the navigation is what gives way. See `plan.md` for the numbers.
- The doors are **unconditional and countless**: no `published_count > 1`, no `count > 0`,
  no per-visitor number anywhere on a publicly cached page. `/`, `/days` and `/days/:date`
  stay byte-identical for every visitor and emit no `Set-Cookie`.
- Every navigation link is a real link with a ≥44px touch target (`DESIGN.md` rule 9) and a
  visible focus ring, and reads as a control rather than as decoration — the wordmark
  failing this test is what the story is about.
- No new ornament, no new colour, no second link style. `.caps-link` and `✦` are what
  exists (`DESIGN.md` rules 1 and 6).
- The masthead does not gain a per-visitor count, and the daily page does not gain a
  numbered badge of any kind.
- The three ad-hoc footer links that this replaces (`Your collection →`, `The days behind
  you →`, `Today →`, `Wander the full gallery →`) are **removed where the new route
  duplicates them** — this story must delete more markup than it adds in the codas.
- The existing `days/_walk` prev · next · today stays. Moving between adjacent days is
  motion *inside* a surface, not between surfaces, and it is the one thing decisions/0006
  named as paying for the missing back button on archive pages.
- `bin/ci` green, including a test that fails if any reader screen loses a door (R1 — the
  rule and its enforcement land in the same unit of work).

## Out of scope
- **A native tab bar or navigation bar in the iOS shell.** `decisions/0006` is not
  reopened: the shell subtracts chrome, the web page owns the screen. A native tab bar
  would also mean a fifth thing to keep in sync with the path configuration before an App
  Store deadline that is tomorrow.
- **Search, an artist directory, browse-by-artist or browse-by-era.** That is Tomás,
  persona 4, explicitly *not baseline* and a candidate for the one "New" slot at the Phase
  3 gate. A navigation fix is not the door through which that arrives.
- **A fifth surface.** No "about", no settings, no help screen.
- **Renaming or reordering the four surfaces**, and no change to what any of them shows.
- **A kept count in the masthead.** Per-visitor state in a publicly cached header — ruled
  out in story 0006 for the same reason it is still ruled out here.
- **A keep control on `/feed`.** Story 0006's call, unchanged, and it reopens at the Phase
  3 gate or on a real user's request, not on the back of a navigation change.
- **Breadcrumbs, a history stack, or any "back" that is not one of the four destinations.**
  Swipe-back and the browser's own back button already exist.
- **Analytics on which door gets used.** Session gate 6 is unmet product-wide; wiring it
  for this story would be scaffolding ahead of the thing that actually needs it.
