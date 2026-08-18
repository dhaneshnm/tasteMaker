# IDEAS.md — idea/feature queue

Everything not being built right now. Flow: CLAUDE.md Build flow step 0. Not a spec —
intake fields (evidence, success signal, lane) happen at promotion to
`specs/NNNN-slug/story.md`.

**Not for:** outreach/research logistics (gallery-run protocol, named R3 targets). Those
feed BET.md's conversation threshold — track in `user-research/`, never as queue rows.

## How to use

- **Capture:** one dated line under Inbox — `- YYYY-MM-DD — <idea> (who/where)`.
  No bucket, no rationale, no ID. Done in seconds.
- **Triage (batch, not live):** move Inbox lines to Considering (ordered — top = next
  pick) or Parked (reason required — the reason says dormant vs dead).
- **Pick:** WIP slot opens (R5) → take the top Considering entry → promote per Build
  flow step 1 → move the entry to Promoted with its spec number.
- **Bucket tag** = Proven / Better / New (CLAUDE.md build order). `—` until triage
  assigns one; unassigned = triage TODO, not a fourth lane. One New slot total — the
  slot is named in `BET.md` at the Phase 3 gate, not here.

## Inbox

(empty)

## Considering — top = next pick

### Theme/period filters — Proven (nav)
2026-08-15/16 — gallery test. Observed: theme-seeking in session ("portraits",
"landscapes from the impressionist era").
Genre facets (~15–25 categories from an existing taxonomy — Getty AAT / Wikidata /
Iconclass, don't invent one) + period/movement. Country facet is inference — lower
priority. Not before submission; first candidate after. Build as navigation, not the
product — the differentiator stays voice + coach; filters are ArtDay's surface.

## Parked — reason required

- **Bulk expansion to 10–20K works** — settled fact (CLAUDE.md): aggregation is the
  documented strategic trap — do not reopen; no user signal unparks this. Inference
  only, no user evidence; ArtDay has 300K works. Bounded coverage fill
  (`specs/0018-the-names-you-know`, Release 2) is the in-scope alternative.
  (2026-08-14 memo)
- **Similar works on keep** (metadata similarity vs vector image search) — Better.
  Zero gallery-test evidence. Vector embeddings before a proven need =
  infrastructure-for-later by name. Needs a user signal. (2026-08-14 memo)
- **Social / invite mechanics** — no evidence from any Tondo test; investigate-only.
  Extract mechanics (Nikita Bier: invite flows, shareability), demo thesis rejected.
  Output would be a `decisions/` note, not a feature. (2026-08-14 memo)
- **Art coach** (gaze → record → delta → dialogue) — New-slot *candidate*; the slot
  itself is still Deferred in `BET.md` and gets named there at the Phase 3 gate (R4
  `decisions/` entry then). Blocked: step 3 as sketched is LLM-graded free text — the
  anti-pattern vs the answer-key framework; needs keyed multiple-choice / spatial
  hit-test redesign first. Validation plan open. Latent demand proven at scale
  (YouTube); zero expressed demand for interactive/paid. (2026-08-14 memo)

## Promoted

- 2026-08-18 — Artist page + recognizable-artist coverage fill →
  `specs/0018-the-names-you-know` (one spec, two releases)
