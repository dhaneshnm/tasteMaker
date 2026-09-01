# 0022 — The note waits

Date: 2026-08-31. Context: story 0032 (`specs/0032-sit-with-it/`), the
guided-sit brainstorm's shape A, promoted from IDEAS.md the same day.

## Position

The front door hands the reader the reveal before the look. From story 0032
on, `/`'s note starts folded behind one quiet invitation and a soft, invisible
60-second minute; the reveal is always the reader's own tap and never locks.
Signed-in readers who let the minute complete get one optional line — ink,
write-once — that afterwards sits above the curator's note. The archive is
never gated. This is Better-bucket sequencing (the blurb gets a *when*), not
the New-slot differentiator; shapes B/C remain the slot's candidates.

Grounding: the owner's slow-looking protocol (`user-research/0010`, 5 sits,
avg 12 min, saturation endings) and four r/ArtHistory DM exchanges
(`user-research/0009`) — the scarce goods are structure and vocabulary, not
content. Sixty seconds is ~8% of the founder's own unaided average: a floor
for a novice whose failure mode is "seen it" at ninety seconds.

## Falsifiable predictions

1. **Dogfood (pre-live):** the gate survives 7 consecutive days of the
   owner's own morning open without reflexive early reveal. Reflexive skip
   every day = the invitation is wrong; rework before any reader sees it.
2. **Post-live:** within 14 days of the first 50 front-door opens, **≥ 20% of
   gates shown reach the completed minute** — measured as
   `completed / shown` from `sit_counters`, which ships WITH the gate (an
   unmeasurable prediction is an R1 violation; eng review OV6 closed it).
   Falsified → the gate reverts to default-off (one Stimulus default), and
   the revert is recorded here, not silently shipped.

**Timeline honesty (eng OV6b):** the app is not yet approved; "first 50
opens" almost certainly post-dates the Sep 30 kill review. This prediction
outlives the review that will read it — it informs the *next* bet, and its
non-resolution by Sep 30 is expected, not evidence either way.

## What would have been easier and was refused

Auto-unfolding at the minute (startles; robs the reveal of being an act);
a visible countdown (a clock on the calmest page); gating the archive
(hostility down a walk); AI-drafted invitation copy shipped unreviewed
(editorial voice is the moat — the draft in the view is marked for the
owner's field-by-field pass, story-0010 precedent).

## Amended 2026-09-01 — the prompt replaces the minute

Owner decision, taken consciously after a day of dogfooding the shipped gate
and three rounds of mocks: the invisible 60-second minute is gone. In its
place, **one looking prompt from the protocol's own rotation**
(`DailyPick::SIT_PROMPTS`, app-scaled from `user-research/0010`'s P1/P2/P3/P5
plus the first-impression move) greets every reader; a signed-in reader
answers on an autosaving line (no Save button — the SAVED whisper is the only
acknowledgment); READ THE NOTE is gold from the first paint and never locks.

Consequences, all deliberate:
- **Write-once is amended:** the answer is a DRAFT that follows the reader's
  typing until the reveal makes it ink. Enforcement is UI-level (the field
  never renders after the reveal); the server permits a reader to rewrite
  their own 280 characters — the worst a hand-rolled request wins.
- **The prompt is stamped on the answer** (`impressions.prompt`), so which
  prompts produce the most writing — the protocol's own seed-order question —
  reads straight off the table.
- **The metrics re-base:** `shown` still counts gates displayed; the second
  counter now records **reveals** (first note-open of the day). Answers per
  day come from the impressions table directly. Prediction 2 is restated:
  measured as revealed/shown plus answers/shown once the first 50 opens
  exist; the timeline honesty note stands unchanged — this resolves after
  Sep 30 and informs the next bet.
- Prediction 1 (the 7-day dogfood without reflexive skip) carries over with
  "reflexive skip" now meaning tapping READ before the prompt has been given
  a moment at all.
