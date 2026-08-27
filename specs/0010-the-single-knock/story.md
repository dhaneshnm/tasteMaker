# 0010 — The single knock

Date: 2026-08-26
Lane: **Full (≤ 2-day core).** One migration (two columns), one recurring job, one
opt-in control on an existing page, one native registration path the stack already
pre-authorizes. No new screens.
Status: **Draft.** Branch `push-notifications`. Takes the WIP slot — 0027 shipped
2026-08-21 (`d96678e`, PR #8), slot open (R5).

Number 0010 was reserved for this story the day the shell shipped (`SHIPLOG.md`
2026-08-07: "it is story 0010 and it is not started") and again on submission day
(2026-08-25: "story 0010 (push) becomes the resubmission fix"). Not routed through
`IDEAS.md`: this is Proven baseline item 2, settled in `CLAUDE.md` since day one —
there is nothing to triage.

## Who

- **Maya** — persona 1, CORE. The push *is* her product:

  > "It's the only app I have that I allow notifications… the single, daily
  > notification."

  She does not browse; she answers the knock, reads 1–3 minutes, closes. Without
  the knock there is no Maya — the habit loop (daily push → open → favorite) is one
  of the two moats `CLAUDE.md` says survive in this category, and today it has no
  first link.
- **The reader who sets her own timer** — leader's corpus: "I have the app timer
  set so that at noon every day I get my DailyArt notification." Evidence for both
  demand and the hour.
- **App Review** — not a persona, but the named top rejection risk (`SHIPLOG.md`
  2026-08-25): guideline 4.2, a chrome-less web shell with no push. This story is
  the pre-named resubmission fix if 4.2 hits, and the strongest "more than a
  website" answer if it hasn't yet.
- Not in this story: Jordan (favorites untouched), curator (admin untouched),
  Amara/Tomás (browsing surfaces untouched).

## Problem

**Baseline item 2 is the only unbuilt Proven item, and it is the habit driver.**
Items 1, 3, 4 are shipped; 5 (free) holds by default. The app is in App Store
review with no mechanism that ever brings a reader back — the daily publish happens
at 05:00 ET into a queue nobody is told about. The category's willingness to pay is
zero and distribution decides everything; the one retention lever the corpus proves
readers *want* — a single, giving, daily notification — does not exist.

The user's ask, verbatim intent: **if a reader opts in, they get one push a day for
the daily art, on their iPhone.** Opt-in is load-bearing — Maya allows this app's
notification *because* it is the only one that asks politely and gives instead of
takes. A launch-time permission ambush is how the category's also-rans train
readers to tap "Don't Allow" forever.

## Story

As **Maya**, I want to say yes once to a single daily notification, and then have
each day's painting knock quietly — so the app comes to me, and tapping the knock
puts the art on my screen with nothing in between.

As the **owner**, I want the knock to be un-alarming and skippable to enable — so
the readers who opt in are readers who wanted it, and nobody's first session ends
in a permission dialog.

## What ships

1. **An invitation, not an ambush.** A short opt-in control on `/you` (the reader's
   corner — the one page that is already "yours"), rendered only inside the shell
   (`native_shell?`). Copy hand-written by the owner, editorial voice. The iOS
   system permission dialog appears only after the reader taps — never on launch,
   never unprompted.
2. **Native registration, the pre-authorized exception.** The shell requests
   authorization, registers with APNs, and POSTs the APNs token to the server
   against the existing device identity (story 0015's Keychain UUID). `CLAUDE.md`
   stack: "Accepted native exception: APNs push registration and delivery."
3. **One knock a day, at noon ET.** A Solid Queue recurring job (the 0023 idiom)
   sends today's pick to every opted-in device at 12:00 America/New_York — the hour
   the corpus hands us, seven hours after the 05:00 ET fill guarantees the day
   exists. One send per day, enforced by a durable stamp, not by hoping the
   scheduler fires once.
4. **The knock names the painting.** Notification copy is a hand-written template
   filled with the day's real title and artist — data slotted into owner-written
   words, no generated prose (CLAUDE.md ban stays intact). Tapping it opens the app
   on today's painting — the root screen — with nothing between push and art
   (Better bucket 4).
5. **Leaving is one tap.** The same control on `/you` turns it off (server forgets
   the token). APNs "unregistered" responses prune tokens automatically — deleted
   apps stop being knocked on without anyone filing a complaint.
6. **A day that isn't there doesn't knock.** If today has no published pick (the
   `/queue-health` 503 case), the job sends nothing. A silent day is a queue
   incident, already monitored; a push pointing at yesterday's art would be a lie.

## Intake

- **Problem:** above — the habit driver is unbuilt, the app is in review with the
  4.2 risk named, and no reader has a reason to return tomorrow.
- **Evidence:** `CLAUDE.md` settled facts (habit mechanics = surviving moat; daily
  push = Proven baseline item 2); persona corpus quotes above (`specs/personas.md`);
  `SHIPLOG.md` 2026-08-25 naming this story the resubmission fix; 0008's story,
  which justified the entire shell as "the carrier for baseline item 2."
- **Success signals (prediction, falsifiable, time-bound):**
  1. **By Aug 28:** `bin/ci` green. Job tests assert: exactly one send per day
     (second fire of the same day sends zero), zero sends when today is
     unscheduled, and an APNs "Unregistered/BadDeviceToken" response clears that
     device's token.
  2. **By Aug 28:** a real push received on the physical iPhone via APNs sandbox —
     screenshot receipt in `SHIPLOG.md`. Wrong if the receipt is a simulator
     screenshot or a unit test: delivery is the feature.
  3. **By Aug 29:** opt-in state round-trips — enable on device, `/you` shows it
     on, disable, server row's token is nil. System test + on-device check.
  4. **Not this story's gate:** opt-in rate and push-driven opens — zero installs
     exist; those numbers start when the app is released. First honest read at the
     kill review or after.
- **In baseline?** Yes — Proven item 2 itself. Not the New differentiator; the New
  slot stays unnamed.
- **R7 note:** moves **0 of 5** `BET.md` thresholds today (code is an input
  metric). What it buys: the habit moat's first link, and the pre-named answer to
  the one rejection risk standing between the app and threshold 1 — five days
  before the Aug 31 kill review.

## Non-goals

- **Per-device local-time delivery.** Noon ET, one clock, same as the whole app
  (Eastern rollover, `config/application.rb`). Per-timezone scheduling is real
  engineering with zero users to justify it — infrastructure for later, by name.
  Revisit on evidence of non-US installs.
- **Rich push (artwork image in the notification).** Needs a Notification Service
  Extension — a second target, a second signing surface. Park in `IDEAS.md`; the
  knock names the painting, the app shows it.
- **Re-engagement pushes, streaks, "you missed yesterday."** The take-not-give
  pattern Maya's quote is a vote against. Never without its own story and evidence.
- **A second daily push, badges, provisional/quiet delivery.** One knock. Zero
  badges — a count on the icon is homework.
- **Web push.** Reader surface is the shell; Safari web push is a different
  audience with no evidence.
- **In-app notification settings screen.** One toggle on `/you` is the whole UI.
- **Prompt-on-first-launch.** Named as a non-goal so it cannot creep in as a
  "growth" default later.

## Design constraints carried in

- Calm (Better bucket 4): opt-in copy sits inside `/you`'s existing quiet layout —
  no banner on the daily page, no modal, nothing between any push and any art.
- Editorial voice: invitation copy, toggle labels, and the notification template
  are **owner-written** (CLAUDE.md ban on generated editorial text). Implementation
  ships with placeholder-free real copy or it is not done.
- DESIGN rule 9: the toggle is a 44px target.
- `/you` stays gated and `private` (0015 wall untouched); the registration endpoint
  follows the existing `device/registrations` idioms (app secret, rate limit,
  idempotent create).

## Open for the plan

- Bridge mechanism for the opt-in tap: route interception (the shell's existing
  `RouteDecisionHandler` idiom) vs a Hotwire Native bridge component. Cheapest that
  fits the existing shell wins.
- Denied-at-system-level UX: what `/you` shows when iOS authorization is denied
  (likely: the invitation stays, a second tap deep-links to Settings).
- APNs environment split: sandbox (Xcode debug builds) vs production (TestFlight /
  App Store) — how the server sends to each during QA without polluting prod.
- Ship vehicle: new build on the in-review 1.0 vs 1.1 — owner call at ship time,
  depends on where App Review stands that day.
