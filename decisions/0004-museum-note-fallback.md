# 0004 — A day with no note runs the museum's text, attributed

Date: 2026-08-04

Position: `blurb` becomes optional. When a curator has not written a note, the daily page
runs `paintings.description` — the museum's own CC0 copy — under the line "From the
Minneapolis Institute of Art", in the metadata treatment rather than the prose treatment.
A pick still cannot exist with neither: if the painting has no museum text either, the
blurb is required and the form says why.

The tension this accepts, stated plainly: `CLAUDE.md` names hand-written editorial voice
as one of only two surviving moats in this category, and `/feed` already shows museum
copy. A silent fallback would mean the differentiator switches itself off on exactly the
days the curator was too busy — and nobody, including the curator, would see it happen.
The attribution is what makes it survivable: the reader always knows whose voice they are
reading, and a run of museum days is visible on the page rather than hidden in the data.
The admin form says the same thing in the same words: the escape hatch, not the plan.

Prediction, falsifiable at the Aug 31 2026 kill review: fewer than 1 in 5 published days
will run museum text. If it is more than that, the fallback is not an escape hatch, it is
the product admitting the daily note is not actually being written — and at that point the
honest move is to fix the publishing cadence or kill the daily format, not to keep
shipping borrowed words under a masthead that promises a curator.

Museum copy is clamped on the daily page, the way it already is in the archive. The
hand-written note is never clamped — that rule is about the curator's words, and it does
not transfer to borrowed ones. Descriptions in the current pool run to 324 words against a
60–180 target, so shown whole they would push the artwork off a phone screen and break
Better bar 2.

Enforcement: `test/integration/daily_test.rb` covers both voices, the attribution and the
clamp. The **receipt for the prediction** is on the curator's queue: a day with no note
reads "museum text" rather than "0 words", and the page states the running ratio against
the 20% line. Counting is a glance, not a query written on Aug 31.

Not changed, deliberately: the PWA manifest and the default meta description still promise
"a short hand-written note". That is what the product is; the fallback is the bounded
exception this decision allows, and the prediction above is the thing that keeps it
bounded. If the ratio breaks 20%, the copy is not what needs fixing.

## Amendment — 2026-08-19, story 0021 (the standing order)

The 20% prediction above was made under the manual regime, where every published day
implied a curator choosing it. Story 0021 makes the machine fill the queue and museum
text the default output of a *correct* system — under an unsplit count the banner would
go permanently red within weeks and this bet would read as falsified by regime change,
not by evidence.

Amended, not retired: **the 20% line now measures hand-picked days only** — the
population the bet was made about. Auto-picked days are measured by decisions/0015's
one-third-blurb tripwire on their own line of the same banner (binding read at 30
auto-picked published days, ~Sep 20, 2026). The `auto_tier` column ships with 0021 and
is what makes the split countable. If the *hand-picked* ratio breaks 20%, this decision
still says the copy is not what needs fixing.
