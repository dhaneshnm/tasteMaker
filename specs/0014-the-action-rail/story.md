# 0014 — The action rail
Date: 2026-08-14
Lane: Full (core, target ≤ 1 day)
Status: Draft

## Who
**Jordan** — Collector / Wishlist-keeper, persona 2, the loudest pain in the review corpus
(`specs/personas.md`). 26, barista and part-time student in Portland, three years of slow
curating on a cracked-screen iPhone. *"Half the reason I used it was to have a catalogue of
great art."* For Jordan the favorites list **is** the product.

Secondary: **Maya**, persona 1, the core persona, who is in the app for one to three
minutes with her morning tea. She is the reader who would keep a work if keeping were on
screen, and who closes the app before finding out that it is.

## Problem
**The keep control — the product's habit mechanic — is below the fold on the front door,
and nothing on screen says so.**

`CLAUDE.md` names two surviving moats in this category: hand-written editorial voice, and
**habit mechanics (daily push → open → favorite)**. The favorite is the last link in that
chain and it is the one a reader cannot see.

Measured in the real stylesheet at 402×874 on the Aug 4 pick, the control sits **40–60pt
below the cut**. Whether any of it shows at all is an accident of that device's height — on
iPhone 17 Pro the words `KEEP THIS` happen to be bisected by the bottom edge; on another
phone they land cleanly out of frame and the page reads as finished.

**And the fallback day is the good case.** The Aug 4 pick is museum copy, clamped to four
lines by `DESIGN.md` rule 8's carve-out, and the page is ~1.3 screens. On a **hand-written**
day — the day the product exists for — rule 8 shows the note whole, so at the 60–180 word
editorial target the page runs past two screens and the control lands several hundred
points down. The page a curator writes is the **worse** page. Every fix aimed at the short
day fixes only the day nobody wrote.

### What this is not
It is not a scroll-cue problem. That was the first reading and measurement killed it: a
cue tells a reader *there is more below*, never *there is something below worth doing*.
Flashing the native scroll indicator (`flashScrollIndicators()`, five lines in the shell)
solves the cue and leaves the habit mechanic buried. See `decisions/0010` for the four
options measured and rejected.

### The near-miss on an existing decision
`decisions/0005-favorites-free-and-device-local.md` made favorites free forever and
device-local, on Jordan's evidence. That decision is about **not taking the collection
away**. This is the same reader failed one step earlier: nothing was taken away, it was
never findable. 0005 is not reopened and not falsified.

## Story
As Jordan, I want to keep today's artwork without hunting for the control, so that the
collection I am building is something I can actually build daily.

## Intake
- **Evidence:** dogfood of the built app in the simulator, 2026-08-14 — screenshot of `/`
  on iPhone 17 Pro with `KEEP THIS` cut by the bottom edge. Measurement in the real
  stylesheet at 402×874 and 375×667 across both content modes
  (`decisions/0010-actions-become-a-rail.md`). Persona 2's collection is the product and
  persona 1 gives this app 1–3 minutes; a control that costs a scroll to find costs the
  habit. `CLAUDE.md` names habit mechanics as one of two moats in a category where product
  is otherwise commoditized.
- **Success signal (prediction), hand-checkable on ship day, no analytics required:**
  1. On `/`, at **375×667 and 402×874**, at every text size `dynamic_type_test.rb`
     asserts, the keep control is **fully visible without scrolling** — on a hand-written
     day at the 180-word ceiling and on a fallback day alike.
  2. The rail does **not** wrap to a second row at 375px at the accessibility cap.
  3. Every rail control measures **≥ 44 × 44 rendered**, not asserted from CSS.
  4. Zoom's left edge is at the same x before and after the lazy keep fragment resolves —
     no layout shift when the per-visitor fragment lands.
  5. `curl -sI /` still returns `public, no-cache` + ETag and **no `Set-Cookie`**. Story
     0007's line holds: the rail's public half is in the cached page, the personal half is
     in the frame.
  6. The daily page still opens on the artwork. Nothing new sits between the top of the
     screen and the plate.
- **In baseline?** Yes — **baseline item 4, favorites / personal collection.** This is a
  defect in the reachability of a built baseline item, not a new feature. It spends no
  "New" slot; the differentiator stays deferred to the Phase 3 gate (`BET.md`).
