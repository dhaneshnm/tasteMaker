# 0017 — Your corner
Date: 2026-08-17
Lane: Full (core). Honest size: **2–3 days** — over the ≤ 2-day lane cap, stated
rather than shaved. Two surfaces, a native auth transport that `bin/ci` cannot
reach, and a one-way data move.
Status: Draft

## Who

**Jordan** — persona 2, Collector / Wishlist-keeper (`specs/personas.md:33`),
the loudest pain in the review evidence. For Jordan the collection *is* the
product. Today it is bolted to one phone: wipe the device and it is gone, open
the web and it is not there.

**Ruth** — persona 6, Burned Loyalist (`specs/personas.md:99`), the reader who
finds out a limit the hard way and never comes back. Every honest-limit
sentence in this story is written for Ruth, and the claim-on-sign-in is the
single most Ruth-shaped thing this product has ever done.

**Maya** — persona 1, CORE (`specs/personas.md:10`). The person this must not
touch. Push → open → art, one to three minutes, nothing in between. Story 0015
protected her by keeping login out of the binary entirely; this story puts
login in the binary, so the protection stops being structural and becomes a
constraint somebody has to hold. It is written as acceptance, not as intent.

**The owner** — directed, this session (2026-08-17), scope reaffirmed after the
cost was flagged. See `decisions/0013`.

## Problem

Four defects, stacked, plus one constraint that reshapes the last two.

**P1 — Sign-out lives in exactly one place, and it is the wrong place.**
`app/views/sessions/_control.html.erb:56` puts `Sign out` at the foot of the
landing page, below the coda, inside a lazily-loaded frame. A signed-in web
reader has to scroll past today's artwork, past the wall label, past
"See you tomorrow." and past "Wander the full gallery →" to leave. It is the
second screenshot in the intake.

**P2 — Signed-out web readers meet the front door below the fold.** Same
fragment, same position (`_control.html.erb:19-48`, first intake screenshot).
Wall bounces are covered — `require_reader` redirects to `/#signin` and the
anchor lands on it — but a reader who arrives at `/` under their own steam
scrolls the entire landing page before learning the product has accounts at
all.

**P3 — The app has no account surface, at all.** `SessionsController#control:80`
returns an empty frame for `native_shell? || current_device`. That was correct
under `decisions/0011` and it is why nothing is visible on mobile today. The
consequence: the only account-shaped control an iOS reader can reach in the
whole product is a footer at the bottom of `/collection`
(`app/views/favorites/index.html.erb:66-72`) offering "Delete this device's
data" — an exit door standing in a field, with no room around it. Story 0016
had to add that door in a hurry because the filed privacy policy promised
in-app deletion that did not exist for the majority reader.

**P4 — A collection cannot leave the phone.** `app/models/favorite.rb:32-36`
enforces exactly one key per row, by validation:

```
device world (iOS)               account world (web)
collector_digest = sha256(uuid)  user_id
        │                                │
        └──── no row can carry both ─────┘
              and no path moves one to the other
```

Wipe the device, the collection dies with it. Sign in on the web, it is not
there. That is persona 2's entire pain, and `decisions/0011` accepted it with a
written trigger for undoing it — a trigger that has **not** fired (see
`decisions/0013`, "The trigger had not fired").

### The constraint that reshapes P3 and P4

**Google refuses OAuth in embedded webviews.** `accounts.google.com` answers a
`WKWebView` with `403 disallowed_useragent`. Policy, not a bug, not a header
we can set. So sign-in buttons rendered into the shell's web view are dead on
tap.

Worse, the near miss looks like a fix. `LinenSafariRouteDecisionHandler.swift:28`
already routes any off-host URL to `SFSafariViewController`. That sheet keeps
its **own cookie jar**. OAuth would complete, the session cookie would land in
Safari's store, the sheet would dismiss, and the reader would be back in an app
that is still signed out — with no error, no failed request, and nothing in the
logs. This is the failure this story is most likely to ship if it is not
designed against on purpose.

## Story

As **Jordan**, I want one place that is mine — where I sign in, sign out, and
can see what my collection is tied to — and I want the works I kept on my phone
to become mine rather than this phone's.

As **Ruth**, I want to be told what signing in will do to my kept works
*before* it happens, and where they went *after* I sign out.

As **Maya**, I want none of this to appear between the notification and the
artwork, ever.

As **the owner**, I want the account controls out of the landing page's footer.

## Intake

- **Problem**: P1–P4 above, plus the embedded-webview constraint.

- **Evidence**: owner directive, 2026-08-17, reaffirmed after the scope cost was
  put in front of them. Persona 2's collection pain (~6 reviews) and persona 6's
  betrayal pattern (~7 reviews) are real evidence and they argue for P4 —
  honestly weighed, they argue for it *whenever*, not *now*.
  `decisions/0011`'s own trigger for building it ("a real user asks for their
  device keeps on the web") has not fired; zero users have asked, because zero
  two-way user conversations exist. P1–P3 are owner-observed on the live build
  and need no persona argument — a sign-out control below the fold is a defect
  on its face.

