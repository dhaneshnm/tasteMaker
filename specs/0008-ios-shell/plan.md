# 0008 — Implementation plan
Status: **Design-reviewed** (`/plan-design-review` 2026-08-05 — 5/10 → 9/10, 8 decisions,
codex outside voice absorbed). **Not yet eng-reviewed.**

## Approach

Seven Swift files, one JSON, one `.xcconfig` pair, one Rails static file, and one
safe-area change to the shipped stylesheet. No gem, no bridge component, no native screen,
no view rewrite.

The whole shell is the answer to one question — *what does iOS put on the screen that the
web page did not ask for?* — and the answer is: a navigation bar, a white view background,
a dark-mode flip, two grey spinners, iOS blue on every system control, and an error screen
in San Francisco. Each one is a second visual system inside a product whose written
position (`decisions/0003-one-skin.md`) is that it ships exactly one. So the shell's job is
mostly **subtraction**, and that is why it is small.

```
  Hotwire Native gives you            Tastemaker keeps
  ────────────────────────            ────────────────
  UINavigationController          →   yes, hidden bar (swipe-back survives)
  navigation bar + title          →   no — the masthead already is one
  view.backgroundColor .white     →   no — linen #f4efe6
  system dark mode                →   no — one skin, forced .light
  DefaultErrorView (SF, SwiftUI)  →   no — the empty state, transcribed
  grey activity + refresh spinner →   no — gold
  .accentColor iOS blue           →   no — window.tintColor = gold
  pull-to-refresh                 →   yes on /, no on /feed
  WKWebView + Turbo               →   yes. this is the entire product.
```

---

## The load-bearing decision: the shell shows no navigation bar

Not a preference. Four facts, each read out of Hotwire Native 1.3.0's source on
2026-08-05, not from documentation:

1. **`VisitableViewController.viewDidLoad` sets `view.backgroundColor = UIColor.white`**,
   and `HotwireWebViewController` overrides it to `.systemBackground`. Neither is linen.
2. **`visitableView` is pinned to `view`'s edges, not the safe area**
   (`VisitableViewController.installVisitableView`), and the web view fills the visitable
   view. So the strips behind the status bar and home indicator are painted by the view
   controller — today, **white above and below a linen page.**
3. **`application.css` contains no `prefers-color-scheme` rule** (verified: zero matches).
   In iOS dark mode the web page stays linen and every native surface flips to black.
4. **`DefaultErrorView`** is SwiftUI, `.largeTitle`, `.accentColor`, and says
   "Error loading page".

