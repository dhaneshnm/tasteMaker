# 0011 — Two keys: accounts arrive on web, the app stays anonymous, the wall goes up

Date: 2026-08-14

Position: every reader-facing endpoint stops answering anonymous requests. Two
identities exist from here on. The **iOS app** carries a device key — a UUID
minted into the Keychain on first launch, registered with the server, carried as
a signed permanent cookie — and never shows a login screen for any feature. The
**web** carries an account key — sign in with Google or Apple, OAuth only, no
passwords ever — and everything except the landing page (which still shows
today's artwork to everyone) requires it. The two worlds do not merge: a
device's kept works and an account's kept works are separate collections
(owner decision, this session). Spec: `specs/0015-the-two-keys/`.

This is an owner directive, not a persona-derived feature, and it is recorded as
such. It moves zero BET.md numbers (R7) and is chosen with that stated.

## What this does to decision 0005, said out loud

0005 promised: keep with one tap, no account, no sign-up. That promise **holds
in full in the app**, which is where persona 1's calm lives and where the
category is actually won. On the **web**, keeping (and the archive, and the
feed) now sits behind sign-in — a deliberate narrowing of 0005's scope from
"everywhere" to "the app," accepted by the owner in the same breath as this
decision. 0005's accounts trigger ("the first time accounts arrive for any
other reason") has fired: `favorites` gains its nullable `user_id`. The claim
path half of that trigger is **not** built, because the no-merge decision above
makes it meaningless for now; it returns if merge ever does. 0005's other
promises — free permanently, no count limit, never leverage — are untouched and
still enforced.

## Choices made (owner Q&A, 2026-08-14)

1. Landing page shows today's artwork to signed-out web visitors; everything
   else gated.
2. Device identity: app-minted UUID in Keychain (survives reinstall, dies with
   device wipe) — not `identifierForVendor`.
3. API protection: device-token scheme — registration guarded by an app secret
   embedded in the binary, extractable by a determined attacker, **accepted**.
   Stops open/anonymous access, not reverse engineering. Named upgrade path:
   App Attest on the same endpoint.
4. Google and Apple sign-in ship together in one story.
5. No device ↔ account merge; no sign-in inside the app. Separate worlds.
6. Stack deviation, one line (per `CLAUDE.md`): **OmniAuth
   (`omniauth` + google/apple strategies + `omniauth-rails_csrf_protection`)
   instead of the Rails 8 auth generator, because the generator is
   password-shaped and this product will never have a password.**
7. One combined story (0015), not two — owner's call, sized honestly at 2–3
   days in the story header.

## Prediction (falsifiable, time-bound)

By the Aug 31, 2026 kill review: **the web wall costs nothing measurable against
BET.md's five thresholds** — installs come from App Store search, not from web
browsing, so gating `/days` and `/feed` on web will not show up in the install
count; and **the device-token scheme is sufficient for the month** — no scraping
or abuse incident forces App Attest before the review. Falsified if installs
stall while landing-page traffic shows web visitors bouncing off the wall, or if
the endpoints see abuse the token scheme fails to stop.

## Enforcement (R1)

The wall, the 0007 front-door contract (no `Set-Cookie`, stable ETag, all three
identity states byte-identical), registration auth + rate limit, and the
two-worlds separation of favorites are each pinned by tests listed in
`specs/0015-the-two-keys/plan.md` and run by `bin/ci`.

## Triggers

- **Merge / claim path**: a real user asks for their device keeps on the web —
  BET.md conversation currency; build it then, not before.
- **App Attest**: actual abuse the token scheme doesn't stop, or the first
  feature where request provenance carries real value (e.g. paid anything).
- **Sign-in inside the app**: only via the merge trigger, never on its own.
