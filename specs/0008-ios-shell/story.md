# 0008 — The shell that gets it onto a phone

Date: 2026-08-05
Lane: Full (core, target ≤ 2 days)
Status: Spec written 2026-08-05 — not started

## Who

**Maya** — Daily Ritual Learner, persona 1 (`specs/personas.md`). 33, pediatric nurse in
Columbus. She does not know this product exists. The way she would find it is the way she
finds everything: typing "daily art" into the App Store on her phone.

Secondary: **the curator (Dhanesh)**, who has a bet due Aug 31 whose only distribution
channel is App Store search, and five thresholds that all start with a listing existing.

Not in this story: Jordan, Amara, Zoe. The shell is not a feature any reader asks for. It
is the container every reader arrives in.

## Problem

Tastemaker is a website nobody can reach. `BET.md` names **exactly one** distribution
channel — App Store search — and every one of its five thresholds runs through an App
Store listing:

| Threshold | Needs a listing? |
|---|---|
| App live on App Store by Aug 14 | it *is* the listing |
| 3 keywords ranked top 100 | ranks a listing |
| 50 installs | installs a listing |
| 4 build-in-public posts | posts about a shipped thing |
| 5 user conversations | about an app somebody can open |

There is no iOS target in this repo. `ls ios*` returns nothing. Four of five Proven
baseline items are built and none of them has ever been opened by a person who is not the
author.

The second problem is baseline item 2. **Daily push is the habit driver** — the single
strongest signal in the review corpus:

> "It's the only app I have that I allow notifications… the single, daily notification."
> — persona 1 evidence, `specs/personas.md:14`

Push needs a registered APNs device token, and a device token needs an app on a device.
The shell is not merely adjacent to the last unbuilt baseline item; it is its precondition.

Third: a stack rule already decided this. `CLAUDE.md` mandates Hotwire Native iOS, web-first
screens in a thin shell, bridge components only where genuinely required. This story is not
choosing an approach. It is executing a settled one.

## Story

As Maya, I want to find Tastemaker in the App Store and open it like an app, so that my
daily art moment lives on my home screen instead of in a browser tab I will never reopen.

As the curator, I want a shell thin enough that every screen I already built renders inside
it unchanged, so that the iOS surface costs days rather than a rewrite.

## Intake

- **Problem:** the product has no App Store surface, which is the only channel `BET.md`
  bets on, and no carrier for baseline item 2 (daily push).
- **Evidence:** `BET.md` — one channel, five thresholds, all currently zero.
  `specs/personas.md` — push is the loudest positive signal in the corpus.
  `CLAUDE.md` stack section — Hotwire Native iOS is already the settled answer.
  Toolchain verified on this machine 2026-08-05: Xcode 26.5, Swift 6.3.2, iOS 26.5 SDK,
  iPhone 17 simulators available. Hotwire Native iOS 1.3.0 (released 2026-07-07) is current.
  `turbo-rails` 2.0.23 already ships `hotwire_native_app?` — no extra gem.
- **Success-signal prediction (falsifiable, time-bound):** by **Aug 8, 2026**, every
  reader-facing screen already built — daily, archive index, a day, the gallery, the
  collection, the 404 — renders inside the shell on an iPhone 17 simulator, and the app is
  installable on a physical device. Falsified if any screen needs a native
  reimplementation, if a bridge component turns out to be required to make the baseline
  work, or if the shell needs its own stylesheet.

  **Rewritten at design review, 2026-08-05.** The original prediction said "zero changes to
  any `.erb` view except chrome suppression." Design review falsified it before a line of
  Swift was written: `.zoom` is `position: fixed; inset: 0`, and under the current
  `viewport-fit=auto` that covers only the layout viewport, so the full-screen artwork
  renders framed by linen bands at the notch and home indicator — breaking the single
  exception `DESIGN.md` grants ("at full screen the picture is the room"). The fix is
  `viewport-fit=cover` in `app/views/layouts/_head.html.erb` plus safe-area padding, which
  is an `.erb` change and a change to the shipped website. Recorded here rather than
  quietly dropped: the prediction was wrong, and it was wrong for a reason worth keeping.
- **Lane:** Full (core). Target ≤ 2 days.

## Scope

**In:**
1. An Xcode project committed to this repo, opening in Xcode 26.5 with no extra tooling.
2. Hotwire Native iOS 1.3.0 via SPM, version-pinned.
3. A `Navigator` whose start URL comes from build configuration — not a hard-coded string.
4. Path configuration: bundled JSON that ships with the app, plus a remote copy served by
   Rails so routing rules can change without an App Store review.
5. The chrome decision — native navigation bar vs. the web masthead — resolved, written
   down, and enforced. See Open question below.
6. App icon and launch screen on linen (`DESIGN.md` tokens). The launch screen is the
   first frame of the product; a white default flash breaks the calm before the app opens.
7. An offline/unreachable state that reads as Tastemaker, not as a crashed WKWebView.
8. Rails side: whatever `hotwire_native_app?` needs to suppress duplicated chrome, plus
   the path-configuration endpoint. Minitest coverage for both (R1).

**Out — named, so it stays out:**
- **Push notifications.** Story 0009. It needs an APNs key, which needs the Apple
  Developer enrollment that does not exist yet.
- **Bridge components.** None of the six screens needs one. Building the bridge
  scaffolding before a screen demands it is *infrastructure for later*.
- **Native screens.** Same test: web-first until a screen proves it can't be.
- **Tab bar.** The product has one front door and a date link. Inventing a tab bar gives
  the shell a navigation model the web app does not have.
- **Widget.** Own spec, post-baseline (`CLAUDE.md`).
- **StoreKit / IAP.** Parked by the stack rules.
- **Android.** Not in the bet.

## Open question for the plan

**Does the shell show a native navigation bar?**

The web masthead (`app/views/daily/_day.html.erb:31`) is already the page's chrome: brand,
label, and a date that doubles as the door to the archive. A native nav bar above it would
put two titles on one screen, and its material is a second visual system —
`decisions/0003-one-skin.md` allows exactly one exception to the linen skin, the
full-screen artwork surround, and this is not it.

Suppressing native chrome and letting the web page own the whole screen is the position
this product's design argues for. It costs the native back button, which swipe-back and
the page's own walk links (`days/_walk`) may or may not adequately replace.

This is direction-level. It gets resolved in the plan, reviewed at
`/plan-design-review`, and written to `decisions/` either way (R4).

## Blocked on, and not by code

Two external dependencies gate the *outcome* of this story, neither of which building the
shell advances. Recorded here because the spec is the intake card and this is the honest
state of the intake:

1. **Apple Developer Program: not enrolled** (confirmed 2026-08-05). No App Store Connect
   record, no TestFlight, no submission, no APNs key. Enrollment runs on Apple's clock.
   Submission target is ~Aug 11 — **six days**.
2. **No VPS.** `config/deploy.yml` is rehearsed but carries three `CHANGEME` values. App
   Review requires a reviewer to open a working app; a shell pointed at a dead host is a
   rejection.

The shell builds and QAs on the simulator against `localhost:3000` without either. It
cannot ship to a human without both.
