# 0013 — Sign-in comes to the app, the collection stops belonging to the phone

Date: 2026-08-17

Position: the iOS app gets a sign-in door, and the two worlds `decisions/0011`
kept apart now merge in one direction. A reader who signs in on the phone has
the works they kept on that phone **moved** to their account, and from then on
the collection follows the reader rather than the hardware. The device key
stays, stays the default, and stays sufficient: nothing in the app ever asks
for an account, and the path from push → open → art gains no step. Signing in
is opt-in, from one screen, and that screen is new. Spec:
`specs/0017-your-corner/`.

This reverses **choice 5 of `decisions/0011`** ("No device ↔ account merge; no
sign-in inside the app. Separate worlds.").

## The trigger had not fired, and this is built anyway

`decisions/0011` set the condition for exactly this work: *"Merge / claim path:
a real user asks for their device keeps on the web — BET.md conversation
currency; build it then, not before."* No user has asked. There are zero logged
two-way user conversations.

So this is an owner directive taken ahead of its own written trigger, recorded
as such. It moves **zero** BET.md thresholds — not installs, not ranked
keywords, not teardown posts, not the five conversations — and the kill review
is 14 days out (Aug 31, 2026). That cost was put to the owner in session on
2026-08-17 with a smaller alternative offered (surface only, ~1 day, 0011
untouched). The owner declined the split and reaffirmed the full scope. R7
says progress claims get the receipt; the receipt here is that there isn't
one, and the work proceeds on the owner's call rather than on evidence.

## What survives from 0011, unchanged

The part of 0011 that was load-bearing for the category moat holds in full:

- **No login gate anywhere in the app.** Not at launch, not on a keep, not
  between the notification and the artwork. Persona 1 (Maya) is untouched —
  the constraint 0015 carried is now harder to hold, because login UI enters
  the binary for the first time, so it is restated as an acceptance criterion
  rather than assumed.
- **The device key remains the default identity.** Fresh install, no account,
  everything works: today, days, feed, keep, collection. Forever.
- **The wall, the 0007 front-door contract, registration auth.** Untouched.
- **No cross-provider linking.** Google and Apple with the same email are still
  two users. Linking by email is an account-takeover vector and stays out.

## Choices made (owner Q&A, 2026-08-17)

1. **One new surface, `/you`** — the fifth. It holds sign-in, sign-out,
   which identity the collection is tied to, and both deletion doors. Those
   controls leave the landing page's footer and the collection page's footer,
   where they are today.
2. **Reached by a glyph pinned right on the compass row**, not a fifth compass
   word. The compass keeps its four one-word labels. Five labels risk wrapping
   at 375px, and a wrapped row costs 44px above the artwork on every screen
   (`DESIGN.md` rules 2 and 9) — a permanent tax on the product's one screen
   that matters, paid for a control used twice a year. The glyph costs
   discoverability instead, which is the cheaper of the two, and it is the tax
   the bookmark glyph already pays (`decisions/0010`).
3. **Transport for sign-in inside the shell: `ASWebAuthenticationSession` plus
   a single-use handoff token.** Not a plain navigation in `WKWebView` —
   Google answers embedded webviews with `403 disallowed_useragent`, by
   policy. Not `SFSafariViewController` either, which is the trap the existing
   `LinenSafariRouteDecisionHandler` would fall into on its own: that sheet has
   its own cookie jar, so OAuth would succeed, the session cookie would land
   somewhere the web view cannot read, and the reader would return to the app
   still signed out with **no error anywhere**. This requires the product's
   first bridge component, which `CLAUDE.md` permits "only where genuinely
   required"; a system auth sheet the web page cannot summon is that case.
4. **One transport for both providers.** Native `ASAuthorizationAppleIDProvider`
   is declined — it is a nicer Apple flow and a second code path for one of two
   buttons. App Store guideline 4.8 is satisfied regardless, because Sign in
   with Apple is offered alongside Google.
5. **The claim is a move, one-way, and confirmed before it runs.** Device
   favorites become account favorites; the device row survives and stays
   registered. There is no un-claim. Signing out on the phone therefore returns
   the reader to a device identity with an **empty** collection — which is a
   betrayal (persona 6, Ruth) if discovered afterwards and merely a fact if
   stated beforehand. Both ends carry copy: `/you` names the count and the
   consequence before sign-in; sign-out names where the works went.
6. **No new gems.** `AuthenticationServices` is a system framework. The handoff
   token gets a table rather than a signed message with a cached nonce, because
   the cache store is `:null_store` in test and a replay guard that silently
   no-ops in the suite is worse than no guard.

## Prediction (falsifiable, time-bound)

By the **Aug 31, 2026** kill review:

1. **Fewer than 20% of app readers sign in**, and **zero** of BET.md's five
   required user conversations are traceable to this feature existing.
   Falsified if the sign-in rate clears 20%, or if a reader initiates contact
   because of it.
2. **The handoff transport survives App Review with no 4.8 or 5.1.1(v)
   finding.** Falsified by a rejection naming either.
3. **This feature costs one of the five thresholds.** Specifically: the four
   weekly teardown posts, which need two more written in the 14 days this
   consumes 2–3 of. Falsified if all four ship on cadence anyway.

Prediction 3 is the one worth watching. It is the honest statement of what
building this instead of distribution work is expected to do.

## Enforcement (R1)

Pinned by tests listed in `specs/0017-your-corner/plan.md` and run by `bin/ci`:
the 0007 front-door contract in all identity states, `/you` unwalled and
never publicly cached, claim idempotency and the already-kept collision, the
device's continued function with no account, and the path-configuration parity
check. The one thing `bin/ci` **cannot** reach is the auth sheet round trip —
simulator verification is the gate there, same as story 0015's Apple callback.

## Triggers

- **Sign-in rate under 20% at the kill review** → the surface stays, the native
  transport is what gets questioned. It is the expensive half.
- **A reader loses works to a sign-out they did not understand** → the confirm
  copy failed; that is a ship-quality defect, not a feature request.
- **App Attest**: unchanged from `decisions/0011` — actual abuse, or the first
  feature where request provenance carries real value.
- **Un-claim / account → device**: not built, no trigger written. If it is ever
  asked for, it needs its own decision, because "put my works back on the
  phone" is a different data model, not a missing button.
