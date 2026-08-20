# 0021 — The standing order — implementation plan

Date: 2026-08-19 (eng-reviewed same day; all findings folded)
Story: `story.md` in this directory.
Direction decisions: `decisions/0015-the-machine-picks-the-curator-speaks.md`
(D1: rolling 7-day buffer, not morning-of. D2: random + spacing rules, not pure random,
not an ordered queue). Amendments from review recorded there and in `decisions/0004`.

Design review: **skipped — UI-light** (build flow step 3 allows it; the UI change is a
few cells and one hint line on an existing admin table). Eng review: **done 2026-08-19**
— 6 findings across sections plus 7 accepted outside-voice findings, all folded below;
see the GSTACK REVIEW REPORT at the end of this file.

## Shape

One recurring job, once a day, that tops the queue up until **today + 6 days** are all
scheduled. Everything else — publish, rollover, fallback, museum-text attribution — already
exists and is not touched. The public site cannot tell this story shipped, except for one
new deliberately boring endpoint: `/queue-health`, the dead man's switch.

```
05:00 ET daily                      DailyPick.auto_fill!(horizon: 7)
Solid Queue recurring ──▶ FillQueueJob ──▶ loop: first_open_date inside horizon?
                                             └─ pick candidate (spacing rules)
                                             └─ create!(auto_tier: 1..4, blurb: nil)

external monitor ──▶ GET /queue-health ──▶ 200 "scheduled through <date>"
 (free uptime ping)                        503 when today unscheduled or < 2 days ahead
```

The curator's existing form keeps full authority, with the interaction rule stated
plainly (outside voice O7): **swap-in-place is the veto** — replacing an auto pick's
painting rejects the machine's choice and the date stays filled. **Destroy is a
re-roll** — the machine refills that date at the next 05:00, possibly with the same
painting (no rejected-memory; that idea sits in `IDEAS.md` Inbox, evidence-gated).
The destroy flash says so, so the curator is never surprised.

## Steps

### 1. Solid Queue enters the stack (pre-authorized)

- `gem "solid_queue"` + `bin/rails solid_queue:install`.
- Separate SQLite database `queue` in `config/database.yml`, its file under
  `/rails/storage` — the one Kamal volume (`config/deploy.yml`, `tondo_storage`). A queue
  db outside the volume is wiped every deploy: survivable for this job, still wrong.
- Production: `config.active_job.queue_adapter = :solid_queue`,
  `config.solid_queue.connects_to = { database: { writing: :queue } }`.
- **Single VPS, no second container:** run the supervisor inside Puma. Two lines that
  must be resolved together (eng review, outside voice O2 — verified before planning):
  - `config/puma.rb`: `plugin :solid_queue if ENV["SOLID_QUEUE_IN_PUMA"] == "true"` —
    the explicit string compare, never a truthy check: Kamal env values are strings, so
    `if ENV[...]` is true even when the value is `"false"`.
  - `config/deploy.yml:88` **already carries `SOLID_QUEUE_IN_PUMA: false`** — flip it to
    `true`. Left as-is, the job is dead in production and step 7's hand-run of
    `auto_fill!` would mask it (success signal 1 would pass with the scheduler dead).
- Delete the IOU comment at `config/deploy.yml` ~115 — it has been paid.
- Dev stays on the async adapter; test uses the `:test` adapter. The job's behavior is
  tested through the model method, not through queue plumbing.

### 2. Migration: provenance + audit in one column

`add_column :daily_picks, :auto_tier, :integer` — nil = hand-picked, 1–4 = machine pick
stamped with the relaxation tier that produced it (eng review finding 1: an integer, not
the originally planned `auto` boolean + log lines).

Why a column and why the tier is IN it: "blurb absent" does not mean "machine picked",
and Kamal container logs do not survive a redeploy — an audit that lives in
`Rails.logger` is an audit that evaporates before the kill review. With the tier on the
row, story success signal 3 and the decisions/0015 tripwire are each one durable query.
R1: the measurement ships with the artifact, in the schema.

### 3. Selection: `DailyPick.auto_fill!(horizon: 7)`

