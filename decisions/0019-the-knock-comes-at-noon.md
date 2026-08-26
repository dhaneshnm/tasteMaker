# 0019 — The knock comes at noon, once, or not at all

Date: 2026-08-26
Trigger: story 0010 (`specs/0010-the-single-knock/`), plan header. Four calls bundled
— they are one shape: what the daily push is, when it fires, where a reader says yes,
and what happens when delivery is uncertain. Recorded under R4 before implementation.

## Position

1. **Noon ET, one clock.** The daily push fires at 12:00 America/New_York for every
   device — the hour the leader's corpus hands us ("I have the app timer set so that
   at noon every day I get my DailyArt notification"), seven hours after the 05:00 ET
   queue fill guarantees the day exists. Per-device local-time delivery is named
   infrastructure for later: real scheduling work, zero users, no evidence of non-US
   installs. The app already clocks everything Eastern (`TZ` in `deploy.yml`); the
   push joins that clock rather than growing its own.
2. **`apnotic` enters the Gemfile.** APNs over HTTP/2 with `.p8` token auth built in.
   The alternative is hand-rolled JWT + net-http2 — more code to review, no gain.
   One-line stack deviation, recorded here per the stack rule.
3. **The invitation lives on `/you`, and only there.** The reader's corner is the one
   page that is already about them. No launch prompt, no banner on the daily page,
   no modal — the iOS permission dialog fires only after a deliberate tap. The
   category trains readers to tap "Don't Allow"; Maya allows this app's notification
   because it asks politely. The opt-in surface is part of the product's manners.
4. **At-most-once delivery.** The job claims the day (`daily_picks.notified_at`,
   atomic compare-and-set) before sending. A process death mid-send means some
   devices miss a day; a claim-after-send would mean a double-fired scheduler knocks
   twice. A missed knock is a quiet failure with a monitoring trail; a double knock
   is the spam pattern this story exists to not be. Chosen, not defaulted.

## Falsifiable predictions

1. **By Aug 28:** a real push delivered to the physical iPhone via APNs sandbox,
   screenshot in `SHIPLOG.md`; the suite proves one-knock-per-day (second same-day
   run sends zero) and prune-on-410. **Falsified if** the receipt slips past Aug 28 —
   then the ≤ 2-day lane was wrong and the kill review reads it that way.
2. **No day ever knocks twice.** The `notified_at` claim makes it structurally
   impossible; the stamp is the audit. **Falsified if** a day shows two send passes —
   that is a claim-logic bug, fixed before anything else ships.
3. **By Sep 30:** no reader conversation names the delivery hour as wrong for their
   timezone. **Falsified if** one does — then per-device local time gets its own
   story on that evidence, and this entry is amended, not silently outgrown.

## Costs, named

Non-US readers get the knock at their local off-hours until prediction 3 fails —
accepted while installs are zero and the ASO bet is US-English keywords. A missed
day under at-most-once is invisible to readers (no "sorry" push — that would be a
second knock); the `notified_at` gap is the operator's tripwire, same philosophy as
`/queue-health`.
