# 0010 — Actions become a rail under the plate

Date: 2026-08-14

Position: reader actions leave the bottom of the wall label and become a row of
line icons directly beneath the artwork — the arrangement Instagram, Google Arts
& Culture and Artsy all share. Direction-level because it moves the product's
only habit mechanic, and because it amends `DESIGN.md` rule 6.

## What was actually wrong

`Keep this` — the favorite, the habit mechanic `CLAUDE.md` names as one of two
surviving moats — was below the fold on the front door, with nothing on screen
saying so. Measured in the real stylesheet at 402×874 on the Aug 4 pick, the
control sat 40–60pt under the cut. Whether any of it showed at all was an
accident of that device's height.

The instinct to treat this as a scroll-cue problem was wrong, and measurement is
what showed it. On a **fallback** day the page is ~1.3 screens. On a **hand-written**
day — the one the product exists for — rule 8 says the note is shown whole, so at
the 60–180 word target the page runs past two screens and the control lands
several hundred points down. Every fix aimed at the short page fixed only the day
the curator did not write.

## What decided the shape

Placement, not iconography. The action sits next to the artwork instead of after
the prose, so its position no longer depends on how long the note is. That holds
at 60 words and at 180, which is the only property that mattered.

Measured, both devices, on the tallest work in the pool shape — a hanging scroll,
1074 × 1600 (`Birds and Chrysanthemums in Snow`, Geiai 芸愛, MIA):

- The rail adds ~48pt above the note, so rule 2's third cap term goes
  `19rem → 22rem`.
- **iPhone 17 Pro (402×874): the rail is free.** `100dvh - 22rem` is 522pt
  against a 55vh of 481pt, so `min()` still picks 55vh and the plate does not
  move. It would take a reserve over 24.6rem before that term bites at all.
- **iPhone SE (375×667): it costs 48pt of artwork, −13%.** `100dvh - 22rem` is
  315pt against a 55vh of 367pt. This is the device `dynamic_type_test.rb`
  already measures and the one persona 2 is holding, so it is the number that
  counts. Accepted: rule 2 allows a smaller picture, never a cropped one, and
  this only affects works tall enough to be height-capped.

On the glyphs: **bookmark, not heart.** The convention that survives testing is
heart = like, a signal aimed at another person; bookmark = save for later. Tondo
has no social graph — there is nobody on the other end of a heart. The action is
called Keep. Google Arts & Culture uses a heart anyway, which is a like-shaped
glyph doing a save-shaped job.

**Zoom joins the rail**, because it already exists. `shared/_zoom` ships today
reachable only by tapping the plate, which nothing advertises, and high-resolution
zoom is the feature reviews of the category leader single out by name. The rail
gives a built thing a visible door; it is not a new feature.

## What was rejected, and why

- **Flashing the native scroll indicator** (`flashScrollIndicators()` in the
  shell). Five lines, no design rule touched, and it was the cheapest answer. It
  says *there is more below*; it never says *there is something here worth doing*.
  It solves the scroll cue and leaves the habit mechanic buried.
- **Moving only the metadata.** Lifting the credit and source lines above the
  keep control buys back ~70pt, enough on a fallback day and nothing at all on a
  hand-written one. A partial fix to the wrong page.
- **Guaranteeing a clipped line at the fold.** Nothing in CSS knows where the
  fold falls relative to a line of type — page height moves with note length,
  Dynamic Type and device. Getting it needs JavaScript measuring viewport against
  document, which is the exact trade rule 5 already refuses in writing.
- **Spreading the rail** the way Instagram does, bookmark hard right. That works
  at 402pt and breaks at Tondo's 680pt measure; the existing keep control already
  carries the finding that 466px apart *"stops reading as a pair."* The rail stays
  left-grouped and inherits that note.
- **Overlaying the actions on the image**, Pinterest-style. Rule 5, unamended:
  nothing hovers over an artwork.
