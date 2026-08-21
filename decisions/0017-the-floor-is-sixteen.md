# 0017 — The floor is sixteen: a facet value is a wing, or it is not offered

Date: 2026-08-21
Trigger: story 0027 (`specs/0027-the-wing-label/`), eng review finding 1.2 and the
outside voice's #1–#2. Owner decision, recorded under R4 in the same unit of work as
the constant change.

## Position

`Painting::MIN_FACET_WORKS` moves **5 → 16**. A facet value with fewer than sixteen
works in the current scope is not offered as a door. The value stays on the works
that carry it (a label is a fact about the work; a floor is a fact about the door),
and a deep link to it still resolves and filters — the reader who has the address
gets the page, and the index shows the value as "here" in its own section.

Why sixteen and not twenty, which the story first wrote: the list decided it.
Measured on the committed pool 2026-08-21, the values under twenty are:

| Facet | Under 20 |
|---|---|
| tradition | **Persian & Islamic 19**, Madhubani 6 |
| genre | Marine 11, Cityscape 10, Animal 9, Nude 7, Icon 4, Vanitas 2, Battle 1, Genre scene 1 |
| period | 12th century 15, then 4 and below |

Persian & Islamic painting is the second-most-searched tradition in `user-research/
0008` (51,170 monthly lookups); 0026 aimed at ≥ 25 and the mirrors gave 19. Twenty
would have dropped it by accident — the story's own defect table missed it. Sixteen
keeps it and still drops every near-dead end the story named (12th century at 15 is
the next value up). The number is a threshold on a measured list, not a round number.

## What this reverses, on the record

0022 wrote the floor as "provisional; Release 2 re-decides by measurement" and nobody
re-decided. 0026's success signals asserted that Cityscape (10) and Madhubani (6)
clear the floor (`test/lib/pool_quota_test.rb:367, :374`); 0024's asserted every
canonical tradition clears it (`:294`). Under this floor those three assertions
invert for Cityscape, Madhubani and nothing else. They are rewritten to an **exact,
dated, named list of values expected below the floor** — a value that starves or
recovers without the list changing fails the suite. The 0026 work is not undone: the
works exist, carry their labels, and will be offered the day the wing reaches sixteen.

## Falsifiable predictions

1. **By Aug 23 (0027's ship):** the index offers exactly the values with ≥ 16 works in
   scope; `pool_quota_test` carries the named below-floor list (Madhubani, Cityscape,
   Animal, Nude, Marine, 12th century, and the sub-5 tail); zero reachable empty
   states by construction. **Falsified if** any offered door lands under sixteen.
2. **By Sep 20 (0015's binding-read date):** no reader conversation or gallery-run
   note names a missing wing that sits between 5 and 15 works. **Falsified if** one
   does — then the floor drops to that value's count, by measurement again, in a
   one-line change with this entry amended.
3. **Tripwire:** if Persian & Islamic ever falls under 16 after a reseed, the build
   fails on the named list, not silently — the list is the tripwire.

## Costs, named

Six values that rendered as wings today stop being offered (they were closets — 6 to
15 works, 74% of two-tap paths dead). 0026's Cityscape and Madhubani targets were met
on paper and are now below the door; the honest reading is that 0026 hit a floor of 5
that was never the right floor. Nothing deleted, nothing re-curated.
