# 0024 — The doors get a frame

Date: 2026-09-02
Spec: `specs/0034-a-frame-for-the-doors` (story written this session).

Position: `/you`'s four action controls (Sign out, Delete account, Delete
device, the notification toggle) move off flat gold tracked-caps text onto a
bordered chip — extending `.signin__door`'s existing anatomy, split into a
safe variant (gold/hairline, matching `.signin__door`) and a destructive
variant (`--warn`-tinted). This reverses `specs/0015-the-two-keys/plan.md`'s
original call, re-affirmed at the 2026-08-17 design review (ISSUE-002,
`application.css:1573-1589` — which fixed adjacency spacing but explicitly
kept flat text as house style: "the gold caps-link treatment for a
destructive control is house style and stays"). Direction-level because it
is a reversal of a previously-stated, previously-reaffirmed house-style call,
not a fresh choice on an open question.

## Why now, not before

Both prior passes (0015's original plan, ISSUE-002) reasoned about the
pattern from design review, not from a live account. The reversal trigger is
a real dogfood report against the live production page (2026-09-02, 28 kept
works, real Apple sign-in) — "these are just text and unusable to the user"
— the first time this exact question was asked by someone using the actual
product rather than reviewing it. The within-product evidence: `.signin__door`
(bordered, same screen, same age) has drawn zero such complaints; the flat
controls beside it drew one on first real use.

## What stays

The house voice — gold, small caps, tracked, Fraunces/Newsreader, no
gradients or shadows — is unchanged. This adds a hairline frame and a fill,
not a new visual language; `.signin__door`'s anatomy already existed and is
being extended, not invented. `Privacy`/`Support` (`.legal`) stay flat text
on purpose — the reversal is scoped to controls that perform an action, not
to navigation.

## Prediction (falsifiable, time-bound)

The owner's next 5 live opens of `/you` (both `:account` and `:device`
states) produce zero hesitation before tapping any of the four controls —
the specific complaint that opened this decision does not recur. Falsified
by a repeat of the same complaint, in which case the fix is the wrong
fix (e.g., chip treatment insufficient, needs icon or stronger fill) rather
than merely unfinished, and this decision reopens rather than being patched
in place.

No post-live numeric threshold is set — `BET.md` reads zero installs as of
this decision's date, so there is no funnel to bind a number against. A
support contact or review naming this class of confusion after installs
exist would falsify this decision a second time; logged as a named,
deferred check rather than assumed away.
