# 0025 — The corner loses its explanations

Date: 2026-09-03
Spec: none written — an Express-lane copy/spacing pass on an already-shipped
page (story 0017), reviewed on a design-canvas mock rather than a
`specs/NNNN-slug` story. Noted here per Build flow step 2 ("implement-time
deviations get noted back") since no plan file exists to note it in.

Position: `/you`'s four states get a copy trim and two shared-class overrides
scoped to this page alone.

- **Copy, `:account` state** — "Signed in with Apple." only. Cut the
  kept-work count/travels-with-account sentence and "No other settings live
  here yet."
- **Copy, `:device` state, kept works + doors available** — one line, "Sign
  in to save your kept work(s) to your account," replacing the paragraph
  that spelled out the consequence (phone-local collection empties until
  signed back in; nothing is deleted).
- **Copy, push section** — both status lines ("The daily notification is
  on." / "Notify when today's artwork is ready.") cut; the button/link
  states are left to speak for themselves.
- **Spacing** — `.page--empty`'s `clamp(4rem, 18vh, 8rem)` top pad and
  `.ornament`'s flanking dashes (`———✦———`) are DESIGN.md-documented,
  deliberate choices (`DESIGN.md:240`, "centres an empty state") shared by
  ten-plus other screens (404, empty favorites/gallery/days, artists,
  daily, privacy/support). Reversed for `/you` only, via a new `.corner`
  scope class on that page's `<main>` — the shared definitions are
  untouched everywhere else.

Mock: https://claude.ai/code/artifact/7f7d1116-e13e-45b4-bb72-31bef553e15d
(four states, iterated live with the owner over several rounds).

## Why now, not before

Trigger was a live-production screenshot: the owner's account state showed
Sign Out and Delete Account touching border-to-border (a real CSS bug, fixed
separately — `9afd0f9`) and, once that was fixed, a ~320px dead zone above
the ornament that the owner asked "why do we have that space" about. The
answer (design-system rule, not a bug) didn't change the owner's read that
the space wasn't earning its keep on this specific page. Each copy cut
followed the same pattern: the owner read the mock, named the redundant or
over-explaining line, and it came out — this decision is the roll-up of six
small calls made over one session, not one designed all at once.

## What stays

The house voice, the chip treatment (`decisions/0024`), the gold ✦ mark
itself, and every OTHER page's `.page--empty`/`.ornament` rendering —
untouched. This is a scoped reversal for one screen's specific over-density,
not a house-style reopening.

## Prediction (falsifiable, time-bound)

No installs exist yet (`BET.md`), so no funnel number applies. The check is
qualitative and near-term: the owner's next live pass on `/you` (all four
states, on-device) produces no "wait, what happened to—" moment for a
control whose explanation was cut — specifically the device-state sign-in
consequence and the push on/off status. A support contact or a repeat
"what does this button do" question after install traffic exists falsifies
this and reopens the cut, rather than being patched in place silently.