- **Success signal (prediction)** — hand-checkable the day it lands:
  1. Fresh install → keep 3 works → open `/you` → sign in with Google → a
     Safari-backed sheet opens (not a 403 page) → returns to the app →
     `/you` shows the account → `/collection` shows the same 3 works.
  2. Sign out on the phone → `/collection` is empty **and says where the works
     went** → sign in again → the 3 works are back.
  3. `curl -sI https://app/` → 200, **no `Set-Cookie`**, identical ETag whether
     the caller is signed in, a device, or nobody. Story 0007's contract, which
     is the thing most likely to break silently here.
  4. `curl -s https://app/you` with no cookies → **200 with the sign-in door**,
     not a bounce; and `Cache-Control: private, no-store`.
  5. At 375px the compass row carries four words plus the glyph on **one** row,
     on all five surfaces, and the artwork fold budget is unchanged from
     today's measurement.
  6. `/privacy` names where deletion lives, and that path works from inside the
     app for all three states: account, registered device, device-that-signed-in.
  7. Signing in a second time on the same device claims nothing and errors
     nothing.
  8. Cancel the auth sheet → back on `/you`, signed in as nobody new, no error
     screen.

- **Lane**: Full. 2–3 days, over cap, stated.

- **In baseline?** No. Owner-directed exception. Reverses `decisions/0011`
  choice 5 → recorded in `decisions/0013`.

- **R7 note**: this moves **zero** BET.md thresholds. Not installs, not ranked
  keywords, not published teardown posts, not the five user conversations. Kill
  review is Aug 31 — 14 days out, of which this takes 2–3. Prediction 3 in
  `decisions/0013` is the bet that it costs the teardown cadence.

## Acceptance

### A. The surface — `/you`

- The fifth reader surface. Sections: **Account** only. Push settings, curation
  preferences and display name are named in Non-goals as future residents and
  are **not** built, and no empty sections are rendered for them — that would
  be infrastructure for later.
- Reached **two ways, deliberately** (owner decision, 2026-08-17). The glyph
  carries reach; the word carries meaning; neither has to do both.
  1. **The oculus** in the masthead's right column, on every screen, both
     platforms. The compass is untouched — four words, one row, no new height.
  2. **`Your corner`** as a caps-link in the coda, joining the row that already
     exists rather than adding one. See the plan's `_legal` conflict: story
     0016 decided one day earlier that extra coda rows stay off the daily page.
- Glyph spec matches `.rail__act` exactly (`application.css:991-995`,
  `DESIGN.md` rule 6 amendment): 23px box, 1.4px stroke, `--gold`, inside a
  44px target, with an `aria-label`. It is a functional glyph, not ornament.
  The drawing is the rose window's **oculus** — `circle r=7.4` stroked around
  `circle r=2.5` filled — the centre of the mark the App Store icon ships. It
  is the weakest signal of the three candidates and was chosen knowing that;
  the coda word is the mitigation, not an extra.
- **The compass row was measured out, not passed over.** 41.0px short at 375px
  with Dynamic Type at its cap, and `test/system/favorites_test.rb:155-166`
  asserts exactly four caps-links, one row, and a ≥10px adjacency floor. Three
  failures, not one. Full arithmetic in the plan.
- On `/feed` the compass is sticky (`.compass--rail`), so the glyph is sticky
  there too. Intended — `/feed` is the screen with the fewest exits.
- **Unwalled.** Second exception after `/`, because it holds the sign-in door.
  Private, `no-store`, `Vary: Cookie`; never publicly cached, never carries a
  stable ETag.
- Three states, from the identity the request already carries:

  | request | `/you` shows |
  |---|---|
  | signed-in (account) | provider + email, Sign out, Delete account |
  | registered device, no account | "Kept on this device, with no account", the two sign-in doors, **the claim sentence naming the count**, Delete this device's data |
  | signed-out web | what signing in opens, the two sign-in doors |

- `require_reader`'s bounce retargets from `/#signin` to `/you` — both the
  redirect (`application_controller.rb:85`) and the frame-write branch's inline
  "Sign in" link (`application_controller.rb:81`).

### B. What moves off the pages it is squatting on

- `Sign out` → `/you`. Leaves `/`.
- `Delete account` → `/you`. Leaves `/collection`.
- `Delete this device's data` → `/you`. Leaves `/collection`.
- `/collection`'s footer keeps **only** the honest-limit line ("Kept with your
  account" / "Kept on this device") and loses its buttons.
- **Superseded by owner decision 5 and the design review.** `/`'s per-visitor
  fragment is **deleted outright** — `sessions#control`, its route, the
  `signin` turbo-frame at `daily/_day.html.erb:194`, and the `/#signin` anchor.
  The corner oculus and the coda word are identical markup for every reader, so
  the landing page needs no per-visitor fragment at all. The paragraph below is
  the original reasoning, kept because it records why the buttons were nearly
  retained:
