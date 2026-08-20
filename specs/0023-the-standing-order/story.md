# 0023 — The standing order

Date: 2026-08-19
Lane: **Full (≤ 3-day core).** New gem (Solid Queue), one migration, one job, one
selection policy with tests. No reader-facing UI change.
Status: **Shipped — code only, not deployed** (`fb67cf7`, `bin/ci` green: rubocop,
bundler-audit, importmap audit, brakeman, 451 unit/integration + 59 system tests).
See `SHIPLOG.md` 2026-08-19 for the full receipt and `plan.md`'s Deviations for
what changed during build and review.

Captured and promoted same day (`IDEAS.md` 2026-08-19): the source is a direct operator
report, not an inference, and the WIP slot is open (0020 shipped code-complete).

## Who

- **The curator** — the operator of this app, and for once the user of the story. Every
  published day currently exists because they opened `/admin/daily_picks/new`, chose a
  painting, and saved. That is a hand-crank on a product whose one job is *daily*. The
  operator's own words, 2026-08-19: manual picking **"has become unsustainable."** Miss a
  day and the front door serves yesterday, dated yesterday.
- **Maya** — persona 1, CORE (`specs/personas.md`). Push → `/` → keep, one to three
  minutes. She never sees this feature; she sees its absence. A day the curator forgot is
  a broken streak on the surface the whole habit loop hangs on. This story makes her
  streak independent of the curator's calendar.
- **Amara** — persona 3, the range reader. Story 0019 spent real work making the pool
  wide (2,000 works, range floors, region bars). A picker that clumps — three Rembrandts
  in a week, a fortnight of Dutch interiors — spends that work down at the one surface
  readers actually meet the pool on. The selection policy exists for her.
- Not in this story: Jordan (favorites untouched), Tomás (artist pages untouched),
  Priya/Zoe (Phase 3 gate).

## Problem

**The daily product has a daily manual dependency.** `DailyPick` rows are created only by
the admin form (`app/controllers/admin/daily_picks_controller.rb`). The publish side is
already automatic — `DailyPick.published` is date arithmetic, `current` falls back to the
last published day — but the *supply* side is a human. `config/deploy.yml:115` has been
carrying the IOU explicitly: *"Solid Queue: no job needs it yet… CLAUDE.md says add it
with the job, not before."* This is that job. `CLAUDE.md`'s own pipeline line — *"curated
queue → daily publish job (Solid Queue)"* — named it in the Proven baseline from day one;
what shipped so far is the queue without the job.

The failure mode is already designed for and already bad: a skipped day is not an error
page, it is yesterday's art staying up, silently, until a human notices. The habit
mechanic (one of the two named moats) degrades exactly when the operator is busiest.

## Story

As **the curator**, I want the queue to fill itself days ahead of publication, so that
the app publishes daily whether or not I showed up, and my time goes to writing notes —
the part only I can do — instead of feeding the machine.

As **Maya**, I want a new artwork every single day, so that opening the app is never a
repeat and the streak the push notification promises is actually kept.

## Intake

- **Problem:** every published day requires a same-week manual admin action; supply is
  the only non-automated link in the daily chain.
- **Evidence:** **Direct operator report, 2026-08-19** — "an admin has to manually pick
  the day's painting… this has become unsustainable." First-party pain from the person
  doing the work, not a design-review inference. Corroborated by the architecture: the
  deploy file itself scheduled this story (`config/deploy.yml:115`), and CLAUDE.md's
  Proven baseline names the daily publish job as pipeline, not feature.
- **Success signal (prediction, falsifiable and time-bound):**
  1. **Within one day of deploy:** the queue holds a scheduled pick for today and the
     next 6 days with zero manual picks made after deploy; `bin/ci` green. **Falsified
     if** any of those 7 days is open after the recurring job has run.
  2. **Every day through Aug 31:** the front door serves a pick dated *today* (Eastern)
     with no admin action that day. **Falsified if** any day dawns unscheduled while the
     eligible pool is non-empty — checkable after the fact with one query over
     `daily_picks.scheduled_on`.
  3. **Spacing holds in production, measured not asserted:** over all auto-picked days, no
     artist repeats within 30 days and no culture runs two days straight, except where the
     relaxation ladder had to give way — and the row itself says so: the machine stamps
     the tier it filled at into `auto_tier` (eng review folded this out of log lines,
     which don't survive a Kamal redeploy). **Falsified if** the audit query finds a
     violation on a tier-1 row.
  4. **Moat tripwire, stated plainly, not a promise:** the buffer is only worth its extra
     machinery over morning-of picking (decisions/0015, D1) if the write-ahead window
     actually gets used. If by Aug 31 fewer than a third of auto-picked published days
     carry a hand-written blurb, the buffer is not protecting the voice — museum text has
     become the norm anyway, and D1 should be reopened with that number in hand.
     **Small-n caveat (eng review, outside voice):** at most ~10 auto-picked days will
     have published by Aug 31 — that read is directional only; the binding read is at 30
     auto-picked published days (~Sep 20), recorded in decisions/0015.
- **In baseline?** Yes — this *is* Proven-baseline pipeline: "curated queue → daily
  publish job (Solid Queue)." No exception argument owed. The one stack addition (Solid
  Queue) is pre-authorized by CLAUDE.md for exactly this unit of work.
- **R7 note.** Moves **0 of 5** `BET.md` thresholds by itself — no install, no post, no
  conversation comes from a cron job. What it changes is the cost side: it deletes a
  daily operator tax and it is the prerequisite half of the push moat (APNs push, when it
  arrives, needs a guaranteed fresh day to point at — a push into yesterday's art is worse
  than no push). Push itself is **not** in this story and the scoreboard stays 0/0/0/0/0,
  twelve days from kill review.

## Non-goals

- **APNs push.** Separate surface, separate spec. This story guarantees push will have
  something true to say; it does not say it.
- **AI-written blurbs.** BANNED in CLAUDE.md and not softened here. Auto-picked days with
  no note fall back to *museum* text, attributed as the museum's — the mechanism
  decisions/0004 already settled. The machine picks; it never speaks.
- **An admin-ordered priority queue** (D2 option c). Rejected in decisions/0015: the
  curator can already hand-place any future day through the existing form, which is the
  same power without a second ordering mechanism. If hand-sequencing runs become a real
  practice, that evidence reopens it.
- **Artist-string canonicalisation.** Spacing compares `artist_slug` as stored; Goya's
  four spellings are four "artists" to the rule, so the 30-day window is weaker than it
  looks for split names. Known, accepted, and owned by the canonicalisation idea already
  sitting in `IDEAS.md` Inbox — fixing attribution data inside a scheduling story would
  be scope theft.
- **A curation-quality scoring model.** Random-with-spacing is deliberately dumb. The
  pool was curated at intake (0013, 0019) — that is where taste lives. Re-ranking it at
  pick time is the aggregation trap wearing a scheduler's coat.
- **Backfilling historical gaps.** `first_open_date` starts at today; days that were
  missed before this shipped stay missed. The archive walk already steps over them.
