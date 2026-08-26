# 0010 — The single knock — implementation plan

Date: 2026-08-26
Story: `story.md` in this directory.
Direction decisions: **`decisions/0019` to be written before implementation (R4)** —
four calls bundled: noon ET send time (not per-device local), `apnotic` gem enters the
Gemfile (stack rule: one-line reason committed), opt-in lives on `/you` (not the daily
page), at-most-once delivery semantics (a missed knock beats a double knock).

Design review: **skipped — UI-light** (build flow step 3; the UI is one toggle and two
owner-written lines on an existing page). Noted here per the flow. Eng review
(step 4): **done 2026-08-26** — 3 findings from the sectioned review + 13 accepted
outside-voice findings (Claude subagent; Codex usage-limited, third story running),
all folded into the steps below. See the GSTACK REVIEW REPORT at the end of this file.

## Shape

The story's whole surface area is: one native tap-to-permission path in, one recurring
job out. Everything between already exists — device identity (0015), the daily pick
and its Eastern rollover, Solid Queue with a recurring schedule (0023), the `/you`
page, Kamal secrets.

```
/you (shell only)                          iOS shell
  "invitation" link ── tap ──▶ PushRouteDecisionHandler intercepts
                                 └─ UNUserNotificationCenter.requestAuthorization
                                     ├─ denied  → open iOS Settings deep link
                                     └─ granted → registerForRemoteNotifications
                                                    └─ didRegister…deviceToken
                                                        └─ POST /device/push_registrations
                                                           (X-Tondo-App + device UUID + APNs token)
                                                            └─ reload /you → toggle shows ON

12:00 ET daily                DailyPushJob
Solid Queue recurring ──▶  today published? not yet knocked?
                              └─ claim notified_at (atomic)
                              └─ APNs HTTP/2 (apnotic, .p8 token auth)
                                   ├─ delivered → done
                                   └─ 410 Unregistered / 400 BadDeviceToken
                                        └─ device.apns_token = nil  (prune)
```

Notification tap → app cold/warm launch → root screen = today's painting. **Zero
routing code** — the default launch path already lands on the art, which is the
"nothing between push and art" bar met by doing nothing.

## Steps

### 0. Owner prerequisites — user actions, blocking, do first

- Apple Developer portal: create an **APNs Auth Key (.p8)** — note Key ID; Team ID is
  on the membership page. One key serves sandbox and production.
- App ID `app.tondo` (or actual bundle id): enable the **Push Notifications**
  capability; regenerate/refresh provisioning as Xcode demands.
- Secrets, gate-6 style: `.p8` contents + Key ID + Team ID into Rails credentials
  (`apns: key:, key_id:, team_id:`) and mirrored into Kamal secrets for deploy.
  Never a loose file in the repo. Agent shell lacks secrets access — owner runs the
  credential edits (`!` prefix), same as prior deploys.

### 1. Gem: `apnotic`

HTTP/2 APNs client with `.p8` token auth built in — the alternative is hand-rolling
JWT + net-http2, which is more code to review for zero gain. One line in
`decisions/0019` covers the stack addition. Dev/test never open a real connection
(injection, step 6).

### 2. Migration — three columns, no new tables

- `devices.apns_token`, string, nullable. Nil = not opted in. No index — the daily
  scan of a table this size is nothing, and the write path looks devices up by the
  existing `token_digest` index.
- `daily_picks.notified_at`, datetime, nullable. The durable one-knock-per-day claim
  stamp (R1: the receipt lives in the schema, the 0023 `auto_tier` lesson).
