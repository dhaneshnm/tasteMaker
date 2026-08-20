# 0015 — The machine picks, the curator speaks

Date: 2026-08-19
Spec: `specs/0021-the-standing-order` (story + plan written this session).

Position: daily-pick supply goes automatic — a recurring Solid Queue job keeps the queue
filled **7 days ahead** (D1a), choosing **randomly with spacing rules** (D2a: no artist
repeat within 30 days, no culture two days running, with a relaxation ladder so a day
always fills). Direction-level because it adds a gem to the stack (pre-authorized by
CLAUDE.md for exactly this job), permanently changes who chooses the day's artwork, and
moves the editorial-voice moat from "curator picks and speaks" to "machine picks, curator
speaks when they choose to."

## The forks and why

**D1 — buffer, not morning-of.** Operator report 2026-08-19: manual daily picking is
unsustainable. Morning-of picking (rejected) is the smaller job but leaves zero window to
write a note before publish — museum text becomes the norm by construction, which spends
one of the two named moats to save one cron schedule's worth of code. The 7-day buffer
keeps the write-ahead window and costs one loop. Museum-text fallback on unwritten days
was already settled by decisions/0004 and is unchanged here.

**D2 — random + spacing, not pure random, not an ordered queue.** Pure random (rejected)
clumps: Rembrandt holds 42 works in the pool; runs are a when, not an if, and they spend
0019's range work on the one surface readers meet the pool. An admin-ordered priority
queue (rejected) rebuilds authority the curator already has — the existing form hand-places
any future day, and a hand pick beats the machine by existing first. Ordering machinery
without evidence of a hand-sequencing practice is infrastructure for later.

**What the machine never does:** write. AI-generated descriptions stay BANNED; auto days
with no note run *museum* text under the museum's attribution, the same as a hand-picked
blurbless day today.

## Prediction (falsifiable, time-bound)

1. **Every calendar day from deploy through Aug 31, 2026 publishes a pick dated that day
   (Eastern) with zero same-day admin action.** Falsified by one query over
   `daily_picks.scheduled_on` showing a gap while eligible paintings existed.
2. **Tripwire on the moat trade:** if fewer than a third of auto-picked *published* days
   carry a hand-written blurb, the buffer bought nothing over morning-of — reopen D1 with
   that number rather than defending the extra machinery. Measurable because the plan
   ships an `auto_tier` provenance column with the feature (R1).

## Amendments — eng review, 2026-08-19 (same day)

- **`auto` boolean became `auto_tier` integer** (nil = hand, 1–4 = relaxation tier the
  machine filled at). Reason: the audit for prediction 1's spacing rules originally
  lived in `Rails.logger`, and Kamal container logs do not survive a redeploy — the
  instrument would have evaporated before the kill review. Tier-on-the-row makes both
  predictions one durable query each.
- **Provenance clears when a curator swaps the painting or moves the date** on a machine
  pick (human re-pick / spacing no longer vouched for); blurb edits keep it. Without
  this, the tripwire's denominator counts curator choices as machine picks.
- **Small-n timing on the tripwire (outside voice):** at most ~10 auto-picked days
  publish by Aug 31 — a third of 10 is noise. The Aug 31 read is directional; the
  **binding read is at 30 auto-picked published days (~Sep 20, 2026)**.
- **decisions/0004's 20% museum-text bet keeps its original population:** the admin
  banner now counts hand-picked days only against 0004's 20%, and auto-picked days
  against this decision's one-third tripwire. Auto-fill makes museum-text days the
  default output of a *correct* system; unsplit, the 0004 receipt would read as
  falsified by regime change rather than by evidence. Cross-amendment recorded in
  `decisions/0004`.