Lives on `DailyPick` next to `first_open_date` — the model already owns "which paintings
may have a day."

- Loop: while `first_open_date < Date.current + horizon`, create one pick for that date.
  The unique index on `scheduled_on` is the race guard; `RecordNotUnique` on a double-run
  is caught and treated as "someone else filled it" (Solid Queue is enqueue-once, not
  run-once — job bodies must tolerate firing twice).
- **Candidates:** paintings not spoken for, with a description (`blurb: nil` means the
  day must have museum text — validation `day_must_have_something_to_read` enforces it,
  the scope pre-filters it), and with a displayable image. Candidates are tried in
  SQL-random order and saved through the full validations; an invalid candidate is
  skipped, never force-inserted — the validations stay the single authority on what a
  publishable day is.
- **One home for "spoken for" (eng review finding 5):** extract the exclusion
  `selectable_paintings` already builds (`daily_pick.rb:74`) into a shared scope
  (e.g. `DailyPick.spoken_for`); `selectable_paintings` and the candidate scope both
  consume it. The model's own comment promised this rule one home — the third copy the
  original draft would have written is the miss. Regression pin: existing
  `selectable_paintings` behavior unchanged (test).
- **Spacing rules (D2), applied as exclusions on the candidate scope:**
  - **Artist key = `artist_slug`, falling back to the raw `artist` string when the slug
    is nil** (outside voice O3, verified: `Painting.artist_slug_for` returns nil for
    every `NOT_AN_ARTIST` placeholder — keying on slug alone would exempt all
    placeholder-attributed works from the artist rule and let anonymous China/Japan
    works legally clump for weeks). Only a fully blank `artist` is exempt. No repeat of
    the key within 30 days either side of the target date — both directions; the queue
    has a future.
  - No `culture` equal to the adjacent scheduled days' culture (skip the rule when
    either side is blank).
- **Relaxation ladder — a day always fills, and the row remembers how:**

  ```
  tier 1: artist ±30d  + culture adjacency     ← the intended policy
  tier 2: artist ±30d                          ← culture rule dropped
  tier 3: artist ±7d                           ← window shrunk
  tier 4: any eligible painting                ← pool nearly spent
  (empty at tier 4: pool exhausted → error log, stop filling;
   `current`'s last-published-day fallback is the graceful floor)
  ```

  The chosen tier is stamped into `auto_tier` (step 2). This diagram also lands as a
  comment block above `auto_fill!` in the model (eng review finding 6) — the house
  already writes its non-obvious decision structures into the file
  (`daily_pick.rb:8-12`), and "why did Tuesday repeat a culture" gets answered where
  the reader is.
- **Provenance stays honest under curator edits (eng review finding 4 + outside voice
  O4):** `before_update { self.auto_tier = nil if painting_id_changed? || scheduled_on_changed? }`.
  Swapping the painting is a human pick; moving the date breaks the spacing guarantees
  the tier vouches for — either way the row stops claiming the machine's placement.
  Blurb edits leave the tier alone: tier records who *picked*, `hand_written?` records
  who *spoke*.
- Randomness: `ORDER BY RANDOM()` is fine at 2,000 rows in SQLite; tests seed via a
  deterministic candidate-ordering seam, not by stubbing the RNG globally.

### 4. `FillQueueJob` + recurring schedule

- Job is a thin shell: `DailyPick.auto_fill!`. All logic stays on the model where the
  console and tests can reach it without queue plumbing.
- `config/recurring.yml` (production): daily at **05:00 America/New_York** — after the
  Eastern rollover the whole app clocks on (`config/application.rb:54`), before any human
  morning. Exact fugit/cron syntax for the timezone verified at implement time.
- **Stated plainly (outside voice O5): the YAML test proves syntax, not scheduling.** A
  parse-and-constantize test cannot prove the supervisor actually fires inside the Puma
  plugin. The real checks are production checks: the next-morning receipt in step 7 and
  the `/queue-health` monitor in step 6, which turns "scheduler quietly dead" into an
  alert within days instead of a stale front door discovered by accident.
- Missed runs self-heal: `first_open_date` starts at `Date.current`, so a job that was
  down for three days fills today first, then forward. No backfill of the past, ever.

