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

### A Keep rail on every multi-work surface — Better (habit)

Source: `/plan-design-review` on `specs/0018-the-names-you-know/plan.md`, 2026-08-18 (D7).

`/feed` and the new `/artists/:slug` both render works with no `.rail`, so Zoom and Keep
are unreachable from them. Discovery → keep is the shortest habit loop in the product,
and the habit mechanic is one of only two moats `CLAUDE.md` names. Tomás landing on 3–5
newly discovered works by one artist is peak keep intent, and today he has to leave the
page to act on it.

Not introduced by 0018 — `/feed` has shipped this way since 0013, and 0018 inherits it.
Cost: N private Turbo frames on a walled page, plus a change to the shared post partial
that lands on both surfaces at once. Depends on 0018 Release 1.

## Considering — top = next pick

### The coverage fill — recognizable names — Better (range)

Split out of story 0018 by `/plan-eng-review`, 2026-08-18 (E5). **Next pick once 0018
Release 1 ships.** Full spec survives verbatim under "Release 2" in
`specs/0018-the-names-you-know/plan.md` — including the Europe-at-exactly-25.0% arithmetic
and the `Unmeetable` dry-run gate that proves feasibility before anything is written.

Why it was split: Release 1 is a same-day app fix; this is research plus a re-curation
whose feasibility the plan itself calls "unknowable without a dry run". An unbounded tail
does not share a WIP slot with a same-day fix 13 days from kill review (R5).

Depends on 0018 Release 1 — it establishes `artist_slug`, `artist_works_count` and the
shared slug function this work reads.

Carries three findings deferred into it:
- Fill depth **2–3**, not ≥1 (design review D17). Under the ≥2 link rule, a filled name
  that lands one work produces an artist page nobody can reach.
- Fix `dedup_key`'s normalization (`lib/pool.rb:60`) — the same non-transliterating `gsub`
  as `artist_key`, so accented and unaccented spellings of one title never dedup. Deferred
  here because it changes which works survive curation.
- **The deny-list's one critical gap:** a culture string a future source introduces
  ("Bhutan") becomes an artist page silently — no test, no handling. Fix is a
  `pool:report` line flagging single-word artist slugs with more than one work, for a
  human pass before seeding.

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
