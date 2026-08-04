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

Enforcement: `test/integration/daily_test.rb` covers both voices and the attribution;
`DailyPick#note` returns the voice alongside the text so no caller can render museum copy
without knowing it did.
