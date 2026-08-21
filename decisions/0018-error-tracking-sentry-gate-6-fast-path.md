# 0018 — Error tracking (Sentry), and gate 6 taken fast-path rather than full

Date: 2026-08-21
Trigger: owner wants to submit to the App Store tonight. Session gate 6
(CLAUDE.md) requires backups + a logged restore test, error tracking, and
analytics-or-an-honest-label before the first external user. None of it
existed. Owner decision, recorded under R4 in the same session as the
submission push.

## Position

**Error tracking:** Sentry, free tier. `sentry-ruby` + `sentry-rails` land in
the same commit as the privacy-page disclosure and the `POLICY_UPDATED_ON`
bump — `test/integration/privacy_claims_test.rb` requires exactly this pairing
and would otherwise fail the build the moment the gem reached `Gemfile.lock`.
The "No third-party analytics" claim stays true and unedited: crash reporting
is not analytics — it only fires on an actual error, carries no behavioral
data, and is disclosed as its own thing.

**Backups:** `script/backup-db` — a live `sqlite3 .backup` inside the running
container, pulled to the operator's machine (offsite from the GCP disk,
closing the torn-WAL gap `decisions/0012` named), then opened and row-counted
locally. That last step is the restore test: the gate wants "one restore
actually performed," not a file that merely exists somewhere.

**Analytics:** still none, deliberately (`decisions/0005`). Gate 6 accepts
"analytics or an honest label" — the label already says so.

**What this fast-path explicitly does NOT do:** no rehearsed disaster-recovery
restore (spinning the backup up as a live replacement server), no alerting on
Sentry errors beyond the dashboard, no automated/scheduled backup cadence —
`script/backup-db` is run by hand. Full versions of each are still owed and
are not this decision's claim to have closed them.

## Prediction (falsifiable, time-bound)

**If `script/backup-db` is not run at least once before TestFlight goes out
tonight, or if Sentry receives zero events in its dashboard within 7 days of
submission, this fast-path was theater rather than a real gate-6 pass** — and
the next kill-review-adjacent session should say so rather than count it as
done. Also falsified if any future commit adds a tracking gem without editing
`app/views/pages/privacy.html.erb` and `PagesController::POLICY_UPDATED_ON` in
the same commit — `privacy_claims_test.rb` should catch that mechanically, but
the prediction is that a human catches it first because the test's failure
message is unambiguous.