- `daily_picks.push_sent_count`, integer, nullable — stamped AFTER the send loop
  with how many pushes actually left. Eng review (outside voice #3): claim-before-send
  means `notified_at` audits "job claimed," not "pushes sent" — a revoked `.p8` would
  stamp every day and send nothing, gap-free. `notified_at` present + `push_sent_count`
  nil-or-0 is the real tripwire, and `/queue-health` reads it (step 6b).

### 3. Server — registration in, opt-out, prune

- **Shared idiom first (eng review finding 3):** extract a `NativeEndpoint` concern
  — `skip_forgery_protection`, the app-secret gate (`expected_app_secret` +
  `secure_compare`), and the pinned `MemoryStore` rate-limit idiom — included by
  `DeviceRegistrationsController` and the new controller. The 0023 DRY-reversal
  (kept duplication for Brakeman) does not apply: no SQL interpolation here.
- **`POST /device/push_registrations`** — native URLSession caller on the concern
  above, params `device_token` (Keychain UUID) + `apns_token` (explicit hex:
  `\A\h{16,200}\z`, String check — the F5 lesson) + **`mode`: `enroll` or
  `refresh`** (outside voice #1). `enroll` (the opt-in tap) does
  `find_or_create` on the digest (finding 2 — a revoked/wiped row must not 500;
  find_or_create matches the registration endpoint's idempotent philosophy) and
  sets the token. `refresh` (launch healing) **updates the token only where one is
  already present** — otherwise the healing path silently reverses a web opt-out
  on the next cold launch, because iOS authorization stays `.authorized` forever
  and nothing client-side knows the reader left. `refresh` with `enabled=false`
  (shell sees `.denied` in Settings) clears the token — closes the
  toggle-lies-forever hole (outside voice #8). `head :no_content` everywhere.
  Why not the device cookie: the shell's native URLSession is ephemeral and
  deliberately does not share the WKWebView jar (`DeviceIdentity` comment).
- **Opt-out from the web**: `DELETE /device/push_registration` (singular), normal
  Turbo form on `/you`, authenticated by the signed device cookie. **Clears by
  token value, not by row** — `Device.where(apns_token: current_device.apns_token)
  .update_all(apns_token: nil)` — because a device wipe re-mints the Keychain UUID
  and leaves a stale second row holding the same token; row-scoped opt-out would
  keep knocking the phone (outside voice #6).
- **Prune on send** (step 6): 410 `Unregistered` and 400 `BadDeviceToken` clear the
  token. Covers deleted apps and sandbox tokens that leak into prod.
- **Duplicate tokens**: send distinct tokens (`DISTINCT apns_token`) — one knock
  per phone, not per row.

### 4. `/you` — the invitation and the toggle

- Render only when `bridge_capable_shell?` **and** `native_shell_version` ≥ the
  first push-capable shell version (the 0017 lesson: capability and binary ship
  together; presence/threshold of the UA version IS the feature detection — no
  server flag). Older binaries and browsers see nothing. **The gate value is not
  free (outside voice #5): `Config/Shared.xcconfig` still says `MARKETING_VERSION
  1.0` — the same string the no-push binary now in App Review reports. This story
  bumps `MARKETING_VERSION` to `1.1` and gates on `>= 1.1` (compare with
  `Gem::Version`, not string compare); the ship-vehicle open item is thereby
  part-decided — whatever carries push carries 1.1.**
- Render nothing when `current_device` is nil (finding 2 — a signed-in reader whose
  device row was revoked must not crash the page). Otherwise server renders state
  from `current_device.apns_token.present?`:
  - **Off:** owner-written invitation line + an enable link → `GET
    /you/push/enable`. In a browser that path just redirects to `/you` (harmless);
    in the shell the route never loads — the handler intercepts it (step 5).
  - **On:** owner-written "on" line + the opt-out button (DELETE above).
- 44px targets (DESIGN rule 9), `/you`'s existing quiet layout, no new sections.

### 5. iOS shell — the accepted native exception

- **Entitlement**: add Push Notifications capability in Xcode → `aps-environment`
  entitlement (`development` in debug, `production` in distribution — Xcode manages
  the swap at archive).
- **`PushRouteDecisionHandler`** — the existing route-decision idiom
  (`AuthRouteDecisionHandler` is the template), matching `/you/push/enable`.
  **Registered AHEAD of the generic same-host handler — first match wins, the
  exact trap the auth handler's own doc comment records (outside voice #11).**
  1. `UNUserNotificationCenter.getNotificationSettings` first:
     - `.denied` → open `UIApplication.openSettingsURLString` (the story's
       denied-UX answer: second tap goes to Settings).
     - `.authorized` or `.notDetermined` → `requestAuthorization([.alert, .sound])`;
       on grant → **hop to main** (`registerForRemoteNotifications()` is
       main-thread-only and the completion arrives on a background queue —
       outside voice #12) → `registerForRemoteNotifications()`, and set a
       **`enrollPending` flag** — the token callback uses it to pick `mode` and
       to decide whether to reload (below).
  2. Cancel the web navigation either way.
- **AppDelegate** `didRegisterForRemoteNotificationsWithDeviceToken`: hex-encode,
  POST to `/device/push_registrations` with the `DeviceIdentity` request idiom
  (secret header, explicit UA, 5s timeout, ephemeral session). `mode` and reload
  ride the **`enrollPending` flag, not the callback itself** (outside voice #10 —
  healing fires this callback on every cold launch; an unconditional reload would
  add a daily needless POST-plus-reload racing `navigator.start()`):
  - flag set → `mode=enroll`; on completion, clear flag and reload the visible
    web view so `/you` re-renders ON. Reload rides the POST completion, never the
    grant, or the page repaints before the server knows.
  - flag clear (launch healing) → `mode=refresh`; no reload.
- **Launch reconcile (both directions)**: on foreground,
  `getNotificationSettings`:
  - `.authorized` → `registerForRemoteNotifications()` (tokens rotate on restore
    from backup; the idempotent refresh POST is the retry mechanism). Server-side
    `refresh` semantics make this safe against reversing an opt-out (step 3).
  - `.denied` → POST `mode=refresh, enabled=false` — the reader who killed
    notifications in iOS Settings stops being lied to by an ON toggle
    (outside voice #8).
- **Notification delegate — wired, not just written (outside voice #9):**
  `UNUserNotificationCenter.current().delegate` assigned in
  `didFinishLaunchingWithOptions` before return.
  - `willPresent` → `[]` — a reader already looking at the art gets no banner
    over it (DESIGN rule 5's spirit).
  - **`didReceive` → navigate the web view to root (outside voice #2 — the P1
    of this review).** A tap on a suspended/backgrounded app — the NORMAL state
    at noon for a daily-habit reader — is bare activation: without this handler
    the reader lands on whatever screen they left, or yesterday's cached today
    page. The story's core promise ("tapping the knock puts the art on my
    screen") lives in this one method. Route to `Endpoint.url` (fresh request,
    not a cached restore).

### 6. `DailyPushJob` — the noon knock

- `config/recurring.yml` production: `every day at 12pm America/New_York`, under the
  0023 entry. Noon per the corpus; seven hours after the 05:00 fill.
- Body, in order:
  1. `pick = DailyPick.current`; **abort unless `pick&.scheduled_on == Date.current`**
     (Eastern, the app's one clock) — the queue-health-503 case sends nothing.
  2. **Claim**: `DailyPick.where(id: pick.id, notified_at: nil)
     .update_all(notified_at: Time.current)` — returns 0 → another run already
     claimed it → abort. Atomic, so a double-fired schedule (Solid Queue is
     enqueue-once, not run-once) cannot double-knock. **Claim-then-send is
     at-most-once by choice** (`decisions/0019`): if the process dies mid-send,
     some devices miss a day — acceptable; two knocks is the notification-spam
     pattern the story exists to not be.
  3. Send: one `Apnotic::Connection` — token auth, the `.p8` fed as a `StringIO`
     straight from credentials (verified: `cert_path` accepts an IO; no tempfile
     on disk), **explicit connection timeout, and `ensure conn.close`** (finding
     1: default ~30s stalls inside the Puma-embedded worker, day already claimed).
     Production URL in prod, development URL otherwise. Loop over
     `Device.where.not(apns_token: nil).distinct.pluck(:apns_token)`, alert push
     with `apns-topic` = bundle id, **`apns-push-type: alert`** (outside voice
     #13 — omitting it surfaces as APNs throttling later, not an error now),
     priority 10. Sequential is fine at this scale; batching/async is
     infrastructure for later, by name.
  4. Per-token rescue: 410/`Unregistered`, 400/`BadDeviceToken` → clear that token;
     other failures → count, keep sending — one bad token must not starve the
     rest. **Whole-batch rescue around the loop** (finding 1): connection-level
     failure → one Sentry event with sent/failed counts, job ends cleanly, no
     hung thread.
  5. **After the loop: `update_column(:push_sent_count, sent)`** — the audit that
     distinguishes "claimed" from "delivered" (step 2, outside voice #3).
- Payload from the **owner-written template** (step 7) + `pick.painting` title and
  artist. No generated prose.

### 6b. `/queue-health` learns about the knock

Outside voice #4: a Kamal deploy replacing the container across the noon tick
skips the schedule with no catch-up, no Sentry event (no job ran), and — before
this step — no watcher. The existing dead man's switch gains one clause: after
**12:15 ET** (grace window), today published but `notified_at` nil → 503. The
external uptime monitor that already watches the queue now watches the knock,
and the `push_sent_count` tripwire (step 2) has a reader. One shared predicate
extension on `DailyPick`, both surfaces keep calling the same method (the 0023
`queue_healthy?` lesson — two readings must never drift).

### 7. Copy — OWNER INPUT, blocks ship, not start

Owner writes, editorial voice: invitation line + "on" line + opt-out label on
`/you`; notification title/body template with `%{title}` / `%{artist}` slots.
Implementation may proceed with the slots wired to obviously-fake strings in
fixtures, but the ship gate is real copy in place (story: "placeholder-free real
copy or it is not done").

### 8. Tests — Minitest, with the suite as the enforcement (R1)

- **Controller**: secret gate (missing/wrong → 401), junk `apns_token` (hash, huge
  string → 400), happy path sets the token, idempotent repeat, DELETE clears it,
  DELETE without a device cookie bounces off the wall.
- **Eng-review additions (all required, from the coverage diagram + outside voice):**
  1. `mode=enroll` on a digest with no Device row → find_or_create, token set.
  2. `mode=refresh` on a row with `apns_token` nil → **stays nil** (the
     opt-out-reversal regression guard — the single most important new test).
  3. `mode=refresh` on a row with a token → token replaced (rotation).
  4. `mode=refresh, enabled=false` → token cleared.
  5. DELETE clears EVERY row holding that token, not just `current_device`'s.
  6. Rate limit: 11th request in a minute → 429, **with the pinned `MemoryStore`**
     (the 0015 lesson: the default is `:null_store` in test — an unpinned limiter
     test is a silent no-op).
  7. `/you` with shell UA at version **below** the gate → control absent; signed-in
     reader with revoked device row → page renders, no crash.
  8. Job: connection-level raise → batch rescue fires, Sentry event recorded, job
     returns; `push_sent_count` stamped with actual sent count (0 on total
     failure); payload template filled with quotes/unicode in title and artist.
  9. `/queue-health`: after the grace window with today claimed-but-unstamped →
     503; before the window → unaffected (time travel via `travel_to`).
- **Job** (client injected — an attr the test swaps for a fake recording
  connection; production builds the real one lazily):
  - one send per opted-in device, distinct-token dedupe;
  - second run same day → zero sends (claim already taken);
  - today unscheduled → zero sends, no stamp;
  - fake 410 → that device's token nil, other devices still sent;
  - payload carries the pick's title/artist through the template.
- **System**: `/you` with the native UA + push-capable version shows the
  invitation; browser UA shows nothing; opted-in device (fixture with token) shows
  the off switch.
- The recurring schedule itself is config, verified by the on-device QA pass, not
  unit-tested — 0023 precedent ("tested through the model method, not queue
  plumbing").

### 9. QA and receipts

- `bin/ci` green before QA (build flow 5).
- **QA wiring, named up front (outside voice #7 — this was a half-day surprise in
  waiting):** `Config/Debug.xcconfig` pins `TONDO_URL` to `localhost:3000`, which
  on a physical iPhone is the phone itself. For the delivery QA, point the debug
  build at the Mac's LAN address (temporary xcconfig edit, not committed) so the
  sandbox token lands in the dev database the job reads. Credentials need no env
  work: the repo has a single `config/credentials.yml.enc` shared across
  environments, so dev already reads the `apns:` block.
- **On-device, physical iPhone** (simulator cannot take a real APNs token): debug
  build → opt in → run `DailyPushJob.perform_now` from the dev machine (sandbox
  connection) → notification lands on the lock screen → **screenshot into
  `SHIPLOG.md`** — story success signal 2, the delivery receipt.
- **Tap routing on device:** background the app on `/days`, send, tap → app must
  land on today's art (the `didReceive` path — outside voice #2), not the archive.
- Toggle round-trip on device (signal 3). Denied path: deny in the dialog, tap
  again, land in Settings.
- Then `/qa`, `/simplify`, `/code-review`, re-verify (flow 6–8) — reviews mutate
  code after QA passed, so the smoke repeats.

## Risks

- **APNs key is owner-gated.** Step 0 is portal work the agent cannot do; the story
  cannot even be QA'd without the `.p8`. Do it first, not at ship time.
- **App Review is in flight.** A new build on 1.0 while "Waiting for Review" means
  pulling the submission or waiting out the verdict; 1.1 means a second review
  cycle. Owner call at ship (story: open item), and if 4.2 rejection lands first,
  this branch IS the Resolution Center answer — which argues for building now,
  deciding the vehicle later. **Part-decided by eng review:** whatever vehicle
  ships push carries `MARKETING_VERSION 1.1` — the version gate (step 4) requires
  the push binary to be distinguishable from the 1.0 now in review.
- **Sandbox/production token mixups.** A debug-build token in the prod database
  fails as `BadDeviceToken` and gets pruned — self-healing, but during QA keep the
  sandbox sends on the dev machine so pruning doesn't eat the QA device's real
  token later.
- **Solid Queue runs inside Puma.** The job does network I/O to APNs on the web
  process's box — sequential sends at current scale are milliseconds-to-seconds;
  revisit only if device count makes noon sends collide with noon traffic (not
  now).
- **Aug 31 is five days out.** The story is sized ≤ 2 days; the schedule holds only
  if step 0 happens today. If the `.p8` stalls, everything but delivery QA can
  still land behind the branch — but "done" stays "shipped and logged" (R7), and a
  push story without a delivered push is not shipped.

## Deviations

(Implement-time deviations get noted here — build flow step 2.)

## GSTACK REVIEW REPORT

| Review | Trigger | Why | Runs | Status | Findings |
|--------|---------|-----|------|--------|----------|
| CEO Review | `/plan-ceo-review` | Scope & strategy | 0 | — | — |
| Codex Review | `/codex review` | Independent 2nd opinion | 0 | — | Codex usage-limited (resets Sep 9); Claude subagent stood in |
| Eng Review | `/plan-eng-review` | Architecture & tests (required) | 1 | CLEAR | 16 issues (3 review + 13 outside voice), 0 critical gaps open — all folded |
| Design Review | `/plan-design-review` | UI/UX gaps | 0 | skipped — UI-light, noted | — |
| DX Review | `/plan-devex-review` | Developer experience gaps | 0 | — | — |

Review date 2026-08-26, commit `87e2c70`, scope accepted as written (complexity gate
triggered on raw file count; web/native boundary inherent, nothing speculative).
Verified in-session: apnotic 1.8.0 loads and constructs on Ruby 4.0.1 (token auth,
`.p8` via StringIO — no tempfile); `published` scope semantics for the noon abort;
`current_device` memoization; Debug.xcconfig localhost pin.

Top folded findings: notification-tap routing on warm launch (`didReceive` → root —
the story's core promise lived in an unwritten method); launch healing reversing web
opt-out (fixed with enroll/refresh modes, refresh never re-enrolls); dead
`notified_at` tripwire (replaced by `push_sent_count` + `/queue-health` 12:15 ET
clause, decisions/0019 amended); MARKETING_VERSION 1.1 bump feeding the version
gate; opt-out clearing by token value across duplicate rows; connection
timeout/close/batch-rescue; NativeEndpoint concern; 9 named test additions.

**CROSS-MODEL:** outside voice (Claude subagent, fresh context) extended the review
rather than contradicting it — no tension points; two findings amended decisions/0019
wording, recorded there.

**VERDICT:** ENG CLEARED — ready to implement.

NO UNRESOLVED DECISIONS