- ~~`/`'s per-visitor fragment keeps the two provider buttons for **signed-out
  web** — it is the highest-traffic first impression, prose can say what a
  glyph cannot, and the compass glyph now answers P2's discovery problem
  above the fold without touching the fold budget. For a **signed-in** reader
  the fragment renders nothing at all. For a device, nothing, as today.
- **`/privacy` and `/support` copy move with the doors.** Story 0016 shipped a
  filed policy that was false for the majority reader because a deletion path
  named in the policy did not exist for them. Relocating the deletion path
  without moving the copy repeats that defect exactly. Ship blocker.

### C. Sign-in inside the app

```
/you in the shell
  │  tap "Continue with Google"
  ▼
bridge component ──> ASWebAuthenticationSession(POST /auth/google_oauth2)
                              │  Safari-backed, its own jar, Google accepts it
                              ▼
                     provider consent → /auth/:provider/callback
                              │  server signs the user in IN THAT JAR
                              ▼
                     302 tondo://auth?handoff=<single-use token>
                              │
                     shell navigates WKWebView to /session/handoff?token=…
                              ▼
                     server verifies + consumes → sets the session cookie
                     IN THE WEB VIEW'S JAR → redirects to /you
```

- Handoff token: single-use, 60-second TTL, stored **in a table**, not a signed
  message with a cached nonce — the cache store is `:null_store` in test and a
  replay guard that silently no-ops in the suite is worse than none.
- `tondo://` registered in `Info.plist`, used **only** as the auth callback.
- The product's first bridge component. `AppDelegate.swift:28-35` currently
  returns a plain `WKWebView` with the comment *"the bridge initialises if any
  components are registered — none are"*. That comment becomes false and is
  part of this change, not a leftover.
- `LinenSafariRouteDecisionHandler` **must not** intercept the auth URLs. Its
  `matches` is a bare off-host test (`:28`), so `accounts.google.com` matches
  it today. A handler that grabs the URL before the bridge does produces the
  silent signed-out return described in the Problem section.
- **No login gate.** `/you` is reachable only by the glyph. Launch, push, open,
  artwork, keep, collection — all unchanged, all working with no account,
  forever. This is the acceptance criterion that carries `decisions/0011`'s
  surviving half.
- Failure states, all quiet: reader cancels the sheet → back on `/you`,
  nothing changed. Handoff expires or is replayed → `/you` with one line, still
  the device identity. Neither is an error screen.
- Both providers take this same path. Native Sign in with Apple is declined
  (`decisions/0013`, choice 4).

### D. The claim — device → account, one way

- On a successful sign-in whose request also carries a device cookie: move
  `Favorite.collected_by(device.token_digest)` to `user_id`, in one
  transaction.
- **Idempotent.** A painting already kept by that account → drop the device row
  rather than fail the unique index. A second sign-in claims an empty set and
  returns normally.
- The `Device` row **survives** and stays registered. The wall still passes it.
  Signing out returns the reader to a device identity whose collection is now
  empty.
- Keyed on identity, not on platform: a web request carrying a device cookie
  claims too. It will not happen in practice — only the shell mints that cookie
  — but the code has no business asking which platform it is on.
- **Both ends carry copy.** Before: `/you` on a device with N kept works names
  N and says they will move. After: sign-out says where they went and that
  signing back in returns them. This is the persona-6 surface of the whole
  story and the copy is a ship blocker, not polish.

## Non-goals

- **Un-claim / account → device.** No un-claim exists. "Put my works back on
  the phone" is a different data model, not a missing button (`decisions/0013`,
  Triggers).
- **Cross-provider linking.** Google and Apple with the same email stay two
  users. Unchanged from 0015; linking by email is an account-takeover vector.
- **Push settings, curation preferences, display name.** Named as future
  residents of `/you`. Not built, not scaffolded, no placeholder sections.
- **Native `ASAuthorizationAppleIDProvider`.** One transport for two buttons.
- **App Attest.** Trigger unchanged from `decisions/0011`.
- **Any account requirement.** The device key is sufficient for every feature,
  permanently.

## Risks

1. **The auth round trip cannot be tested by `bin/ci`.** A simulator or a real
   device is the only gate. This is the same class of risk as story 0015's
   Apple cross-site POST, which shipped verified on the deployed domain with a
   green local suite that could not have caught it.
2. **The silent signed-out return.** Described twice above because it is the
   defect this design exists to avoid, and it fails with no error anywhere.
3. **The claim is destructive, one-way, and fires at the moment a reader is
   least prepared for a data move.** Mitigated only by copy.
4. **Story 0007's front-door contract.** A new per-visitor thing on every screen
   is exactly how `Set-Cookie` gets onto a publicly cached `/`. The glyph is a
   plain link with no per-visitor content for that reason, and success signal 3
   is the check.
5. **Schedule.** 2–3 days, 14 days to the kill review, zero threshold movement.
   Owner reaffirmed with this stated.

## Next

`plan.md`, then `/plan-design-review` (significant UI — the glyph, the new
surface, and the claim copy) and `/plan-eng-review` (the transport and the
data move).