A navigation bar sitting above `app/views/daily/_day.html.erb:31` would also put two
titles on one screen — the bar takes `webView.title` ("Girl with a Pearl Earring —
Tastemaker") and the masthead already says `Tastemaker / Artwork of the Day`.

**Position:** the web page owns the whole screen. The bar is hidden, the interface style is
forced light, the view background is linen, and the error view is rewritten. This gets a
`decisions/` entry (R4) because it is direction-level and it constrains every screen built
after it.

### What hiding the bar costs, and how each cost is paid

| Cost | Payment |
|---|---|
| No native back button | `days/_walk` has prev · next · today; every screen renders `masthead__brand → root_path` (verified in `paintings/index`, `favorites/index`, `days/index`, `errors/not_found`). Nothing is a dead end. |
| **UIKit disables `interactivePopGestureRecognizer` when the bar is hidden** | `LinenNavigationController` re-enables it: `interactivePopGestureRecognizer?.delegate = self`, `gestureRecognizerShouldBegin` returns `viewControllers.count > 1`. Without this, swipe-back silently dies and the stack becomes one-way. Asserted in the QA pass. |
| Status bar content colour | `window.overrideUserInterfaceStyle = .light` makes `.default` resolve to dark content — legible on linen. One lever, two problems. |
| **The brand link would grow the stack forever** | Design review finding. See "Navigation model" below. |
| Modals get no dismiss affordance | Nothing is presented modally in this story's path configuration. |

---

## Navigation model (design review, decision 1)

On the web, `masthead__brand → root_path` means "home". In a native stack an ordinary link
is a **push**, so home becomes a fourth screen rather than a return:

```
/  →  /days  →  /days/2026-08-04  →  tap "Tastemaker"  →  / (a 4th screen)
                                                            swipe-back lands on a day,
                                                            not out of the app
```

Unbounded stack growth, and swipe-back — the only back affordance the hidden bar leaves —
walks backwards through duplicate front doors.

**Decision: `^/$` gets `"presentation": "clear_all"`.** It unwinds to the root that already
exists at the bottom of the stack rather than building a new one. Turbo revalidates the
restored root on reappear against the ETag the daily page already sets, so the cost is a
304, not a render.

`Navigation.Presentation` has no `push` case. The real enum is
`default, pop, replace, refresh, clear_all, replace_root, none`.

---

## Path configuration

**Patterns are unanchored regexes.** `PathRule.match` runs
`NSRegularExpression.numberOfMatches` with no anchoring, so a pattern of `"/"` matches
**every path in the product**. Every pattern below is anchored deliberately; `"^/admin"`
already covers `/admin/*`, so no second pattern is needed.

```json
{
  "settings": {},
  "rules": [
    { "patterns": ["^/$"],     "properties": { "presentation": "clear_all", "pull_to_refresh_enabled": true } },
    { "patterns": ["^/feed$"], "properties": { "pull_to_refresh_enabled": false } },
    { "patterns": ["^/admin"], "properties": { "presentation": "none" } }
  ]
}
```

- `/` keeps pull-to-refresh: "has today's arrived yet" is the one gesture this product's
  reader actually wants.
- `/feed` is infinite scroll; pull-to-refresh fights the scroll gesture at its top.
- `/admin` is HTTP Basic behind a browser auth dialog a WKWebView handles badly. No
  reader-facing link points there; the rule is insurance.
- Cross-origin links already route to `SafariViewControllerRouteDecisionHandler` by
  default — no rule needed.

One file, **two copies**, kept honest by a test:

- `public/configurations/ios_v1.json` — served by Rails as a static file, so navigation
  rules can change without an App Store review.
- `ios/Tastemaker/path-configuration.json` — bundled, so the app routes correctly on a
  cold launch with no network.

Loaded in order; remote last, because it resolves async:

```swift
Hotwire.loadPathConfiguration(from: [
    .file(Bundle.main.url(forResource: "path-configuration", withExtension: "json")!),
    .server(endpoint.appendingPathComponent("configurations/ios_v1.json"))
])
```

**Forcing function (R1):** `test/integration/path_configuration_test.rb` asserts the two
files are byte-identical and that the endpoint returns 200 with valid JSON.

---

## Safe areas: `viewport-fit=cover` (design review, decision 3)

**The defect.** `.zoom` is `position: fixed; inset: 0` (`application.css:592`) on
`#100e0b`. Under the current `viewport-fit=auto` (`_head.html.erb:16`), WebKit insets the
layout viewport out of the unsafe strips, so a `fixed; inset: 0` overlay stops below the
status bar and above the home indicator — and the view controller's linen shows through
both. `DESIGN.md`'s single accepted exception says *"at full screen the picture is the
room."* Linen bands are the wall.

Corroborating: `.zoom__close` already reads `max(0.9rem, env(safe-area-inset-top))`
(`application.css:614`). The author anticipated insets; no `viewport-fit=cover` was ever
set, so that `env()` has always resolved to 0. Mobile Safari hid this behind browser
chrome. The shell exposes it.

**Decision: `viewport-fit=cover`, with the padding it forces.**

| # | Change | File |
|---|---|---|
| 1 | `width=device-width,initial-scale=1,viewport-fit=cover` | `_head.html.erb:16` |
| 2 | `.masthead` top padding → `calc(0.9rem + env(safe-area-inset-top))` | `application.css:102` |
| 3 | Bottom padding on `.page` / `.coda` → `+ env(safe-area-inset-bottom)` | `application.css` |
| 4 | Landscape left/right insets on `.masthead` and `.page` | `application.css` |
| 5 | `.zoom__close` → `calc(env(safe-area-inset-top) + 0.9rem)`, **not** `max(...)` — under `cover`, `max()` lands the button flush against the boundary with no breathing room | `application.css:614` |

**Status bar during zoom:** dark glyphs on `#100e0b` become invisible. **Accepted.** It is
what every photo viewer does, and the alternative needs a bridge component to tell native
that a web overlay opened — which this story bans.

**Two consequences, named rather than discovered later:**

1. **This changes the shipped website, not just the shell.** Mobile Safari honours
   `viewport-fit=cover` too. Following the story 0004 precedent for app-wide changes, the
   safe-area work lands as **its own revertable commit**, separate from the shell.
2. **The fold budget must be re-verified on a notched device.** `test/system/daily_test.rb`
   runs at 375×667, where insets are 0 — it cannot catch a regression of the
   "art and text visible together" bar. Manual check on an iPhone 17 simulator.

---

## Native surfaces the shell owns (design review, decisions 2 and 4)

### Loading states

`VisitableView.activityIndicatorView` is `UIActivityIndicatorView(.medium)` with
`color = UIColor.gray`; `UIRefreshControl` defaults to system grey. Grey is not in the
token table. The cold-boot sequence a reader sees every day is: linen launch screen →
linen view controller → **grey spinner** → the page.

- `activityIndicatorView.color = .gold` (`#7d5f18`)
- `refreshControl.tintColor = .gold`
- `VisitableView.backgroundColor = .linen` **before** first access to
  `screenshotContainerView`, whose background is captured from `self.backgroundColor` at
  lazy-init — otherwise the app-switcher snapshot letterboxes in the wrong colour.

### System surfaces: global tint plus the three a reader can reach

- `window.tintColor = .gold` — removes iOS blue from every system control in one line:
  text-selection handles, share-sheet buttons, alert buttons.
- `SFSafariViewController` — `preferredBarTintColor = .linen`,
  `preferredControlTintColor = .gold`.
- **`WKUIDelegate`** — JavaScript `alert`/`confirm`/`prompt` and `target="_blank"`.
  This is not decoration: **without a `WKUIDelegate`, a `target="_blank"` link does
  nothing at all**, which reads as a broken app rather than an unstyled one.

**Explicitly not claimed** (see "NOT in scope"): context menus, share sheet layout, the
`/admin` HTTP auth challenge.

### Colour token

`#100e0b` is hardcoded at `application.css:599`. `DESIGN.md` rule 1 says colour comes from
the token table, and the native side now needs the same value. Add `--mount-bg: #100e0b`
to `:root`, use it in `.zoom`, and mirror it in `Assets.xcassets`.

### Accessibility

- Landscape safe-area insets — mandatory now that `cover` makes them real.
- **VoiceOver:** the native error view must render sentence-case text with
  `.textCase(.uppercase)`, **never an uppercase string literal** — VoiceOver spells
  `"TRY AGAIN"` letter by letter. The web is already safe here: `.caps-link` uppercases in
  CSS, so the DOM text stays sentence case.
- **Reduce Motion:** free. UIKit cross-dissolves pushes automatically, and WKWebView maps
  `prefers-reduced-motion`, which the CSS already honours (rule 7).
- **Smart Invert:** `overrideUserInterfaceStyle` does **not** disable it. iOS skips images,
  so the artwork survives and the page inverts. Test on device; do not opt out of a user's
  accessibility setting.
- **Dynamic Type: in scope** (design review, decision 5 — deferral overruled). The CSS
  sizes in `rem` against a fixed root, so iOS "Larger Text" has no effect in the shell.
  A `WKUserScript` sets the root font size from
  `UIApplication.shared.preferredContentSizeCategory`, and
  `UIContentSizeCategory.didChangeNotification` updates it live.

  **The cost this buys, stated plainly:** larger type pushes the note down against the
  55vh `.plate__img` cap, and "art and text visible together" is a Better-bucket quality
  bar — the one the category leader fails. `test/system/daily_test.rb` runs at 375×667 and
  **cannot** catch that regression. So this ships with **new coverage as part of the same
  unit of work** (R1): a system test that asserts the plate and the first line of the note
  are both above the fold at the largest non-accessibility content size category. If that
  test cannot be made to pass, the scaling is capped rather than the bar broken.

---

## Approved mockups

Board: `~/.gstack/projects/tasteMaker/designs/ios-shell-surfaces-20260805/board.html`

| Surface | Direction | Constraints from review |
|---|---|---|
| App icon | **A · the gold T** — Fraunces uppercase `T` in `#7d5f18` on linen, alone, display optical size (`opsz 144`) | Must hold at 29px. Not a new mark: `.masthead__brand::first-letter` already renders exactly this gold T on every screen. |
| Launch screen | **L2 · centred wordmark** — `TASTEMAKER` with the gold T, centred on linen, shipped as an image asset | Uses the plain `UILaunchScreen` Info.plist dict (background colour + centred image). No storyboard, no font bundling. |
| Offline / error | **E2 · the empty state, transcribed** — `——— ✦ ———` ornament, one Fraunces display-italic line at `--ink-dim`, a `.coda__note` line, gold `TRY AGAIN` at ≥44px | Structural twin of `daily/empty.html.erb`. Requires Fraunces + Newsreader bundled in the app target (both SIL OFL). Sentence-case source text. |

---

## File manifest

```
ios/
  Tastemaker.xcodeproj/project.pbxproj      objectVersion 77, synchronized file group
  Config/
    Shared.xcconfig                          bundle id, version, deployment target
    Debug.xcconfig                           TASTEMAKER_URL = http://localhost:3000
    Release.xcconfig                         TASTEMAKER_URL = CHANGEME (the VPS)
  Tastemaker/
    AppDelegate.swift                        Hotwire.config, path configuration load
    SceneDelegate.swift                      Navigator, window, forced .light, tintColor
    Endpoint.swift                           start URL from Info.plist, fails loudly
    LinenNavigationController.swift          hidden bar + swipe-back rescue
    LinenWebViewController.swift             linen background (4 layers), gold spinners
    LinenErrorView.swift                     E2, the empty state transcribed
    SafariPresenter.swift                    SFSafariViewController tint + WKUIDelegate
    Info.plist                               scene manifest, ATS, UILaunchScreen
    path-configuration.json                  bundled copy
    Fonts/                                   Fraunces + Newsreader (SIL OFL), for E2
    Assets.xcassets/                         AppIcon (A), Launch wordmark (L2),
                                             Linen / Ink / Gold / MountBg colour sets
```

**No XcodeGen, no Tuist, no Ruby project generator.** Xcode 26.5 supports
`PBXFileSystemSynchronizedRootGroup` (objectVersion 77), so the `.pbxproj` names the
folder, not every file in it.

**Deployment target: iOS 17.0.** The library floor is iOS 14 (`Package.swift`), so this is
our choice. Persona 2 (Jordan) is on an old cracked-screen iPhone — iOS 17 still covers
iPhone XS and later, which is 2018 hardware.

**Bundle ID: `com.dhaneshnm.tastemaker`**, matching the `dhaneshnm/tastemaker` registry
namespace already in `config/deploy.yml`. Must match the App ID registered in the Apple
Developer account that does not exist yet.

### The four layers that must all be linen

Setting `view.backgroundColor` alone is not enough. Overscroll rubber-banding exposes the
scroll view; the web view has its own background; a Turbo cold boot shows the VC's view
before any HTML paints.

```swift
view.backgroundColor               = .linen   // safe-area strips
webView.backgroundColor            = .linen   // between VC and page
webView.scrollView.backgroundColor = .linen   // overscroll bounce
webView.isOpaque = false                      // else the page's own white wins
```

---

## Rails-side changes

1. `public/configurations/ios_v1.json` — a static file. No controller, no route entry.
2. **`app/views/layouts/_head.html.erb`** — `viewport-fit=cover`. One line, and it is the
   change that falsified the story's original prediction.
3. **`app/assets/stylesheets/application.css`** — safe-area padding (items 2–5 above) and
   the `--mount-bg` token. Ships as its own commit.
4. **No new gem.** `turbo-rails` 2.0.23 already ships `hotwire_native_app?`
   (`app/controllers/turbo/native/navigation.rb:15`). The third-party
   `hotwire_native_rails` gem is not needed and is not added.
5. **No chrome suppression.** With the native bar hidden there is nothing duplicated, so
   `hotwire_native_app?` is not called anywhere in this story.

---

## Tests and forcing functions (R1)

**The problem:** `.github/workflows/ci.yml` runs entirely on `ubuntu-latest`. It cannot
compile Swift. An iOS target with no CI is an artifact without its enforcement.

1. `script/ios-build` — builds for an iPhone 17 simulator, exits non-zero on failure. This
   is what proves the hand-written `.pbxproj` is valid.
2. A `build_ios` job on `macos-latest` in `ci.yml` running that script. macOS runners bill
   at 10× minutes on private repos — named here rather than discovered.

Rails-side Minitest:
- `test/integration/path_configuration_test.rb` — endpoint 200, parses as JSON,
  byte-identical to the bundled copy.

Manual QA (`/qa`, step 6), simulator, six screens: `/`, `/days`, `/days/:date`, `/feed`,
`/collection`, a 404. Plus: cold launch with the server stopped (E2 error view), dark mode
toggled (stays linen), swipe-back after two pushes, `clear_all` from three deep, the empty
front door, **zoom on a notched device (no linen bands)**, landscape, Smart Invert,
Reduce Motion, VoiceOver on the error view.

---

## NOT in scope — considered and deferred

| Deferred | Why |
|---|---|
| Push notifications | Story 0009. Needs an APNs key, which needs Apple enrollment that does not exist. |
| Bridge components, native screens, tab bar | No screen has demanded one. Scaffolding first is the named failure pattern. |
| Widget | Own spec, post-baseline (`CLAUDE.md`). |
| StoreKit / IAP | Parked by the stack rules. |
| Android | Not in the bet. |
| Context menus, share-sheet layout, `/admin` auth dialog | Not reachable from the six current screens; global `tintColor` improves them anyway. |

**Two items moved OUT of this table at design review** (decisions 5 and 6):

- **Dynamic Type** is now in scope for this story, with its own fold-budget test. See
  Accessibility above.
- **Self-hosting Fraunces + Newsreader for the web** ships **before** this story, as its
  own spec. `_head.html.erb:29` pulls both from `fonts.googleapis.com` — an extra DNS +
  TLS handshake on every cold boot against a Better-bar that says "instant open", a
  fallback serif when offline, and a reader-IP leak to a third party on every launch.
  Both are SIL OFL, so self-hosting is licensed.

  **Ordering consequence, and it is a good one:** doing this first puts the font files in
  the repo *before* the shell needs them, so E2's bundled-font work becomes a copy rather
  than a sourcing job. **WIP=1 holds** because story 0008 is still at plan stage with no
  code written — the font story ships and closes first.

## What already exists — reuse, do not reinvent

- `daily/empty.html.erb` — the error view is a transcription of this, not a new idiom.
- `.masthead__brand::first-letter` — the gold T is already the brand mark. The icon is it.
- `.ornament`, `.coda__line`, `.coda__note`, `.caps-link` — the entire vocabulary E2 needs.
- `days/_walk` — prev · next · today, the back affordance the hidden bar relies on.
- `DESIGN.md` token table — every colour in the shell comes from it. No new colours.
- `test/system/design_test.rb` — the one-skin forcing function; unaffected by this story.

---

## Risks

| Risk | Mitigation |
|---|---|
| Hand-written `.pbxproj` rejected by Xcode | `script/ios-build` runs in the same session it is written |
| Swipe-back dies with the bar hidden | Explicitly rescued in `LinenNavigationController`; QA asserts it |
| `viewport-fit=cover` regresses the shipped website | Its own revertable commit; notched-device check on the fold budget |
| `.server()` path config fetch fails on cold launch | Bundled `.file()` source loads first and synchronously |
| ATS blocks `http://localhost:3000` | `NSAllowsLocalNetworking = true` — local-network hosts only, safe to ship |
| Smart Invert produces an unreadable page | Tested on device; documented rather than disabled |

## Sequence

1. ~~`/plan-design-review`~~ — done 2026-08-05, 5/10 → 9/10, 8 decisions.
2. `/plan-eng-review` — project layout, two-copy path config, macOS CI job, `WKUIDelegate`.
3. `decisions/0006-shell-shows-no-native-chrome.md` (R4).
4. Xcode project + `script/ios-build` green before any feature Swift.
5. Swift files, then the Rails static file + Minitest, then the safe-area commit.
   `bin/ci` and `script/ios-build` both green.
6. `/qa` on the simulator → fix. `/simplify` → `/code-review` → fix. Re-verify (step 8).
7. Commit, `SHIPLOG.md` line. **Marked "code only, not shipped"** — it is not on anyone's
   phone until enrollment and a VPS exist.

---

## Implementation Tasks
Synthesized from this review's findings. Each task derives from a specific finding above.

- [ ] **T1 (P1, human: ~1h / CC: ~10min)** — path-configuration — Anchor every pattern and give `^/$` `clear_all`
  - Surfaced by: Pass 1 — `PathRule.match` uses unanchored `numberOfMatches`, so `"/"` matches every path; the brand link pushes a duplicate front door
  - Files: `public/configurations/ios_v1.json`, `ios/Tastemaker/path-configuration.json`
  - Verify: `test/integration/path_configuration_test.rb`; QA — tap the brand from three screens deep, stack returns to root
- [ ] **T2 (P1, human: ~3h / CC: ~25min)** — web/css — `viewport-fit=cover` and safe-area padding, as its own commit
  - Surfaced by: Pass 3 — `.zoom` renders linen bands at the notch, breaking DESIGN.md's one accepted exception
  - Files: `app/views/layouts/_head.html.erb`, `app/assets/stylesheets/application.css`
  - Verify: QA — zoom on a notched simulator shows no linen band; fold budget re-checked on iPhone 17
- [ ] **T3 (P1, human: ~2h / CC: ~15min)** — ios/error-view — Build E2 with bundled fonts and sentence-case VoiceOver text
  - Surfaced by: D5 + Pass 6 — stock `DefaultErrorView` is SF/blue/white; an uppercase literal is spelled out by VoiceOver
  - Files: `ios/Tastemaker/LinenErrorView.swift`, `ios/Tastemaker/Fonts/`
  - Verify: QA — stop the Rails server, cold launch, VoiceOver reads "Try again"
- [ ] **T4 (P2, human: ~1h / CC: ~10min)** — ios/chrome — Gold spinners, linen snapshot, `window.tintColor`
  - Surfaced by: Pass 2 + Pass 4 — two grey spinners and iOS blue on every untinted control
  - Files: `ios/Tastemaker/LinenWebViewController.swift`, `ios/Tastemaker/SceneDelegate.swift`
  - Verify: QA — cold boot and pull-to-refresh both show gold; app-switcher snapshot is linen
- [ ] **T5 (P2, human: ~2h / CC: ~15min)** — ios/system-surfaces — `WKUIDelegate` + `SFSafariViewController` tint
  - Surfaced by: Pass 5 / codex 6 — without `WKUIDelegate`, `target="_blank"` does nothing at all
  - Files: `ios/Tastemaker/SafariPresenter.swift`
  - Verify: QA — an external link opens a linen-and-gold Safari sheet
- [ ] **T6 (P2, human: ~30min / CC: ~5min)** — design-system — Add `--mount-bg: #100e0b` token
  - Surfaced by: Pass 5 — the mount board is a legitimate exception but was never named
  - Files: `app/assets/stylesheets/application.css`, `ios/Tastemaker/Assets.xcassets`
  - Verify: `bin/ci` (`test/system/design_test.rb` stays green)
- [ ] **T7 (P2, human: ~1h / CC: ~10min)** — ios/assets — App icon A and launch wordmark L2
  - Surfaced by: D3 + D4 — the icon is the tap target in the only channel BET.md bets on
  - Files: `ios/Tastemaker/Assets.xcassets`, `ios/Tastemaker/Info.plist`
  - Verify: icon legible at 29px in Settings; no white flash before the linen page
- [ ] **T8 (P2, human: ~2h / CC: ~15min)** — ci — `script/ios-build` + `macos-latest` job
  - Surfaced by: Tests section — CI is ubuntu-only and cannot compile Swift (R1)
  - Files: `script/ios-build`, `.github/workflows/ci.yml`
  - Verify: the job fails on a deliberately broken `.pbxproj`
- [ ] **T9 (P3, human: ~2h / CC: ~20min)** — a11y — On-device Smart Invert / Reduce Motion / Bold Text pass
  - Surfaced by: Pass 6 / codex 3 — forced `.light` does not disable accessibility transforms
  - Files: none (verification task); findings go to `specs/0008-ios-shell/plan.md`
  - Verify: documented result per setting, on a real device
- [ ] **T10 (P2, human: ~1d / CC: ~40min)** — a11y — Dynamic Type via `WKUserScript`, with a fold-budget test
  - Surfaced by: decision 5 — deferral overruled; iOS Larger Text currently has no effect in the shell
  - Files: `ios/Tastemaker/LinenWebViewController.swift`, `app/assets/stylesheets/application.css`, `test/system/daily_test.rb`
  - Verify: new system test — plate and first line of the note both above the fold at the largest non-accessibility content size category
- [ ] **T0 (P1, human: ~1h / CC: ~10min)** — web/fonts — Self-host Fraunces + Newsreader, **ships before this story**
  - Surfaced by: decision 6 — CDN handshake on every cold boot against the "instant open" bar; fallback serif offline; reader-IP leak
  - Files: `app/views/layouts/_head.html.erb`, `app/assets/fonts/`, new spec `specs/0009-self-hosted-fonts/`
  - Verify: `bin/ci`; no request to `fonts.googleapis.com` in the network log on cold load
  - Note: needs its own story + intake fields before code (CLAUDE.md build flow). Renumbers push to 0010.

---

## GSTACK REVIEW REPORT

| Review | Trigger | Why | Runs | Status | Findings |
|--------|---------|-----|------|--------|----------|
| CEO Review | `/plan-ceo-review` | Scope & strategy | 0 | — | — |
| Codex Review | `/codex review` | Independent 2nd opinion | 3 | ISSUES | outside voice absorbed into this review |
| Eng Review | `/plan-eng-review` | Architecture & tests (required) | 3 | CLEAR (PLAN) | **stale — 11 commits behind, reviewed story 0006, not 0008** |
| Design Review | `/plan-design-review` | UI/UX gaps | 4 | CLEAR (FULL) | score: 5/10 → 9/10, 8 decisions |
| DX Review | `/plan-devex-review` | Developer experience gaps | 0 | — | — |

Pass scores: Info Arch 5→9 · States 4→9 · Journey 6→9 · AI Slop 8→10 · Design System 5→9 ·
Responsive/a11y 4→8 · Decisions 8 resolved, 0 deferred.

**CODEX:** 7 findings, no hard rejections, 7/7 litmus checks pass. Independently confirmed
the `viewport-fit` zoom defect and contributed three the first-party review missed: Smart
Invert survives `overrideUserInterfaceStyle`, `.zoom__close`'s `max()` is wrong once insets
are real, and the unclaimed native system-surface inventory.

**CROSS-MODEL:** the `.zoom` safe-area defect was found independently by both passes from
different directions — first-party from `PathRule`/`VisitableView` source reading,
codex from WebKit's `viewport-fit` semantics. Treated as confirmed, not plausible.

**VERDICT:** DESIGN CLEARED — 9/10, 0 unresolved. **Eng review required before implementation:**
the logged eng review predates this story by 11 commits and covers story 0006.

NO UNRESOLVED DECISIONS

---

## Implemented 2026-08-07 — deviations from this plan

Recorded here rather than fixed silently. Each of these changed the plan, not just
the code.

### 1. T5's premise was stale: the library already ships a `WKUIDelegate`

The plan says "without a `WKUIDelegate`, a `target="_blank"` link does nothing at all."
True in general, already handled in 1.3.0. `Navigator` installs one itself
(`Navigator.swift:136–138`, `webkitUIDelegate = WKUIController(delegate: self)`), and
`NewWindowWebViewPolicyDecisionHandler` is registered by default and routes new-window
navigations through the navigator. So no `SafariPresenter.swift` was written.

What *did* need writing is narrower and different: the library's
`SafariViewControllerRouteDecisionHandler` sets `preferredControlTintColor = .tintColor`
— which resolves to the window tint, so gold comes for free — but never sets
`preferredBarTintColor`, leaving a white bar above a linen app. That class is `final`,
so the only way to change it is to replace it. Hence
`LinenSafariRouteDecisionHandler.swift`, registered ahead of the default set.

### 2. woff2 cannot be used on iOS — the fonts are not a copy job after all

The plan's ordering argument for shipping story 0009 first was that E2's bundled fonts
would become "a copy rather than a sourcing job". Half right. Story 0009 ships **woff2**,
and iOS cannot load woff2 at all — `UIAppFonts` needs TTF or OTF.

They are still not a sourcing job, because the same latin subsets convert directly. What
ships in `ios/Tastemaker/Fonts/` is two **static instances** cut from story 0009's own
files: `Fraunces-Italic` at `opsz 18 / wght 400` and `Newsreader-Regular` at
`opsz 16 / wght 400`, 96 KB together. Static rather than variable because the error view
uses exactly two sizes, and the full variable families would have been ~1.5 MB for four
lines of text.

### 3. The app icon uses `opsz 60`, not the board's `opsz 144`

The board specified display optical size. Rendered and compared at 29px, `opsz 144`'s
hairline serifs go thin and grey; `opsz 60` holds. Since `opsz 60 / wght 560` is exactly
what `.masthead__brand` renders, this is also the more faithful reading of "not a new
mark — the gold T is already the brand mark." The board's constraint ("must hold at
29px") beat the board's parameter.

### 4. The synchronized group needs an `Info.plist` exception

`PBXFileSystemSynchronizedRootGroup` sweeps in every file under `Tastemaker/`, including
the `Info.plist` that `INFOPLIST_FILE` already processes — two commands producing one
output, which is a hard build error, not a warning. Fixed with a
`PBXFileSystemSynchronizedBuildFileExceptionSet` listing `Info.plist`.

### 5. Dynamic Type caps at 1.25, not 1.35

The plan set the cap at 1.35 and said that if the fold-budget test could not pass, "the
scaling is capped rather than the bar broken." It could not. Measured against a 667px
fold, the note's first line lands at:

| scale | root | slack |
|---|---|---|
| 1.20 | 19.2px | +31px |
| 1.25 | 20.0px | +19px |
| 1.30 | 20.8px | +8px |
| 1.35 | 21.6px | **−4px, over the fold** |

1.30 fits, but only by 8px against a single fixture note, and note and title lengths vary
with every artwork. That is a coincidence, not a cap. **1.25.**

### 6. The fold budget had never actually been tested — two suite defects

Found while building T10's test, and much the most important thing in this list.

**`test/fixtures/paintings.yml` shipped a 1×1 pixel PNG** under a comment reading "real
pixels for system tests". `.plate__img` is `width: auto; height: auto`, so the `width`
and `height` attributes only set an aspect ratio — they do not override an intrinsic
size. The plate laid out at 1×1 (3px with its border). Every fold assertion in the suite,
including `daily_test.rb`'s "the artwork and the note share the first screen", was
measuring a page with no artwork in it. Replaced with an inline 800×1000 PNG, 396 bytes
of base64, matching the `image_width` / `image_height` the fixture already declared.

**`ApplicationSystemTestCase` ran at a 524px viewport** while its failure messages said
375×667. `driven_by ... screen_size:` sets the *window*, and headless Chrome takes ~143px
off the top for its own chrome — a viewport tighter than any real device, and much
tighter than the shell, which has no chrome at all. Now resized in `setup` until
`window.innerHeight` is genuinely 667.

With both fixed, **Better bar 2 holds at the default text size** — the product was fine,
the test was not. But it had been green for the wrong reason since story 0001, and that
is the failure mode R1 exists to prevent: the artifact was there, the enforcement was
not.

### 7. The macOS CI job is its own workflow, not a job in `ci.yml`

GitHub Actions has no per-job `paths` filter, so a `build_ios` job inside `ci.yml` would
run on every commit — and the plan's own cost note (10× billing on private repos) was the
reason to avoid that. It is `.github/workflows/ios.yml`, filtered to `ios/**`,
`script/ios-build`, and itself, plus `workflow_dispatch`.

It builds against `generic/platform=iOS Simulator` rather than a named device: which
simulators a runner image ships changes without notice, and the job exists to prove the
project compiles.

`script/ios-build` was verified to fail as intended — exit 74 against a deliberately
corrupted `.pbxproj`.

### 8. Verified on the simulator, and what was not

Verified against `localhost:3000` on an iPhone 17 simulator, with screenshots:

- The daily page renders with no native navigation bar, linen through the notch strip,
  dark status-bar glyphs, both typefaces, the gold masthead T.
- **Dark mode stays linen** — forced `.light` holds across the whole app.
- **The E2 error view**, cold-launched with the Rails server stopped: linen, gold
  ornament, Fraunces italic line, Newsreader note, gold `TRY AGAIN`. Bundled fonts load.
  No San Francisco, no iOS blue, no white.
- **The launch screen** is the linen wordmark with the gold T. No white flash.
- Navigation to a past day pushes correctly.

**Not verified, and this is the honest gap.** Driving taps on the simulator needs
Accessibility permission this environment does not have (System Events returns `-25204`),
so everything below is still exactly as manual as the plan said it was:

- **Zoom at the notch** — the single thing the `viewport-fit=cover` work exists for.
  Nothing has yet confirmed the linen bands are gone.
- Swipe-back after two pushes, and `clear_all` from three deep.
- Landscape safe-area insets.
- Smart Invert, Reduce Motion, VoiceOver on the error view (T9).
- The fold budget on a real notched device at 874pt rather than the suite's 667.

### Still not done from the plan's sequence

- `/plan-eng-review` (build flow step 4) was never run on this plan.
- `/qa`, `/simplify`, `/code-review` (build flow steps 6–7) were not run.
