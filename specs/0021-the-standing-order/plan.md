# 0021 — The standing order — implementation plan

Date: 2026-08-19
Story: `story.md` in this directory.
Direction decisions: `decisions/0015-the-machine-picks-the-curator-speaks.md`
(D1: rolling 7-day buffer, not morning-of. D2: random + spacing rules, not pure random,
not an ordered queue).

Design review: **skipped — UI-light** (build flow step 3 allows it; the only UI change is
two markers on an existing admin table). Eng review: required before implementation.

## Shape

One recurring job, once a day, that tops the queue up until **today + 6 days** are all
scheduled. Everything else — publish, rollover, fallback, museum-text attribution — already
exists and is not touched. The public site cannot tell this story shipped.

```
05:00 ET daily                      DailyPick.auto_fill!(horizon: 7)
Solid Queue recurring ──▶ FillQueueJob ──▶ loop: first_open_date inside horizon?
                                             └─ pick candidate (spacing rules)
                                             └─ create!(auto: true, blurb: nil)
```

The curator's existing form keeps full authority: any future day can still be hand-placed,
edited, swapped, or destroyed. The job only fills days that are *open* — it never touches
an existing row, so a hand pick always wins over the machine by simply existing first.

## Steps

### 1. Solid Queue enters the stack (pre-authorized)

- `gem "solid_queue"` + `bin/rails solid_queue:install`.
- Separate SQLite database `queue` in `config/database.yml`, its file on the same
  persistent-volume path as the primary db (`config/deploy.yml` volume — verify the
  mounted path at implement time; a queue db outside the volume is wiped every deploy,
  which for this job is survivable but wrong).
- Production: `config.active_job.queue_adapter = :solid_queue`,
  `config.solid_queue.connects_to = { database: { writing: :queue } }`.
- **Single VPS, no second container:** run the supervisor inside Puma
  (`plugin :solid_queue` in `puma.rb`, gated to production / `SOLID_QUEUE_IN_PUMA`).
  Kamal stays one app server. Update `config/deploy.yml` and **delete the IOU comment at
  line ~115** — it has been paid.
- Dev stays on the async adapter; test uses the `:test` adapter. The job's behavior is
  tested through the model method, not through queue plumbing.

### 2. Migration: provenance

`add_column :daily_picks, :auto, :boolean, null: false, default: false`

Why a column and not inference: "blurb absent" does not mean "machine picked" — a curator
can hand-pick without writing, and can write on top of a machine pick. Success signal 3
and the D1 tripwire (share of auto days that got a note) are unanswerable without
provenance, and R1 says the measurement ships with the artifact.

### 3. Selection: `DailyPick.auto_fill!(horizon: 7)`

Lives on `DailyPick` next to `first_open_date` and `selectable_paintings` — the model
already owns "which paintings may have a day."

- Loop: while `first_open_date < Date.current + horizon`, create one pick for that date.
  The unique index on `scheduled_on` is the race guard; a `RecordNotUnique` on a
  double-run is caught and treated as "someone else filled it," not an error.
- **Candidates:** paintings not in `daily_picks` (mirrors the existing uniqueness rule),
  with a description (`blurb: nil` means the day *must* have museum text to read —
  validation `day_must_have_something_to_read` enforces it, the scope pre-filters it),
  and with a displayable image. Candidates are tried in SQL-random order and saved through
  the full validations; an invalid candidate is skipped, not force-inserted — the
  validations stay the single authority on what a publishable day is.
- **Spacing rules (D2), applied as exclusions on the candidate scope:**
  - no `artist_slug` that appears in a pick within 30 days either side of the target date
    (both directions — the queue has a future); paintings with no artist are exempt from
    this rule, and the deny-listed placeholder "artists" are just strings here, no page
    logic involved;
  - no `culture` equal to the adjacent scheduled days' culture (skip the rule when either
    side is blank).
