# 0002 — Keep the infinite-scroll MVP; it maps to persona 4

Date: 2026-08-03

Position: The shipped infinite-scroll feed (commit fdf28c5: Painting model, MIA seed data,
Turbo lazy-frame pagination) is kept, not deleted. It maps to persona 4 (Reference Browser
— see specs/personas.md) and is the front-runner for the New slot. Baseline (one-per-day,
push, archive, favorites) is built in the same codebase on the same Painting substrate.
Formal New-slot naming still happens at the Phase 3 gate per BET.md — front-runner status
is not a naming. Until named, the feed gets zero new feature work (WIP = 1 protects
baseline).

Prediction: at the Phase 3 gate, with baseline shipped and ≥ a few user conversations done,
the feed will be named the New slot in ≤ 1 day of deliberation because the substrate
already exists; if conversations instead surface persona 5 (personalization) as the
stronger want, this prediction is falsified and the feed stays an unlinked archive view.

Amendment, 2026-08-03: "zero new feature work" holds for capabilities. It does not cover
making an existing component behave the same way on both screens — after
`decisions/0003-one-skin.md` the two screens are visibly the same product, so a gesture
that works on one and dies on the other is a defect, not a missing feature. Story
`specs/0002-feed-zoom/` is the one exception taken under this reading: no model, no route,
no new content, half a day. If an exception ever needs more than that, it waits for the
Phase 3 gate.