### 5. Admin queue: seeing the machine's work

`admin/daily_picks#index` gains, on the existing table and hint pattern — no new screens:

- **Queue-depth line** (eng review finding 2): "scheduled through <date> (N days
  ahead)", styled with the existing `is-off-target` class when N < 2. The failure is
  visible on the exact page the write-ahead workflow brings the curator to.
- **auto marker** on machine-picked rows (`auto_tier` present) — which days nobody chose,
  at a glance.
- **museum-text marker** on any *future* row with no blurb — the write-ahead window only
  functions if blurbless upcoming days are visible without opening each one.
- **The 0004 banner splits its denominators** (eng review finding 3, verified against
  `index.html.erb:16-24`): the existing "N of M published days are running museum text /
  under 20%" line now counts **hand-picked days only** — that is the population
  decisions/0004's bet was made about. A second line reports auto-picked published days
  against decisions/0015's one-third-blurb tripwire. Without the split the banner goes
  permanently red within weeks and a still-open bet reads as falsified by regime change.
  Amendment paragraphs land in `decisions/0004` and `decisions/0015` with this story.
- **Destroy flash for future auto picks** (outside voice O7): "Removed — the machine
  refills this day tomorrow morning. Swap the painting instead to overrule it." Deleting
  is a re-roll, not a veto, and the UI says so at the moment it matters.