- **R7, stated plainly:** this moves **none** of BET.md's five numbers. The scoreboard is
  0 live / 0 posts / 0 keywords / 0 conversations / 0 installs, and **the App Store
  live-by threshold was today, Aug 14** — it is missed as of this story being written, with
  `config/deploy.yml` still carrying two `CHANGEME` values. Shipping this is an input
  metric. It is a one-day story on the screen a first install lands on, and it is still
  not progress.

## Acceptance
- **Actions sit directly under the plate**, above the wall label, on `/` and `/days/:date`.
  Position does not depend on note length, so the control is on screen at open on a 60-word
  day and a 180-word one alike.
- The rail carries **Keep**, the count, and **Zoom** — nothing else. **No placeholder slot
  for a future action ships.** A third action is one element on the day it becomes real.
- **Bare glyphs, no labels** (settled 2026-08-14, `decisions/0010`). The count keeps its
  word — `3 kept`, never `3`. It is the only word left in the rail.
- **Kept state is the filled glyph.** No colour shift, no second mark, no `Kept · Remove`
  wording. `aria-pressed` is unchanged — it never depended on the visible label.
- **Every rail control states both axes of rule 9**: `min-width: 44px` *and*
  `min-height: 44px`. Rule 9 as written says height only, because every control it names is
  a `.caps-link` and words make those wide for free. These have no words. This is the exact
  shape of the assumption that shipped 15px targets in **ISSUE-002** (commit `866bbc2`).
- **The lazy frame's placeholder reserves both axes too.** `.rail__slot` carries
  `min-width: 44px`, or Zoom slides left every time the keep fragment lands — the sideways
  version of the 79px shift already recorded in the stylesheet.
- **Every glyph has a non-empty accessible name containing the artwork title**, and Keep's
  `aria-pressed` tracks state. With the visible words gone the accessible name is the whole
  announcement, so this is a correctness requirement, not a nicety.
- `autofocus` on the write response stays. Turbo replaces the frame, focus drops to
  `<body>`, and focus landing on the toggle is what makes a screen reader say the new state.
- **The old `.keep-frame` at the foot of the label is deleted, not duplicated.** One
  control, one place. The coda stays the single ending.
- **Zoom gains a visible door and no new behaviour.** `shared/_zoom` ships today reachable
  only by tapping the plate, which nothing advertises. The plate stays tappable.
- **Nothing hovers over the artwork.** `DESIGN.md` rule 5 is untouched by this story; the
  rail is in flow, under the plate. Pinterest's overlay is out.
- **Rule 2's third cap term goes `19rem → 22rem`,** and the resulting **−48pt of artwork at
  375×667 on height-capped works is accepted** (settled 2026-08-14). Free at 402×874, where
  55vh is still the smaller number. A smaller picture, never a cropped one.
- `test/system/dynamic_type_test.rb` stays green and **gains the front-door rail
  assertion** — R1, the rule and its enforcement in the same unit of work.
- No new colour, no new link style, no second ornament. `--gold` and `.caps-link` are what
  exists. `DESIGN.md` rule 6's amendment (functional glyphs are not ornament) is already
  written and is not widened by this story.
- `bin/ci` green before QA.

## Out of scope
- **Share.** Not built, no slot, no placeholder. It appears when there is a reason for it,
  and "we will have more actions later" is not one — that is the named
  infrastructure-for-later pattern and it was refused in `decisions/0010`.
- **Any social action** — like, comment, repost, counts belonging to other people. There is
  no social graph and this story does not open one.
- **A keep control on `/feed`.** Story 0006's call, unchanged. It reopens at the Phase 3
  gate or on a real user's request, not on the back of a control moving 400px up a
  different page.
- **A rail on `/feed` or `/collection`.** The rail belongs to the screens whose job is one
  artwork.
- **Icon labels**, and any settings toggle to turn them on. One shape ships.
- **Re-deciding heart vs bookmark**, or the glyph drawings. Settled in `decisions/0010`.
- **`flashScrollIndicators()` in the shell.** Measured and rejected in `decisions/0010`;
  adding it alongside the rail would be paying twice for a problem this story removes.
- **Analytics on keeps.** Session gate 6 is unmet product-wide. Wiring it here is
  scaffolding ahead of the thing that actually needs it.
- **Widening `DESIGN.md` rule 6's glyph exception** beyond the rail's controls.
