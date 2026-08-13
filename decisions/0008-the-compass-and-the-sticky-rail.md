# 0008 — The compass, and the one sticky bar

Date: 2026-08-13

Position: navigation in this product is a web-page concern, carried by one
component that renders on every screen in the same place, showing all four
surfaces and marking the one you are on by taking its link away. The single
unbounded screen, `/feed`, carries that component in a sticky rail of its own
with no JavaScript. Direction-level because it is chrome on every screen and it
narrows a `DESIGN.md` rule.

## What was actually wrong

Four reader surfaces, and the links between them were a one-way funnel. `/feed`
streamed 110 works and its only exit was the serif wordmark, which stops being on
screen after two flicks because the masthead is not sticky and the coda renders
only on the last page. `/collection` was reachable from one line in one footer.
The archive's door on the front page was an unlabelled date that appeared only
once a second day existed.

Each of those had been patched once, on one screen, the day somebody noticed —
ISSUE-001 was this same bug on the empty collection page. Patching the fifth
instance was not going to be the last time.

## What decided the shape

Measurement, not taste. Built in the real stylesheet at 375×667, the sizes
`test/system/dynamic_type_test.rb` asserts:

- The product's long editorial voice (`The days behind you`) wraps to three rows
  at 375px. Every row costs 44px, because `DESIGN.md` rule 9 applies to each item
  and `.caps-link` sets size and tracking but never height. Three rows put the
  note's first line 35px below the fold at the accessibility cap — it broke the
  bar the leader fails and this product exists to hold.
- One-word labels fit on one row. The gap had to be clamped rather than set in
  `rem`, because a `rem` gap grows with the text at exactly the moment there is
  least room for it — at 1.4rem the row wrapped, at 1rem it wrapped by one pixel.
- Even at one row the compass did not fit. The front door had 43px of headroom
  and the row needs 44. So `.plate__img` gained a third cap term,
  `calc(100dvh - 19rem)`: the picture yields height to keep the first written
  line on screen, and only when the text is scaled up. That is the cap doing the
  job its own comment always claimed.
- `19rem` is set by the worst page that ships, not the friendliest. The seed data
  holds 18 titles over 60 characters and one of 104; `17rem` passed the short
  fixture and missed the long one by 10px.

## What was rejected, and why

- **Rendering only the other three destinations.** Moves every label one slot
  depending on the screen. The claim was "learned once"; a set whose positions
  move is the opposite.
- **A sticky masthead on `/feed`.** 104px, 16% of an iPhone SE screen, parked
  over the artwork for the whole scroll — a wordmark and a work count spending an
  exception written to protect pictures.
- **A shape-changing sticky bar** that hides the brand once stuck. There is no
  cross-browser stuck-state selector and iOS Safari is the target, so this needs
  the app's first scroll-watching JavaScript. The rail is structural instead: the
  masthead leaves, the rail does not, nothing changes shape.
- **A native tab bar.** `decisions/0006` stands. This is the amendment its "three
  ways" clause needed, not a reversal — that decision paid for the missing back
  button with the brand link, the walk, and swipe-back, and the first dogfood pass
  of the built product showed the brand link does not carry that load on `/feed`.
- **Deleting the daily coda's `Wander the full gallery →`.** The design review
  read it as a duplicate of the compass's `GALLERY`; the outside voice read the
  coda as the ritual's closing beat. Kept, on the same reasoning that kept the
  keep frame's `N kept →`: an invitation is not an exit sign.

## Prediction (falsifiable, time-bound)

Through the **Aug 31, 2026** kill review: no reader in the five conversations
`BET.md` requires raises "how do I get back" or "where is my collection"
unprompted, and no fifth navigation surface, native tab bar, or scroll-watching
JavaScript is added to carry navigation.

Falsified if a reader raises navigation unprompted, if any screen ships that a
reader can reach and cannot leave through the compass, or if the rail acquires a
scroll listener.

## Enforcement

`test/integration/navigation_test.rb` asserts the matrix: every reader surface
links every other one, the current surface is marked and unlinked, `/feed` emits
exactly one `nav[aria-label="Sections"]`, and an unknown `here:` raises rather
than quietly linking everything. `test/system/feed_test.rb` asserts the rail is
on screen at scroll 1200, under 70px, that the masthead is gone, and that the
zoom overlay covers it. `test/system/dynamic_type_test.rb` holds the fold budget
on three page shapes, including the longest title in the dataset.

One thing this decision fixed on the way past, recorded because it silently
weakened every measurement in the suite: `ApplicationSystemTestCase` claimed a
375×667 viewport and was running at 500×667, because headless Chrome on macOS
will not size a window below roughly 500px wide and `window.resize_to` clamped
without complaining. Every fold assertion in this product had been measured
125px wider than the phone it named, in the direction that hides bugs — the
compass fits on one row at 500px and wraps at 375. It now sets the viewport
through `Emulation.setDeviceMetricsOverride`, which is not bound by any window
minimum.