Editing an auto pick's blurb, swapping its painting, or deleting it already works
through the existing actions untouched (tier behavior per step 3's callback).

### 6. `/queue-health` — the dead man's switch (outside voice O1)

The buffer deletes the curator's daily reason to look, which deletes the only failure
detector the manual regime had. Error tracking is still unwired (session gate 6), so
this story ships its own minimal detector:

- `GET /queue-health`, public, no auth, `Cache-Control: no-store`. Body is one line and
  leaks nothing but dates: `ok — scheduled through 2026-08-27 (7 days ahead)`.
- **200** when today is scheduled and ≥ 2 future days exist; **503** otherwise. The 2-day
  floor means a dead scheduler alerts ~5 days before the front door ever staled.
- Deploy step points a free external uptime monitor (UptimeRobot-class, 5-minute setup,
  no new code) at it; the monitor's email is the alert channel. Named plainly: this is
  the R1 enforcement for the "scheduler dies silently" failure mode — an admin hint line
  alone only works if the curator keeps visiting, and this feature's success is that
  they can stop.

### 7. Tests (with the work, not after — R1)

Model (`auto_fill` coverage):
- fills exactly to horizon; idempotent on a second run same day; `RecordNotUnique`
  mid-loop treated as filled, loop continues;
- never overwrites or shifts an existing hand pick; hand pick mid-horizon → machine
  fills around it;
- skips paintings without description / without image; spoken-for exclusion shared —
  **regression pin: `selectable_paintings` returns the identical set before and after
  the scope extraction**;
- artist spacing holds both directions; **placeholder-artist works (nil slug) space by
  raw artist string — two "China" works cannot land 10 days apart**; blank artist
  exempt; culture rule holds; blank culture skips;
- ladder relaxes in order; **stamped `auto_tier` VALUES asserted per tier (1 vs 2 vs 3
  vs 4)** — the stamp is the audit instrument, an untested stamp is an untested
  instrument; exhausted pool logs and stops without raising;
- job down 3 days → next run fills today first, never a past date;
- `before_update` callback: painting swap clears tier, date move clears tier, blurb
  edit keeps it.

Job/schedule:
- `FillQueueJob` performs → queue filled (through the `:test` adapter);
- `recurring.yml` parses, task references a resolvable class (syntax only — see step 4's
  honesty note).

Controller/integration:
- `/queue-health`: 200 with today scheduled + buffer; 503 when today unscheduled; 503
  when < 2 days ahead; `no-store` header present;
- an auto-picked published day renders `daily/show` with museum attribution
  (`hand_written?` false path) — the one reader-visible surface this story could break.

Admin (existing controller/system tests extended):
- depth line shows and goes off-target below 2 days; auto marker on tier rows; future
  museum-text marker; split banner counts hand-picked days against 20% and auto days
  against one-third; destroy flash carries the re-roll wording.

`bin/ci` green before QA. Then build flow 6–9: `/qa`, `/simplify`, `/code-review`,
re-verify, ship with SHIPLOG receipt.

### 8. Deploy + smoke (receipt for success signal 1)

- Deploy via Kamal (operator runs it — agent shell lacks secrets). Confirm
  `SOLID_QUEUE_IN_PUMA: true` shipped and the queue db file sits under
  `/rails/storage` on the volume.
- Prod console: eligible-pool count recorded into this file's Deviations; run
  `DailyPick.auto_fill!` once by hand rather than waiting for 05:00.
- **Next morning, the receipt that actually proves the schedule** (the hand-run above
  cannot): today's pick exists with `auto_tier` set and `created_at` ≈ 05:00 ET.
  Recorded in Deviations.
- Point the external monitor at `/queue-health`; confirm one green check and one
  test-fired alert (monitor's own test button). 7 days scheduled, admin markers visible.

## Risks, named

- **Museum text becomes the norm** — the amended D1 tripwire owns this;
  `auto_tier` makes it measurable, and the small-n caveat is written into
  decisions/0015 (outside voice O6): the Aug 31 read is directional on n≈10; the
  binding read is at 30 auto-picked published days (~Sep 20).
- **Split artist names weaken spacing** (Goya × 4 spellings). Accepted in story
  non-goals; owned by the canonicalisation Inbox idea. The placeholder-key fallback
  (step 3) closes the worse half of this hole.
- **Solid Queue inside Puma couples job uptime to web uptime.** On one VPS they share a
  box anyway; `/queue-health` is the detector either way. Revisit only if a job ever
  needs to outlive a deploy window.
- **Pool exhaustion** is ~5.5 years away at 2,000 works; the error log line plus the
  health endpoint's buffer floor are the alarm, not a feature.

## NOT in scope (considered, deferred, with reasons)

- **APNs push** — separate surface, own spec; this story guarantees push will have
  something true to say.
- **Error tracking / analytics (session gate 6)** — own unit of work before first
  external user; `/queue-health` is deliberately the minimal detector, not a substitute.
- **Rejected-memory for machine picks** (destroy = re-roll may repeat a painting) —
  `IDEAS.md` Inbox, promoted only if re-rolls annoy in practice.
- **Admin-ordered priority queue** — rejected in decisions/0015; hand-placing any future
  day is the same power.
- **Artist-string canonicalisation** — in Inbox, owns the split-name weakness.
- **AI-written blurbs** — BANNED, unchanged.
- **Backfilling historical gaps** — archive walk already steps over them.

## What already exists (reused, not rebuilt)

- `DailyPick.first_open_date`, uniqueness indexes, all validations — the fill loop's
  entire safety net; reused as-is.
- `published` / `current` / last-published-day fallback — the graceful floor for every
  failure mode; untouched.
- `selectable_paintings`'s spoken-for exclusion — extracted to one shared scope, not
  copied (finding 5).
- Museum-text fallback + attribution (decisions/0004 mechanism) — auto days ride it
  unchanged.
- Admin queue table, hint/off-target styles, museum-text banner — extended in place,
  no new screens.
- `config.time_zone = "America/New_York"` — the one clock everything already agrees on.

## Deviations

Implemented per plan through `bin/ci` green (commit `5681596`), then `/simplify`
(`7a830cc`) and `/code-review` (`fb67cf7`) each found real issues folded back in.
Everything below is a deviation from what the eng-reviewed plan specified, not from
what shipped — the shipped shape is this section plus the plan above.

- **`exclude_unless_null` helper introduced by `/simplify`, then reverted by
  `/code-review`.** The simplify pass collapsed the two NOT-IN-OR-NULL SQL
  exclusions in `candidates_for` into one shared private method taking the column
  expression as a parameter. Brakeman then flagged it as a possible SQL injection:
  passing the column SQL through a method argument is exactly the shape its static
  analysis can no longer prove is always a hardcoded constant, even though both
  call sites only ever pass `ARTIST_KEY_SQL` or the literal `"paintings.culture"`.
  Reverted to two inline calls (six duplicated lines) rather than add a scanner
  suppression file — the code stays provably safe by inspection, which was judged
  worth more than the DRY win.
- **`DailyPick.queue_healthy?(today_scheduled:, days_ahead:)` — not in the
  eng-reviewed plan.** Code review's adversarial pass found that the admin
  queue-depth hint and `/queue-health` computed "is the queue okay" two different
  ways: the admin hint only ever checked buffer depth (`@days_scheduled_ahead`),
  never whether *today itself* had a pick. A curator deleting today's already-
  published pick — an ordinary action, not a machine-pick re-roll — would see the
  admin hint read clean (future days still buffered) while `/queue-health` was
  already returning 503 and the front door was serving yesterday's painting. The
  plan's own `LOW_BUFFER_DAYS` sharing (from the simplify pass) made the *number*
  agree between the two surfaces; it didn't make the *predicate* agree. Fixed with
  one shared class method both consumers call, taking already-known inputs so
  neither caller pays for an extra query it didn't already need.
- **`fill_one!`'s `RecordNotUnique` rescue was under-specified.** The plan's
  text ("treated as 'already handled'") didn't account for `daily_picks` carrying
  *two* unique indexes, not one — `scheduled_on` and `painting_id`. A collision on
  `painting_id` (two concurrent runs claiming the same painting for different
  dates) left the target date still open while the original code returned `true`
  anyway, silently discarding a valid candidate and reporting false progress. Now
  checks `exists?(scheduled_on: date)` before deciding whether to stop trying this
  date or move to the next candidate. Not directly testable in this suite (see the
  comment above the rescue and the test file) — Rails' uniqueness validation
  always runs a SELECT before every INSERT, so a single-connection test can only
  ever hit `RecordInvalid` first; the real trigger needs two Solid Queue runs
  racing on separate connections, which transactional fixtures structurally can't
  construct. Stated plainly rather than papered over with a misleading test.
- **Two test gaps the plan's own coverage diagram didn't catch, found by the
  code review's testing specialist:** every ladder test either resolved at tier 1
  or fell straight to tier 4 (all used horizon 1-2, too short a gap for tier 3's
  7-day window to ever matter) — tier 3 was unverified. And `auto_fill!`'s actual
  default (`horizon: 7`, what `FillQueueJob` runs with in production) was never
  itself exercised — every test passed an explicit horizon. Both now have direct
  tests (`test/models/daily_pick_test.rb`).
- **QA pass found zero bugs** against a real dev server with the full 2000-painting
  seed (screenshots in `~/.gstack/qa-reports/`) — worth recording since it means
  every finding above surfaced from code review, not from exercising the UI.

## GSTACK REVIEW REPORT

| Review | Trigger | Why | Runs | Status | Findings |
|--------|---------|-----|------|--------|----------|
| CEO Review | `/plan-ceo-review` | Scope & strategy | 0 | — | — |
| Codex Review | `/codex review` | Independent 2nd opinion | 0 | — | Codex usage-limited until Sep 9; Claude subagent ran instead |
| Eng Review | `/plan-eng-review` | Architecture & tests (required) | 1 | CLEAR (PLAN) | 17 issues (3 arch, 3 quality, 11 test gaps, 0 perf), 0 critical gaps, all folded |
| Design Review | `/plan-design-review` | UI/UX gaps | 0 | — | Skipped: UI-light (build flow step 3), noted in plan header |
| DX Review | `/plan-devex-review` | Developer experience gaps | 0 | — | — |

- **CROSS-MODEL:** Outside voice (Claude subagent, fresh context) returned 8 findings: 7
  accepted and folded (deploy.yml:88 flag, nil-slug spacing key, date-move tier clear,
  dead-man `/queue-health`, recurring-test honesty note, small-n tripwire timing, veto
  semantics), 1 was agreement with the story's own R7 admission. One tension (admin
  depth line vs. structural silence) resolved in the outside voice's favor.
- **VERDICT:** ENG CLEARED — ready to implement.

NO UNRESOLVED DECISIONS