- **Relaxation ladder — a day always fills:** tier 1 both rules → tier 2 drop the culture
  rule → tier 3 artist window shrinks 30→7 days → tier 4 any eligible painting. Every
  fill above tier 1 writes one structured log line (`Rails.logger.info`) naming the date
  and the tier — that line is what success signal 3 audits against. If tier 4 is empty,
  the pool is exhausted: log at error level and stop filling; `current`'s
  last-published-day fallback is the graceful floor, same as today.
- Randomness: `ORDER BY RANDOM()` is fine at 2,000 rows in SQLite; tests seed via a
  deterministic candidate ordering seam, not by stubbing the RNG globally.

### 4. `FillQueueJob` + recurring schedule

- Job is a thin shell: `DailyPick.auto_fill!`. All logic stays on the model where the
  console and tests can reach it without queue plumbing.
- `config/recurring.yml` (production): daily at **05:00 America/New_York** — after the
  Eastern rollover the whole app clocks on (`config.time_zone`,
  `config/application.rb:54`), before any human morning. Exact fugit/cron syntax for the
  timezone verified at implement time, and asserted by a test that parses the file and
  resolves the class name (R1: the schedule is an artifact, so a check owns it).
- Missed runs self-heal: `first_open_date` starts at `Date.current`, so a job that was
  down for three days fills today first, then forward. No backfill of the past, ever.

### 5. Admin queue: seeing the machine's work

`admin/daily_picks#index` gains two cell-level markers, no new screens:

- **auto** on machine-picked rows — the curator can tell at a glance which days nobody
  chose;
- **museum text** on any *future* row with no blurb — the write-ahead window is the whole
  point of D1a, and it only functions if blurbless upcoming days are visible without
  opening each one.

That is the entire UI. Editing an auto pick's blurb, swapping its painting, or deleting
it already works through the existing actions untouched. (`auto` stays true when a
curator writes a blurb on a machine pick — provenance records who *picked*, and
`hand_written?` already records who *spoke*.)

### 6. Tests (with the work, not after — R1)

Model (`daily_pick_test` or a dedicated `auto_fill_test`):
- fills exactly to horizon; idempotent on a second run same day;
- never overwrites or shifts an existing hand pick; hand pick mid-horizon → machine fills
  around it;
- skips paintings without description / without image; mirrors the one-day-per-painting
  rule;
- artist spacing holds in both directions; culture rule holds; blank artist/culture exempt;
- ladder relaxes in order and logs the tier; exhausted pool logs and stops without raising;
- picks are created with `auto: true, blurb: nil` and publish with museum attribution
  (ties into the existing `hand_written?` paths).

Job/schedule:
- `FillQueueJob` performs → queue filled (through the `:test` adapter);
- `recurring.yml` parses, task references a resolvable class.

Admin (existing controller/system tests extended):
- index shows the auto marker and the future-blurbless marker; hand rows show neither.

`bin/ci` green before QA. Then build flow 6–9: `/qa`, `/simplify`, `/code-review`,
re-verify, ship with SHIPLOG receipt.

### 7. Deploy + smoke (receipt for success signal 1)

- Deploy via Kamal (operator runs it — agent shell lacks secrets).
- Prod console: eligible-pool count recorded into this file's Deviations; run
  `DailyPick.auto_fill!` once by hand rather than waiting for 05:00 — the recurring
  trigger still gets verified next morning against the log line.
- Verify: 7 days scheduled, queue db file sits on the volume, admin index shows the
  markers.

## Risks, named

- **Museum text becomes the norm** — the D1 tripwire in `story.md` intake owns this; the
  `auto` column is what makes it measurable.
- **Split artist names weaken spacing** (Goya × 4 spellings). Accepted in story non-goals;
  owned by the canonicalisation Inbox idea.
- **Solid Queue inside Puma couples job uptime to web uptime.** On one VPS they share a
  box anyway; a crashed app already means a down site. Revisit only if a job ever needs
  to outlive a deploy window.
- **Pool exhaustion** is ~5.5 years away at 2,000 works and shrinks only by one per day;
  the error log line is the alarm, not a feature.

## Deviations

(None yet — filled in during implementation.)