- **Building slots for future actions.** Named as the user's historical failure
  pattern and refused. The rail is a flex row with a gap — a third action is one
  element on the day it becomes real. Share is drawn in the mock only to show the
  row holds it; no placeholder ships.

## What this amends

`DESIGN.md` rule 6 said *"No glyph in the kept state"*, and the reason it gave was
that `✦` is the product's only ornament and a second mark a few centimetres away
meant two ornaments saying different things. The reasoning was never "no icons" —
it was "not a second `✦`, not there."

The rail sits under the plate, a full screen above the coda, so the two marks are
never in frame together; and these are controls, not decoration. Rule 6 keeps its
job — one *decorative* ornament — and gains a stated exception for *functional*
glyphs.

## Settled the same day

Three choices were left open above and were made 2026-08-14:

- **No labels.** Bare glyphs. This goes against the evidence and is recorded as
  such: NN/g measures unlabelled app-specific icons at 34% correct prediction and
  icon-only usability at ~60%, and Instagram buys that literacy with dozens of
  opens a day where this product gets one. The recommendation was icon plus caps
  label. Overruled deliberately, for the quieter row. The mitigations are the
  count keeping its word — `3 kept`, not `3`, the only word left in the rail and
  the one free piece of literacy on it — and accessible names on every glyph.
  If a reader misreads a glyph in the five `BET.md` conversations, this is the
  line that was wrong and labels are the fix already costed.
- **Kept state is the filled glyph.** No colour shift, no second mark, no words.
- **The 48pt is accepted** at 375×667.

One consequence that only appears without labels: **rule 9 needs a second axis.**
It states `min-height: 44px` and says nothing about width because every control
it names is a `.caps-link`, and words make those wide for free. A bare glyph has
no words, so the target would be 23px across and 44px tall. `.rail__act` states
both, and so does the lazy frame's placeholder — `.rail__slot` reserves
`min-width: 44px` or Zoom slides left every time the keep fragment lands, which
is the sideways version of the 79px shift already recorded in the stylesheet.

**Amended 2026-08-14, same day, after `/simplify`.** The paragraph above is left
as written because it is what was decided; this is what happened to it. Two
things landed between the decision and the code that made `.rail__slot`'s reserve
dead, and it was removed:

- The frame ships **default content** (the un-kept glyph), so a real `.rail__act`
  already holds a `--tap` box in both directions before the fetch resolves.
- **Zoom moved to first in the row**, so the frame that grows has nothing to its
  right to shove.

Either one alone would have retired the reserve; both shipped. What survives is
the finding underneath it — rule 9 needed a second axis — and that is now a
`--tap` token rather than a number written in four places. `.rail__act` still
states `min-width`; only the placeholder's duplicate box went.

## Prediction (falsifiable, time-bound)

Through the **Aug 31, 2026** kill review: `Keep this` is on screen at open on
every published day on both 375×667 and 402×874, at every Dynamic Type size
`dynamic_type_test.rb` asserts, with no scroll. No reader in the five
conversations `BET.md` requires asks what an icon in the rail does, and no fourth
action or placeholder slot is added to the row.

Falsified if a reader misreads a glyph, if the rail acquires a slot with nothing
behind it, if the row wraps to two lines at 375px at the accessibility cap, or if
keeping requires a scroll on any published day.

## Enforcement

Owed by the story that implements this, not by this file:

- `test/system/dynamic_type_test.rb` gains a front-door assertion that the rail's
  keep control is above the fold at every asserted text size, on both viewports
  and on both a landscape and a height-capped work.
- A system test asserting the rail does not wrap to two rows at 375px at the
  accessibility cap — the same failure mode the compass row was measured against.
- Target-size coverage: rule 9's 44pt minimum on every rail control, the bar
  `ISSUE-002` shipped 15px targets by assuming.
- Accessible names on every glyph, asserted, since the kept state stops carrying
  its meaning in visible words the moment `Kept · Remove` becomes a filled mark.
