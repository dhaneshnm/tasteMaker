# 0023 — The thread replaces the gate

Date: 2026-09-01. Context: story 0033 (`specs/0033-whose-words/`), triggered
by the owner's dogfood of the shipped 0032 gate on its first production day —
the reader's own answer and the museum/curator note read as one voice, no
attribution.

## Position

The words under the artwork become a comment thread: the museum or curator
voice is a **pinned comment**, collapsed by default; the reader's own line is
a comment beside it, prompt until answered. One rail glyph shows or hides the
whole thread — open by default, remembered closed for the day only. Both
comments wear a drawn (never gold-filled) medallion. This retires 0032's F1
(the reader's voice sits above the curator's at the reveal moment): the
reveal event that argument depended on is gone, and the pin's own fold now
carries write-first instead.

Bundled with the thread, by the same owner session: the "N kept" count
leaves the rail on every surface (reversing `decisions/0010`'s narrowing),
and the ink boundary on the reader's own answer moves a second time — see
below.

## The ink boundary, amended again

`decisions/0022` amended write-once to a draft-until-reveal. The reveal
event died the same day it shipped (0032's own redesign, same date). This
story's first draft reinstated a version of write-once anyway ("any saved
body renders as the comment on the next load") — caught at eng review (OV1)
as a regression: on mobile the common path is type-then-tap-away, so most
"commits" would have been accidents.

The boundary now sits at the day's end, structurally rather than by a
clock: a painting is editable exactly as long as it **is** `DailyPick.current`
— the one day the front door shows — and the moment it is not, the only
route to it is the archive, which answers read-only always. Tapping the
comment while it is still today's returns it to the composer, prefilled. An
emptied field plus the "set it down" gesture deletes the row (eng OV2) — a
reader who changes their mind while the day is still theirs is not published
against their will.

## What the new metric measures, and what it blesses

`shown`/`completed` are re-based a second time. Both now dedupe once per
client per day: `shown` on the thread being visible at all (the old
denominator, "gates displayed," becomes "thread seen"), `completed` on the
pin's first expansion (not the reveal, which no longer exists). The
numerator is a subset of the denominator by construction, so the ratio reads
cleanly as "fraction of daily lookers who opened the note."

**0032's own prediction — `completed/shown ≥ 20%` — is retired UNFALSIFIED,
not superseded.** Its measuring mechanism (the reveal event) was deleted the
day 0032 reached production, before a single day of reader data existed
against it. Recorded here so nobody reads a later number as 0032's
prediction resolving; it never had the chance to.

**What success at the new number blesses, said out loud:** if ≥ 30% of daily
lookers open the pin, ~70% never read the hand-written note on a given
day — the product's one moat surface (CLAUDE.md). The stance this story
takes: the moat is that the words exist, are attributed, and cost one
visible, unlocked tap — not that every reader is compelled to read them.
Looking is the ritual; the words are there if the looking asks a question.
If that stance is wrong, this metric, unlike 0032's, will actually say so.

## Falsifiable prediction

Within 14 days of the first 50 front-door opens (post-app-approval; the
Sep 30 kill review will almost certainly predate this, same timeline-honesty
note as `decisions/0022`): **≥ 30% of thread-seen days expand the pinned
note**, and **at least one signed-in reader besides the owner writes an
answer**. Fail either → the medallion dress retreats to the ledger variant
(no avatars — a CSS-layer removal, cheap, pre-built into the implementation
order for exactly this). **Reverting the thread structure itself is NOT a
one-line swap** — it is a multi-file restore (views, CSS, `sit_controller`,
three localStorage keys) plus a second mid-table beacon-meaning flip. Priced
here truthfully so the number is read knowing the exit cost.

## The teaching gap, confronted

`decisions/0010` bought the label-less rail with two mitigations: the count
as a first-time teacher on `/`, and the accessible name on every glyph
everywhere. This story spends the first one entirely — no surface anywhere
teaches with words any more. Accepted with eyes open: Keep's fill still
self-demonstrates on first tap; the bubble's one wrong reading ("other
people's comments," an Instagram habit) is bounded by what it actually
opens — two voices, never a crowd. If the dogfood week shows the bubble
reading as social chrome rather than attribution, the tripwire is the same
medallion retreat named above.

## What would have been easier and was refused

Keeping the prompt visible as a caption under the answer forever (the
outside voice's F7 — rejected, the owner's direction on the reveal read is
literal: once answered, the prompt is not shown again); shipping the ledger
variant by default instead of medallions (F12's headline — rejected, the
owner picked variant C with medallions on the comparison board; the ledger
stays the pre-built retreat, not the default); mounting `sit_controller`
on the archive so a closed pin there can't desync from the artwork's
`aria-describedby` (a real, narrow accessibility edge case, accepted rather
than adding JS to a surface the plan keeps deliberately inert — see
`daily/_day.html.erb`'s own comment at the describedby computation).
