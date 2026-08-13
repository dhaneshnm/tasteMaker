# Tondo — CLAUDE.md

Month 1 (Aug 2026) of a 12-month one-app-per-month experiment. iOS daily-art category.
Fork B: **practice vehicle, not a revenue bet.** Kill review **Aug 31, 2026**, against the
numeric thresholds in `BET.md` — never against felt traction.

## Settled category facts — do not re-derive, do not reopen mid-build
- Category revenue plausibly < $500K/yr; willingness to pay ≈ zero (~5¢/lifetime install for leader).
- Distribution decides this category; product is commoditized.
- Only surviving moats: **hand-written editorial voice** and **habit mechanics** (daily push → open → favorite).
- Images: CC0 museum APIs (Met, Art Institute of Chicago, Cleveland). Content floor is zero.
- Aggregation (more content, AI-generated text) is a documented strategic trap.

## Build order — Proven / Better / New
Ship the Proven baseline first, then execution quality, then exactly **one** "New"
differentiator — named in `BET.md` before Phase 3 starts. Never invented mid-build.

Proven baseline:
1. One artwork per day, curated, short **hand-written** editorial blurb.
2. Daily push notification — the habit driver.
3. Browsable archive of past days.
4. Favorites / personal collection.
5. Free at launch. No billing now (premium unlock is a later-phase decision, floor ~$30/yr).

Content pipeline: CC0 museum APIs → curated queue → daily publish job (Solid Queue).
**BANNED: AI-generated artwork descriptions.** Editorial text is written by the user.

Better bucket — execution quality bars applied while building the baseline (evidence:
leader's review failures, see `specs/personas.md`). Not extra features:
1. Blurb craft: accurate, specific, proportioned, zero promo cruft.
2. Art + text visible together — text never swallows the artwork.
3. Fast: images cached locally, no stutter, instant open.
4. Calm: no ads, no upsell interrupts, nothing between push and art (free by baseline — protect it).
5. "Today" rolls over correctly per timezone.
6. Curation range: beyond Euro-canon greatest hits.
7. Zoomable, high-quality images.
(iOS widget appears in evidence but is a new surface, not a quality bar — own spec, post-baseline.)

## Build flow — every feature follows this, in order
1. User describes who the user is + their problem → write user story with intake fields
   (problem, evidence, success-signal prediction, lane: Express same-day reversible /
   Full ≤ 3-day core) → `specs/NNNN-slug/story.md`. The spec IS the intake card.
2. Generate implementation plan → `specs/NNNN-slug/plan.md`. Implement-time deviations
   get noted back into the plan file.
3. `/plan-design-review` on the plan — only for features with significant UI. Skipping it
   on a UI-light story is fine; note the skip.
4. `/plan-eng-review` on the plan. Direction-level changes → `decisions/` entry (R4).
5. Implement **with Minitest coverage as you go**; `bin/ci` green before QA. Tests are
   part of implementation, not a later step (R1).
6. `/qa` → fix findings.
7. `/simplify`, then `/code-review` → fix findings.
8. Re-verify: `bin/ci` + quick smoke — steps 6–7 mutated code after QA passed.
9. Ship: commit, deploy when live, `SHIPLOG.md` line with receipt. Done = shipped and
   logged, not reviewed (R7).

Size stories to lane: each shippable in ≤ 2 days. WIP = 1 means one story in flight, ever.

## Do NOT build
- Any feature without a spec in `specs/` (story + intake fields — see Build flow).
  Out-of-baseline features must carry evidence that actually argues for the exception.
- **"Infrastructure for later"** — the user's named historical failure pattern. If asked for
  speculative scaffolding or abstractions the current phase doesn't need, name it out loud
  and push back.
- A second "New" differentiator. One slot.
- Native SwiftUI rewrite, React, node build chain, SPA.

## Stack — non-negotiable; deviation needs a one-line reason committed to `decisions/`
- Rails 8.x omakase: Propshaft, importmap-rails, no node toolchain.
- Hotwire (Turbo + Stimulus) for all UI.
- Hotwire Native iOS: web-first screens in a thin shell; bridge components only where
  genuinely required. Accepted native exception: **APNs push registration and delivery.**
- SQLite in production + Solid Queue / Solid Cache / Solid Cable. Postgres only with a
  written reason. (Solid gems not yet in Gemfile — add Solid Queue when building the
  daily publish job, not before.)
- Kamal 2 (single VPS) + Thruster — add at first deploy, not before.
- Minitest + fixtures + Capybara system tests. No RSpec.
- Rails 8 built-in auth generator if accounts become necessary. Device-local favorites vs
  accounts = spec decision with evidence, not assumption.
- Active Storage on local disk for cached artwork images.
- Parked, do not build: StoreKit/IAP for premium unlock inside the Hotwire Native shell.

## Operating rules — operative, not advisory
- **R1 Forcing function.** No artifact without its enforcement in the same unit of work
  (tests → CI runs them; rule → check; posting plan → public log).
- **R2 Bet before commit.** `BET.md` complete and committed before any feature commit.
  Missing or blank fields → stop and say so. No "small commit" exceptions.
- **R4 Written fingerprints.** Direction-level decisions (features, pricing, kill/ship,
  stack deviations) → short position + falsifiable, time-bound prediction in `decisions/`.
- **R5 WIP limit 1.** One thing in Building. Branch dark > 2 weeks → merge, kill with a
  note, or written bet. Hidden WIP = automatic flag.
- **R7 Adversarial on progress claims.** Commits, migrations, green suites = input metrics.
  Progress = published posts, ranked keywords, initiated user conversations, installs.
  Progress claim → ask for the receipt.
- **R8 Communication contract.** Terse in, production-ready out. Scannable structure
  (headers, short sections, plain words) is an accessibility requirement (dyslexia, ADHD),
  not decoration. Acknowledge corrections plainly, no over-apology. Read existing written
  context instead of asking for re-explanation.
- **R9 Delegated trust on strengths.** Architecture, patterns, build execution get review,
  not supervision. No manufactured pushback. Spend the challenge budget on scope drift,
  kill discipline, and whether the user talked to users this week.

## Session-start gates — state failures in first message, then proceed
1. `BET.md` complete and committed? No → no feature work this session.
2. Inside month boundary? Kill review Aug 31, 2026.
3. WIP = 1?
4. Anything in flight without a spec in `specs/`?
5. `SHIPLOG.md` current? A week with shipped code and zero initiated user contact →
   name it as builder's gravity.
6. Before first external user: backups + logged restore test, secrets in Rails
   credentials / Kamal secrets, error tracking + analytics wired, accurate App Store
   privacy labels.

## Session protocol
- Terse instruction in → production-ready output back. Ask only when genuinely blocked;
  otherwise make the call and note it.
- Mid-session direction choices → `decisions/` entry before session end.
- Session end: update `SHIPLOG.md` if anything shipped or published; surface drift —
  reopened settled questions, second analysis threads, spec-less features,
  infrastructure for later.

## Skills
Create a skill only after its workflow has been run manually ≥ 2 times — a speculative
skill is infrastructure for later. Anatomy: SKILL.md, triggering description up top,
bundled scripts/references only as needed, body < 500 lines.
