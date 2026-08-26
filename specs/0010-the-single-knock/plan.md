# 0010 — The single knock — implementation plan

Date: 2026-08-26
Story: `story.md` in this directory.
Direction decisions: **`decisions/0019` to be written before implementation (R4)** —
four calls bundled: noon ET send time (not per-device local), `apnotic` gem enters the
Gemfile (stack rule: one-line reason committed), opt-in lives on `/you` (not the daily
page), at-most-once delivery semantics (a missed knock beats a double knock).

Design review: **skipped — UI-light** (build flow step 3; the UI is one toggle and two
owner-written lines on an existing page). Noted here per the flow. Eng review
(step 4): **pending — run `/plan-eng-review` on this file before implementing.**

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

### 2. Migration — two columns, no new tables

- `devices.apns_token`, string, nullable. Nil = not opted in. No index — the daily
  scan of a table this size is nothing, and the write path looks devices up by the
  existing `token_digest` index.
- `daily_picks.notified_at`, datetime, nullable. The durable one-knock-per-day stamp
  and the audit the kill review can query (R1: the receipt lives in the schema, the
  0023 `auto_tier` lesson).

### 3. Server — registration in, opt-out, prune

- **`POST /device/push_registrations`** — native URLSession caller, so it mirrors
  `DeviceRegistrationsController` exactly: `skip_forgery_protection`, app-secret
  header check (same `expected_app_secret`), same rate-limit idiom, params
  `device_token` (Keychain UUID) + `apns_token` (hex, length-capped ≤ 200, String
  check — the F5 lesson). Finds `Device` by digest, sets `apns_token`, `head
  :no_content`. Idempotent: same pair, same outcome. Why not the device cookie: the
  shell's native URLSession is ephemeral and deliberately does not share the
  WKWebView jar (`DeviceIdentity` comment) — the secret+UUID pattern is already the
  native lane.
- **Opt-out from the web**: `DELETE /device/push_registration` (singular), normal
  Turbo form on `/you`, authenticated by the signed device cookie the wall already
  resolves. Sets `apns_token: nil`. No native code involved in leaving.
- **Prune on send** (step 5): 410 `Unregistered` and 400 `BadDeviceToken` clear the
  token. Covers deleted apps and sandbox tokens that leak into prod.
- **Duplicate tokens**: a device wipe re-mints the Keychain UUID, so two device rows
  can briefly hold one APNs token. Send distinct tokens (`DISTINCT apns_token`) —
  one knock per phone, not per row.

### 4. `/you` — the invitation and the toggle

- Render only when `bridge_capable_shell?` **and** `native_shell_version` ≥ the
  first push-capable shell version (the 0017 lesson: capability and binary ship
  together; presence/threshold of the UA version IS the feature detection — no
  server flag). Older binaries and browsers see nothing.
- Server renders state from `current_device.apns_token.present?`:
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
  (`AuthRouteDecisionHandler` is the template), matching `/you/push/enable`:
  1. `UNUserNotificationCenter.getNotificationSettings` first:
     - `.denied` → open `UIApplication.openSettingsURLString` (the story's
       denied-UX answer: second tap goes to Settings).
     - `.authorized` or `.notDetermined` → `requestAuthorization([.alert, .sound])`;
       on grant → `registerForRemoteNotifications()`.
  2. Cancel the web navigation either way.
- **AppDelegate** `didRegisterForRemoteNotificationsWithDeviceToken`: hex-encode,
  POST to `/device/push_registrations` with the `DeviceIdentity` request idiom
  (secret header, explicit UA, 5s timeout, ephemeral session); **on completion,
  reload the visible web view** so `/you` re-renders with the toggle on. Sequencing
  matters: reload rides the POST's completion, not the authorization grant, or the
  page repaints before the server knows.
- **Re-registration healing**: if `getNotificationSettings` reports `.authorized`
  on launch, call `registerForRemoteNotifications()` — tokens rotate on restore
  from backup; the idempotent POST is the retry mechanism, same philosophy as
  `DeviceIdentity.register` on every cold launch.
- **Foreground**: `willPresent` returns `[]` — a reader already looking at the art
  does not get a banner over it (DESIGN rule 5's spirit).
- **Tap**: no handler needed; default launch shows today.

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
  3. Send: one `Apnotic::Connection` (production URL in prod, development URL
     otherwise), loop over `Device.where.not(apns_token: nil).distinct.pluck(:apns_token)`,
     alert-type push, `apns-topic` = bundle id, priority 10. Sequential is fine at
     this scale; batching/async is infrastructure for later, by name.
  4. Per-token rescue: 410/`Unregistered`, 400/`BadDeviceToken` → clear that token;
     other failures → count, report once to Sentry, keep sending — one bad token
     must not starve the rest.
- Payload from the **owner-written template** (step 7) + `pick.painting` title and
  artist. No generated prose.

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
- **On-device, physical iPhone** (simulator cannot take a real APNs token): debug
  build → opt in → run `DailyPushJob.perform_now` from the dev machine (sandbox
  connection) → notification lands on the lock screen → **screenshot into
  `SHIPLOG.md`** — story success signal 2, the delivery receipt.
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
  deciding the vehicle later.
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
