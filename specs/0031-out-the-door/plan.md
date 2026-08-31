# 0031 — Out the door — plan

Story: `story.md`. Owner decisions 1–5 there are fixed inputs; this plan does not
reopen them. Deviations found at implement time get noted back here.

## Shape of the thing

One new button in the existing rail, on all four keep surfaces. The web renders it for
**everyone, hidden** — markup byte-identical for shell and browser, so `/`'s public
cache contract is untouched. (`/` is the only public one — `/days/:date` went
`private_revalidate` behind the wall in story 0015; the contrary claim in
`favorites/_control.html.erb`'s comment is stale, eng review E2, fixed in this story.) The Hotwire Native bridge
reveals it only inside a shell that registered a `share` component (1.2+). Old
binaries (1.0/1.1) never registered it, so the button stays hidden there too — **no
server-side version gate needed**; the bridge handshake *is* the gate.
(`shell_version_at_least?` stays untouched.)

Tap → bridge message `{text, url, imagePath}` → native `ShareComponent` presents
`UIActivityViewController` immediately, full-res image resolving inside it (step 4).

## The link target — corrected twice, read the history

There is no `paintings#show`. (**Deviation note, merge time 2026-08-31:** story 0030
"the permanent address" merged `paintings#show` to main while this story was in its
worktree — but that page sits behind `require_reader`, same wall as `/artists/:slug`,
so E1's conclusion holds unchanged: a share link there would still bounce recipients
to sign-in. Link target stays `root_url`. The premise sentence above is stale; the
reasoning is not. Second effect of the same merge: `/paintings/:id` reuses
`paintings/_painting` verbatim, so Share renders on a FIFTH surface the
story's "all four keep surfaces" never named — deliberate, the control
travels with the partial and the page is walled like the other four.) First draft chained published-day-page → root. **Eng
review (E1, 2026-08-31) killed the chain: `/days/:date` is WALLED** — only
`daily#show` skips `require_reader` (`application_controller.rb:51`,
`daily_controller.rb:7`); every other surface 303s a cookieless visitor to `/you`
(story 0015, retargeted 0017). A share link that lands a recipient on sign-in doors
is anti-distribution, and the artist page was already banned for the same reason
(story 0018 X3).

So: **the link is always `/?via=share`** — the product's one unwalled artwork page.
The recipient sees today's work, not necessarily the shared one; accepted, because
the shared *image* carries the artwork and the link's job is the door back to the
app. This also deletes the DailyPick lookup, the per-page batch map, and both
controller edits the chain needed — the helper is now a pure function of the
painting.

Unwalling `/days/:date` for anonymous recipients would be the stronger distribution
answer — but it reverses the 0015 wall, which is an owner direction call, not a
review edit. Parked in NOT-in-scope.

## Steps

**0. Decision entry (R4).** `decisions/0021-first-bridge-component.md`: the shell
gains its first bridge component. Position: image-file share sheets are a
native-only capability (Web Share API file support inside WKWebView unverified;
owner rejected the spike 2026-08-31), which meets the stack rule's "genuinely
required" bar. Prediction: the story.md success signal, verbatim.

**1. Web helper — `share_payload_for(painting)`** (`ApplicationHelper`). A pure
function of the painting — no day param, no queries, no controller changes (eng
review E1 simplification). Returns `{ text:, url:, image_path: }`:
- `text` = `painting.alt_text` — already `"Title — Artist"` with the placeholder-artist
  fallback (`artist_display`) story 0018 hardened; a second title-plus-artist string
  would be a drifting copy (design review, 2026-08-31).
- `url` = `root_url(via: "share")`, always (see link-target section above).
- `image_path` = `artwork_src`'s own rule at full size (outside voice C1):
  `painting.image.attached? ? url_for(painting.image) : painting.image_url_800`.
  The first draft always called `url_for(painting.image)`, which **raises for a
  work serving from the museum CDN fallback** — `display_image?` is true for
  either source (`painting.rb:277-279`), and the suite even keeps a
  remote-only painting on purpose (`painting.rb:257`). Relative blob path or
  absolute CDN URL both fine: the shell resolves against its base URL and an
  absolute URL passes through. Cookie-less native download is safe by design:
  Active Storage controllers do not inherit the walled `ApplicationController`,
  and blob URLs are signed capability URLs (`application_controller.rb:47-50`,
  eng review A3 of story 0015 — verified, not assumed).

**2. Web partial — `shared/_share.html.erb`** rendered in both rails, only when
`painting.display_image?` (a resting work has no file to share). A plain
`<button type="button">` — not `button_to`: no form, no CSRF token, no session,
nothing that could poison the public cache. Carries `data-controller="bridge--share"`,
the payload as data attributes, and `aria-label="Share #{painting.title}"`.

**Position (design review D1, 2026-08-31): Share sits immediately LEFT of the keep
frame, everywhere.** On `/` and `/days/:date` the rail reads **Zoom · Share ·
Keep · count**; on `/feed` and `/artists/:slug`, **Share · Keep**. Not taste —
DESIGN.md's own rule: keep and its count share one Turbo frame that grows ~60px when
the private fragment lands with a count, and "last position means there is nothing to
its right to shove." A share button to the keep frame's right would be shoved on
every open, for exactly the reader with a collection — the documented bug, reintroduced.
Left of the frame, nothing moves when the count arrives.

**Glyph (design review D4): the platform's own square-and-arrow, redrawn in the house
hand** — 1.4px stroke, 23px drawing in the 44px `--tap` target, `--gold`, same
`_oculus`-style authored SVG as keep and zoom, no SF Symbol pasted in. The rail is
label-less and only `/`'s count word teaches glyphs; share's meaning must arrive
pre-taught, and the square-and-arrow is the one mark every iOS reader already knows.
An invented brand glyph here would be unlearnable. **Share is a momentary action, not
a toggle: no filled state, no `aria-pressed`** — fill is the house marker for state
(keep, the wing door) and share has none.

**3. Web bridge JS.** `bin/importmap pin @hotwired/hotwire-native-bridge` (vendored,
no node toolchain — stack-clean). `controllers/bridge/share_controller.js` extends
`BridgeComponent`, `static component = "share"`; on tap, `this.send("share", payload)`.

**Reveal — IMPLEMENTED DIFFERENTLY THAN DESIGNED, and simpler.** Design review D3
(and outside voice C3's amendment) called for a bespoke native `WKUserScript`
stamping a dataset attribute at document-start, reasoning that the bridge
package's own `data-bridge-components` dataset arrives too late (after
`setAdapter()`, post-JS-evaluation) to be pre-paint-safe.

Reading the actual vendored `hotwire-native-ios` 1.3.0 source instead of the
public docs found a simpler, already-existing mechanism that makes the bespoke
script unnecessary: `HotwireConfig.userAgent` (`UserAgent.swift`) folds
`"bridge-components: [\(names)]"` into the string the library sets on
`WKWebViewConfiguration.applicationNameForUserAgent` **before the web view is
created, let alone before any request is sent** — the same string
`ApplicationController::NATIVE_UA_TOKEN` parsing already trusts server-side, and
literally the string the bridge package's own `BridgeComponent.shouldLoad` reads
client-side via `navigator.userAgent` to decide whether to connect a Stimulus
controller at all. `navigator.userAgent` is a browser-engine-level property,
fully formed before any script runs — so a **plain inline `<script>` in
`layouts/_head.html.erb`**, reading `navigator.userAgent` and stamping
`document.documentElement.dataset.shellShare`, is pre-paint by the same
guarantee the library's own gate relies on. No Swift script, no
`WKUserScript`, no native code change beyond `Hotwire.registerBridgeComponents`
(which is what puts the string in the UA in the first place).

CSS: `html[data-shell-share] .rail__act.rail__share { display: inline-flex; }`.

This is simpler than the plan, more robust than the design review's amendment
(no dependency on the bridge JS's adapter-handshake timing at all — a pure,
synchronous UA string match), and was caught by building against the real SPM
checkout rather than trusting documentation. `decisions/0021`'s prediction is
unaffected; this only changes the reveal's plumbing, not the feature's shape.

**4. Native `ShareComponent.swift`.** `BridgeComponent` subclass, name `"share"`.
On `share` message: resolve `imagePath` against the web view's base URL and **present
the sheet immediately** (design review D2). The first plan draft downloaded the
full-res image first and let "the sheet just arrive when ready" — over cellular a
museum original is seconds of silence after the tap, which reads as a dead button and
earns a second tap. Instead: `UIActivityViewController` opens on tap with the text +
URL items live and the image as a **`UIActivityItemProvider` subclass** — precise
semantics per Apple docs, not hand-waved (outside voice C4): `item` is a
*synchronous* property invoked on a secondary thread when the reader picks a
target; it may block. Ours blocks on a `URLSession` download with a 10s timeout
and returns the `UIImage`; on failure or timeout it must still return `Any`, so it
returns the share URL — the target app gets a second link instead of an image. The
`placeholderItem` is the share URL for the same reason. No alert, no crash, no
spinner of ours. Set the iPad popover anchor defensively (iPhone
app, but it runs on iPad). **Re-entrancy guard (eng review E3): bail if a sheet is
already presented** (`presentedViewController == nil` check) — a double-tap must not
stack two activity controllers.
Register in `AppDelegate.configureHotwire()`:
`Hotwire.registerBridgeComponents([ShareComponent.self])` — and update the
`makeCustomWebView` comment that currently says "none are registered", which this
step makes false.

**5. Version.** `MARKETING_VERSION` 1.1 → 1.2 (`ios/Config/Shared.xcconfig`).
Marker only — nothing server-side reads it for this feature (see Shape).
`path-configuration.json` untouched: the share sheet is not a navigation event.

**6. Tests (R1, with the code not after it).**
- Helper: `url` is always `root_url(via: "share")` (a day-picked AND an unpicked
  painting — the test that would catch the walled-chain bug returning), `text` is
  `alt_text` (one placeholder-artist case), `image_path` both ways: attached →
  original blob path, **remote-only → `image_url_800`** (outside voice C1 — the
  suite already keeps a remote-only painting, `painting.rb:257`).
- System (Capybara): button present-but-hidden on all four surfaces for a plain
  browser; absent for a resting work; visible once the reveal condition is simulated
  (set `data-shell-share` on `<html>` via `execute_script` — standing in for the
  inline UA-reading script in `layouts/_head.html.erb`, see Steps); rail order
  asserted: share left of the keep frame on every surface; clicking the revealed
  button in a browser with no native adapter (the real UA is untouched by the
  stand-in) is a safe no-op — `BridgeComponent.shouldLoad` never connects the
  controller at all. Shipped as `test/system/share_test.rb`.
- Integration: extend `public_cache_headers_test` — `/` still carries no
  `Set-Cookie`, still `public`, share markup byte-identical with and without the
  shell UA. (`/days/:date` is private since 0015 — eng review E2 — so it gets the
  markup assertion only, not the public-cache one.)
- Existing `daily_test` / `dynamic_type_test` / `feed_test` assertions about the
  rail may enumerate its children — update them to the new order deliberately, do
  not loosen them.
- Native half has no CI; it is covered by step 7.

**7. Device QA (LAN, owner-run — agent shell can't drive the device).** Script:
share from all four surfaces; **double-tap share → exactly one sheet (E3)**; cancel
mid-sheet; **tap share, immediately navigate back before the sheet finishes
presenting → no crash** (code review, adversarial pass — the destination-torn-
down race); share → Messages actually delivers image + text + link; recipient link
opens `/` anonymously (no wall bounce); resting work shows no button; web Safari
shows no button; airplane mode → text-only sheet, no crash; **share on a slow
connection, dismiss the sheet before the image resolves → no stall** (code
review — proves the `cancel()` fix actually shortens the wait); 1.1 binary
against new server → no button (bridge-gate proof).

**8. Pipeline.** `/plan-design-review` on the glyph + rail placement (new visible
control on the flagship screen — not skipping); `/plan-eng-review`; implement;
`bin/ci`; `/qa`; `/simplify`; `/code-review`; re-verify `bin/ci` + smoke.

**9. Ship.** Deploy web (owner runs kamal — agent shell lacks secrets); archive 1.2,
TestFlight, App Review; `SHIPLOG.md` line with receipt once the binary is out. The
web half can deploy first and sits inert (button hidden everywhere) until 1.2 lands —
no coordination window.

## What the reader sees, state by state (design review, 2026-08-31)

| Moment | Reader sees |
|---|---|
| Tap share | Sheet opens at once — targets live, text + link ready, image resolving behind the provider |
| Double-tap | One sheet, not two — second tap swallowed by the re-entrancy guard (E3) |
| Slow network | Sheet already open; the chosen app waits on the provider, ≤ 10s |
| Download fails / times out | Share goes through as text + link; no alert, no toast |
| Cancel | Sheet dismisses; nothing else changes, focus where it was |
| Share completes | Nothing from us — iOS gives the feedback; the rail stays calm (DESIGN rule 5 spirit) |
| Resting work (no image) | No share button at all |
| Web browser / 1.0–1.1 shell | No button, no reserved gap — rail identical to today |

## NOT in scope (design review)

- A share **count** or any social proof surface — no social graph, settled.
- A confirmation toast/haptic after sharing — iOS's own sheet feedback suffices;
  anything more violates the calm bar.
- A third-party share-preview card (Open Graph tags for the day page) — worth doing
  someday for link unfurls, separate story; the shared *image* already carries the art.
- A brand-drawn share metaphor glyph — rejected in D4, recorded here so it is not
  re-invented at implement time.
- **Unwalling `/days/:date` so recipients land on the exact shared artwork** — the
  stronger distribution move, but it reverses the story 0015 wall: owner direction
  call, own decisions entry, not a review edit (eng review E1).

## What already exists and gets reused

- `Painting#alt_text` — the share text, verbatim.
- `.rail` / `.rail__act` CSS — button chrome, `--tap` sizing, hover, gold — no new
  component class beyond `.rail__share` for the reveal hook.
- The `_oculus`-style authored-SVG glyph contract (23px / 1.4px / 44px).
- `favorites/_control` cache split — untouched; share never enters the keep frame.
- `AppNavigationRouteDecisionHandler` etc. — no routing change; share is not navigation.

## Risks

- **Stamp/bridge mismatch** (step 3): the reveal script and the component
  registration both derive from the same `Hotwire.registerBridgeComponents` call
  in the same binary — there is no second source of truth to drift out of sync.
  The residual case (UA claims `share`, but the bridge's own adapter handshake
  hasn't completed yet) still degrades safely: `share_controller.js` extends
  `BridgeComponent`, whose `send()` no-ops without a connected adapter. Low.
- **Blob URL expiry — corrected (outside voice C5):** blob *redirect* URLs are
  permanent signed-id URLs unless `urls_expire_in` is configured (it is not); the
  short expiry lives on the disk-service URL minted fresh per redirect, which
  `URLSession` follows immediately. A day-old backgrounded page still downloads.
  Non-risk unless that config changes.
- **App Review**: share sheet is standard; no new entitlements, no new privacy-label
  surface (nothing leaves the device except via the user's own chosen share target).

## Failure modes (eng review, per new codepath)

| Codepath | Realistic failure | Test? | Handled? | Reader sees |
|---|---|---|---|---|
| Helper URL | wall bounce for recipient | unit (E1 regression) | link is always `/` | artwork, not sign-in |
| CSS reveal | stamp present, bridge dead | system no-op test | `this.enabled` guard | button that does nothing, no crash |
| Image path | remote-only work, no blob | helper unit (C1) | `image_url_800` branch | share works from CDN copy |
| Bridge send, web | no native adapter | system no-op test | BridgeComponent guard | nothing (correct) |
| Image download | timeout / 404 / airplane | device QA | provider resolves text+link | share still goes out |
| Sheet present | double-tap | device QA | E3 re-entrancy guard | one sheet |
| Old binary | no `share` component | device QA (1.1 proof) | attribute never set | no button |

No silent-failure critical gaps: every failure lands on "share proceeds degraded" or
"button absent," both visible states in the table above.

## Parallel lanes (worktree strategy)

| Step | Modules touched | Depends on |
|---|---|---|
| Web (steps 1–3, 5, 6) | app/, config/, test/ | — |
| Native (steps 4, 5) | ios/Tondo/, ios/Config/ | payload shape from step 1 |

Lane A: web half. Lane B: native half — only the message contract (`{text, url,
imagePath}`, component name `"share"`) couples them; fix the contract in this plan
(done) and the lanes are independent. WIP=1 (R5) means one branch either way —
lanes are an ordering freedom inside this story, not two stories.

## Implementation Tasks

Review findings, already folded into steps above; tracked here for /autoplan.

- [x] **T1 (P1)** — rail — share slot LEFT of keep frame, both rails (step 2; design D1)
- [x] **T2 (P1)** — native — immediate sheet + `UIActivityItemProvider` image (step 4; design D2)
- [x] **T3 (P1)** — reveal — inline UA-reading script in `layouts/_head.html.erb` stamps `data-shell-share`; CSS gates on it. Implemented differently than designed: no native `WKUserScript` needed — `navigator.userAgent` already carries `bridge-components: [share]` pre-paint, verified against the vendored SPM source (step 3, see "Steps" for the full correction).
- [x] **T4 (P2)** — glyph — square-and-arrow authored at 23px/1.4px/`--gold` (step 2; design D4)
- [x] **T5 (P2)** — helper — reuse `Painting#alt_text` as share text (step 1)
- [x] **T6 (P1)** — helper — link always `root_url(via: "share")`; regression test for the walled-chain bug (eng E1)
- [x] **T7 (P1)** — native — re-entrancy guard, one sheet on double-tap (eng E3)
- [x] **T8 (P3)** — comments — fix stale "days is public" claim in `favorites/_control.html.erb` (eng E2)
- [x] **T9 (P1)** — helper — `image_path` falls back to `image_url_800` for remote-only works (outside voice C1)
- [x] **T10 (P2)** — native — `UIActivityItemProvider` subclass returns URL on failure, never nil (outside voice C4)

## Implementation status (2026-08-31)

All ten tasks shipped in this branch. Web half: `app/helpers/application_helper.rb`
(`share_payload_for`), `app/views/shared/_share.html.erb`, wired into `daily/_day`
and `paintings/_painting`; reveal via a plain inline script in `layouts/_head`
(simpler than designed — see the Steps section's correction); CSS in
`application.css`; Stimulus controller `app/javascript/controllers/bridge/
share_controller.js`; `@hotwired/hotwire-native-bridge` pinned via importmap.
Native half: `ios/Tondo/ShareComponent.swift` (+ `ShareImageItemProvider`),
registered in `AppDelegate.swift`; `MARKETING_VERSION` → 1.2. **Native half
compiles clean** — `xcodebuild ... build` verified against the real
`hotwire-native-ios` 1.3.0 SPM checkout, zero warnings on touched files (no
XCTest target exists in this shell; matches the thin-shell architecture).

Tests written alongside (R1): 6 new helper-unit cases, 6 new system-test cases
(`test/system/share_test.rb`), 1 new integration case extending
`public_cache_headers_test`. One pre-existing system test
(`favorites_test.rb`'s rail-wrap geometry check) needed a one-line visibility
filter — its raw `querySelectorAll` started counting the new hidden button's
0×0 rect as a second row; fixed, not loosened.

`bin/ci` — **green**: rubocop 152 files/0 offenses, bundler-audit clean,
importmap audit clean (covers the new pinned package), brakeman 0 warnings,
`bin/rails test` 670 runs/3074 assertions/0 failures/0 errors (1 pre-existing
unrelated skip), `bin/rails test:system` 72 runs/0 failures.

Not run from this shell (device-dependent, owner action per `specs/0031-out-
the-door/plan.md` step 7 and CLAUDE.md's session-start gates): the LAN device
QA script, TestFlight/App Review, `kamal` deploy, `SHIPLOG.md` entry.

## /simplify and /code-review (2026-08-31, per build flow steps 6-7)

**`/simplify`** — 4 parallel agents (reuse, simplification, efficiency, altitude).
One fix applied: `share_payload_for`'s `image_path:` had hand-copied `artwork_src`'s
attached/CDN-fallback conditional instead of calling it — now just
`image_path: artwork_src(painting)`. Two findings evaluated and skipped with
reasoning recorded inline at the call sites: the extra `artwork_src` call this
adds per painting per render matches `shared/_plate.html.erb`'s own existing
pattern (it already recomputes independently rather than accepting a threaded
value) and costs an in-memory signed-ID computation, not I/O; `ShareComponent`'s
`message.event == "share"` guard is unreachable-false today but validates
against the `Message` protocol's own `event` field, which is designed to carry
more than one value. Altitude review: clean, zero findings.

**`/code-review`** — Codex (both the adversarial pass and the 200+-line
structured pass) hit its usage quota mid-run (resets late Sep 2026) and could
not run; the review proceeded on the Claude adversarial subagent plus a manual
critical-pass read against the checklist (SQL/race/LLM-trust/shell-injection/
enum-completeness — none apply to this diff; no unsafe HTML rendering, no
server-side UA branching that could poison `/`'s public cache).

The adversarial subagent verified — not just trusted — the XSS surface (ERB
auto-escaping through to Swift `Decodable`, no `html_safe`/`raw` anywhere),
the cache-poisoning surface (`share_payload_for` depends on nothing
per-visitor; `via` is never read server-side; the new integration test pins
byte-identical `/` output), the double-tap guard's actual thread-safety
(bridge messages serialize on main), and URL-scheme isolation (painting data
never reaches the `URL(string:)` call that becomes the shared link — only the
image fetch). One real, verified bug and one real design gap survived:

- **Fixed — `ShareImageItemProvider` never implemented `cancel()`.**
  `UIActivityItemProvider` is an `Operation` subclass; `UIActivityViewController`
  calls `cancel()` on it when the sheet closes before the item resolves, but a
  synchronous, already-blocked `item` getter never observed that call — an
  ordinary "share, then dismiss" or "share, then background the app" left the
  operation-queue thread parked in `semaphore.wait()` for up to the full 10s
  timeout regardless. Now overrides `cancel()` to cancel the in-flight
  `URLSessionDataTask`, whose completion handler signals the semaphore
  immediately instead of waiting out the timeout.
- **Fixed — the reveal script's UA regex used `\bshare\b`, not the framework's
  actual matching rule.** The vendored bridge JS's own gate does
  `.split(" ").includes(component)` — exact space-token match. The word-boundary
  regex would also have fired for a hypothetical future component named e.g.
  `"photo-share"`, which the real `shouldLoad` gate correctly rejects — a
  self-healing "safe no-op" today (button visible, controller never connects,
  only one component exists), but a second, non-equivalent reimplementation of
  a rule with one canonical source. Rewritten to capture the bracketed list
  and `.split(" ").includes("share")`, mirroring the framework exactly.
- **Skipped, noted rather than fixed — no allowlist on `image_url_800` before
  the native `URLSession` fetch.** For a remote-only painting this string is
  museum-API JSON, never validated for scheme/host anywhere in the ingest
  pipeline (`lib/pool/sources.rb`). Previously it only ever became an `<img
  src>` (browser-sandboxed); this story is the first time native code fetches
  it directly. Not exploitable today — populating it requires the curator
  pipeline, an already-trusted boundary — but it's a new trust-boundary
  crossing worth an allowlist at ingest time. Genuinely out of scope for a
  share-button story: it touches `lib/pool/sources.rb`, a different
  subsystem, for a curated-data hardening concern this diff didn't create.
  Worth its own TODO, not a blocker here.
- **Skipped — bridge message arriving after the destination is torn down**
  (rapid tap-share-then-back-navigate). UIKit's `present(_:animated:)` is
  documented to no-op gracefully on a view controller no longer in the window
  hierarchy — the standard, industry-wide accepted mitigation, not something
  apps typically add extra guards for. Added to the device QA script (step 7)
  instead of a code change: "tap share, immediately navigate back."

Re-verified after all `/simplify` + `/code-review` fixes: iOS build succeeds
(`xcodebuild` against the real SPM checkout), `bin/rubocop` 152/0,
`bin/rails test` 670/3074/0 failures, `bin/rails test:system` 72/0 failures.

## GSTACK REVIEW REPORT

| Review | Trigger | Why | Runs | Status | Findings |
|--------|---------|-----|------|--------|----------|
| CEO Review | `/plan-ceo-review` | Scope & strategy | 0 | — | — |
| Codex Review | `/codex review` | Independent 2nd opinion | 1 | ABSORBED | 8 findings: 3 confirmed eng E1–E3, 4 new (C1 image gate, C3 reveal timing, C4 provider semantics, C5 expiry), 1 moot — all folded |
| Eng Review | `/plan-eng-review` | Architecture & tests (required) | 1 | CLEAN | 7 issues, 0 critical gaps: E1 walled link target → always `/`, E2 stale public-cache claims, E3 double-tap guard, + C1/C3/C4/C5 |
| Design Review | `/plan-design-review` | UI/UX gaps | 1 | CLEAN | score: 6/10 → 9/10, 7 decisions (D1 rail order, D2 immediate sheet, D3 reveal — since amended by C3, D4 platform glyph) |
| DX Review | `/plan-devex-review` | Developer experience gaps | 0 | — | — |

- **CODEX:** outside voice (read-only, web-search-backed) independently rediscovered the walled-days and double-tap findings and added four corrections, all verified against code before folding.
- **CROSS-MODEL:** agreement on E1/E3 (strong signal both are real); C3 refined design D3 rather than contradicting it — no open tension.
- **VERDICT:** DESIGN + ENG CLEARED — ready to implement.

NO UNRESOLVED DECISIONS
