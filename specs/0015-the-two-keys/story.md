# 0015 — The two keys
Date: 2026-08-14
Lane: Full (core, target ≤ 2 days build; honest estimate 2–3 — this is two surfaces and
an identity model, combined into one story by explicit owner decision, this session)
Status: Spec'd

## Who
**The owner** — this story is directed, not persona-derived. Dhanesh wants the product's
endpoints closed to anonymous open access before it is live, and wants the web surface to
be a signed-in surface. Secondary: **Maya**, persona 1 (`specs/personas.md`) — the person
this story must *not* touch. Her whole product is push → open → art, on the phone, with
nothing in between. Any login screen in the iOS app breaks the category's one quality bar
we named a moat (calm), so the app keeps working end-to-end with no account, ever, in this
story.

## Problem
Three related holes, one identity model missing under all of them:

1. **Every reader-facing endpoint is open to anyone with curl.** `/`, `/days`, `/feed`,
   `/collection` answer any request from anywhere. There is no notion of "this request
   came from our app or our signed-in web reader." Before the app is live and the URL is
   public, the owner wants that closed: scrapers, hotlinkers, and strangers replaying the
   collection endpoints should get the front door and nothing else.
2. **The web surface has no identity at all.** The plan is for web to be a signed-in
   experience: a visitor sees today's artwork on the landing page, and everything else —
   archive, feed, collection — requires signing in with Google or Apple.
3. **The iOS app's identity is a browser cookie with browser-cookie durability.** Kept
   works hang off a token WKWebView may quietly evict under storage pressure (named as an
   accepted risk in `specs/0006-favorites/plan.md`). A device-level identity in the
   Keychain survives eviction and app reinstall.

## Story
As the owner, I want every endpoint to answer only our iOS app or a signed-in web reader,
so that the product's content and collection APIs are not an anonymous public utility —
while the app itself stays exactly as calm as it is today, no login anywhere in it.

As a web reader, I want to sign in with Google or Apple — no password, no signup form —
and get the archive, the feed, and a collection that is mine.

## Intake
- **Problem**: above — open endpoints, no web identity, fragile device identity.
- **Evidence**: owner directive (this session, 2026-08-14 — Q&A logged in
  `decisions/0011-the-two-keys.md`). This is **not** a Proven-baseline item and must not
  be argued as one; the baseline says "free at launch, no billing" and stays true — signed
  in is not paid. Adjacent evidence, honestly weighed: session gate 6 (secure the surface
  before first external user) points this direction; the category moat (calm) points hard
  at keeping the app login-free, which this story preserves by design. R7 note: this moves
  zero BET.md numbers. It is a prerequisite the owner chose, not progress.
- **Success signal (prediction)**, hand-checkable the day it lands:
  1. `curl -s https://app/days` with no cookies → redirect to `/`, zero content leaked.
     Same for `/feed`, `/collection`, and every favorites route.
  2. `curl -sI https://app/` → 200, **no `Set-Cookie`**, same ETag whether the caller is
     signed in, a device, or nobody — the story 0007 contract survives intact.
  3. Fresh install in the simulator → open app → today, archive, feed, keep/unkeep all
     work. Zero login UI anywhere in the app. No new taps between push and art.
  4. On web: sign in with Google → everything opens; sign out → walled again. Sign in
     with Apple does the same on the deployed domain.
  5. `POST /device/registrations` without the app's registration secret → 401. With it →
     device row + signed device cookie.
- **Lane**: Full.
- **In baseline?** No. Owner-directed exception, carried by the evidence line above and
  by `decisions/0011`.

## Acceptance

### The app (device key)
- On first launch the shell mints a UUID, stores it in the **Keychain** (survives
  reinstall; dies with device wipe — accepted, decision Q2), registers it with the
  server, and receives a signed, permanent device cookie into the WKWebView cookie store.
- Every screen in the app works with no account: today, days, feed, keep, collection.
  **No login UI exists anywhere in the app.** Sign-in affordances shown to logged-out web
  visitors must never render inside the shell.
- Kept works are keyed against the device identity. Deleting and reinstalling the app
  keeps the collection (Keychain survives). Wiping the device loses it — same honest
  caveat as story 0006, now one notch more durable.
- Registration is idempotent: every cold launch may re-register; same UUID → same
  identity, cookie re-issued, no duplicate rows.

### The web (account key)
- The landing page (`/`) shows **today's artwork** to everyone, signed in or not
  (decision Q1). It stays publicly cacheable, byte-identical, `Set-Cookie`-free.
- A logged-out web visitor sees, on the landing page only, a quiet way to sign in with
  Google or with Apple. Rendered inside the existing private-fragment pattern so the
  public HTML stays identical for everyone.
- Everything else on web — `/days`, `/days/:date`, `/feed`, `/collection`, all favorite
  routes — requires a signed-in session. Logged out → redirected to `/`.
- Sign-in is **OAuth only**: Google or Apple. No password, no email form, no signup step.
  First sign-in creates the user (provider, uid, email, display name); returning sign-in
  finds them. Apple's name/email arrive only on first authorization and are stored then.
- Sign out exists, works, and resets the session.
- A signed-in reader can **delete their account** — one control, on the collection page.
  Destroys the user row and their kept works. Data hygiene before the first external
  user, and the exit door the leader's users begged for.
- Kept works on web are keyed to the user (`favorites.user_id` — the exact nullable
  column `specs/0006-favorites/plan.md` promised when accounts arrived).

### The wall itself
- One guard in one place: a request passes with a valid user session **or** a valid
  signed device cookie. Everything else redirects to `/`. Health check, error pages,
  auth endpoints, device registration, and `/` itself are the only exemptions. Admin
  keeps its own basic auth, unchanged.
- Device registration requires an app secret (embedded in the binary — extractable by a
  determined attacker, **accepted**, decision Q3: this stops open/anonymous access, not
  reverse engineering; App Attest is the named upgrade path) and is rate-limited.
- No merge between the two worlds (decision Q5): a device's keeps and an account's keeps
  are separate. The app never signs in; the web never sees a device's collection.

## Out of scope
- **App Attest / DeviceCheck attestation.** The real "only our binary" proof. Named
  upgrade path, not built now (decision Q3a).
- **Device ↔ account merge, or sign-in inside the app.** Separate worlds (decision Q5a).
  Reopens only if a real user asks for their keeps on the web — that conversation is
  BET.md currency anyway.
- **Passwords, email/password auth, Action Mailer.** No password ever exists in this
  product; there is nothing to reset.
- **Roles, profiles, avatars, settings pages.** A user row is provider + uid + email +
  name. Nothing else.
- **A JSON API.** "The API" here is the HTML endpoints the shell already consumes.
  No new serialization surface.
- **APNs device tokens.** Push is its own story (baseline item 2). The devices table this
  story creates is the natural home for a push token **later** — the column is added by
  the push story, not this one (infrastructure-for-later rule).
- **Premium, billing, StoreKit.** Parked in `CLAUDE.md`; signed-in ≠ paid, and nothing
  in this story may imply otherwise.
