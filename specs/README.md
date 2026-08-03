# specs/

One folder per story: `NNNN-slug/` containing `story.md` and `plan.md`.
The spec IS the intake card — no separate document. Flow lives in CLAUDE.md ("Build flow").

## story.md template

```
# NNNN — Title
Date: YYYY-MM-DD
Lane: Express (same-day, reversible) | Full (≤ 3-day core)
Status: Draft | Planned | Building | Shipped | Killed

## Who
<the user, in one or two sentences>

## Problem
<their problem, in their terms>

## Story
As <who>, I want <capability>, so that <outcome>.

## Intake
- Evidence: <why this, why now — teardown finding, user conversation, BET.md threshold>
- Success signal (prediction): <observable, checkable after ship>
- In baseline? <yes: which item / no: evidence must argue for the exception>

## Out of scope
<explicit non-goals for this story>
```

## plan.md template

```
# NNNN — Implementation plan
Status: Draft | Reviewed (/plan-eng-review) | Building | Done

## Approach
<short; models, routes, jobs, views touched>

## Steps
1. …

## Tests
<what Minitest covers — written during implementation, not after>

## Deviations (added during build)
- <date>: <what changed vs plan, why>
```
