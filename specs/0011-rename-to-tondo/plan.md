# 0011 — Implementation plan

Status: Built 2026-08-10 — bin/ci green, script/ios-build green, simulator smoke passed. NOT committed.

## Approach

One commit, seven passes, in an order chosen so that the thing most likely to
break — the hand-written `.pbxproj` — is verified by a build before anything
else is touched on top of it.

The mark is **not** hand-drawn into PNGs. SVG sources are committed and a script
renders every raster from them, because twelve PNGs made by hand are twelve PNGs
that silently drift the first time the mark is adjusted (R1). The geometry is
fixed in `DESIGN.md`'s Brand section; the SVGs are that table, transcribed.

Nothing in the design system moves. The mark uses `--bg` and `--gold` and adds
no token, no component and no exception.

## What the design review changed

The mark was rendered to real PNGs before this plan was reviewed, which
falsified three things the plan and `DESIGN.md` had both asserted. All five
decisions are recorded in `DESIGN.md`; the short version:

| Was | Is | Why |
|---|---|---|
| Linen tile, gold rose | **Gilt tile, linen rose** | The linen tile has no edge on light or photographic wallpapers — the square vanishes and the rose floats |
| Full drawing 1024–120, small at 80 and below | **Measured per size against real PNGs** | Twelve lights were clean at 87 and 80; eight lights read as a *gear* at 40. Both thresholds were guesses |
| Render each size natively in Chrome | **Render 1024, downsample with `sips`** | Native small renders came out blocky; downsampling is smoother and is what Apple does anyway |
| Icon appearances not mentioned | **Tinted drawn, dark inherits light** | Desaturating gold yields a flat mid-grey with no window left in it |
| Launch screen becomes mark + wordmark | **Wordmark alone, as today** | A gilt field makes the mark a filled gold square, which is the loudest thing on the calmest surface |

## Steps

### 0. The gate — before any of the below

Run the USPTO search: `trademarkcenter.uspto.gov`, "Tondo", Class 9 (software)
and Class 41 (education). A live mark in either class stops this story and
reopens `decisions/0007`. Record the result in that file either way — a search
that was run and came back clean is worth as much as one that did not.

### 1. Brand sources

All `viewBox="0 0 1024 1024"`, geometry exactly per `DESIGN.md`.

- `brand/rose.svg` — gilt field, tracery band r=396/w12, 12 lights, oculus r=96.
- `brand/rose-small.svg` — gilt field, 8 lights, oculus r=122, no band.
- `brand/rose-tinted.svg` — the same window in grayscale on a **transparent**
  ground, so iOS composites its own tint behind it.
- `brand/rose-mono.svg` — ink field, for print. Not rendered by default; it
  exists so the one-colour version in `DESIGN.md` is not a paragraph describing
  a file nobody made.
- `brand/launch.svg` — **caps wordmark only**, Fraunces 480 uppercase tracked
  0.24em, gold on linen. No mark. `@font-face` points at
  `app/assets/fonts/fraunces-roman-latin.woff2` by relative path so the render
  needs no network.

Starting geometry is already drawn and proofed — see Approved artefacts below.

### 2. `script/brand-render`

Headless Chrome, already installed at
`/Applications/Google Chrome.app/Contents/MacOS/Google Chrome`, verified working
during the design review:

```
--headless --disable-gpu --hide-scrollbars --force-device-scale-factor=1
--default-background-color=00000000 --virtual-time-budget=1500
--window-size=1024,1024 --screenshot=OUT file://SRC
```

**One render per SVG, at 1024. Every smaller size comes from `sips -Z N` off
that master.** Do not invoke Chrome per size — that was the original plan and
the review showed it produces harder aliasing at exactly the sizes that matter.

Outputs, all overwritten in place:

| From | Sizes | To |
|---|---|---|
| `rose.svg` / `rose-small.svg` | per the size table settled in step 3 | `ios/Tondo/Assets.xcassets/AppIcon.appiconset/` |
| `rose-tinted.svg` | same set | same, tinted appearance |
| `rose-small.svg` | 512 | `public/icon.png` — PWA `purpose: any` |
| `rose-small.svg` | 512 on a 640 canvas | `public/icon-maskable.png` — PWA `purpose: maskable` |
| `rose-small.svg` | 180 | `public/apple-touch-icon.png` |
| `rose-small.svg` | — | `public/icon.svg` (copied, not rendered) |
| `launch.svg` | 300×40 / 600×80 / 900×120 | `LaunchWordmark.imageset/wordmark{,@2x,@3x}.png` |

**Maskable canvas, spelled out** because "a padded image" is not a spec: the
mark rendered at 512 centred on a 640×640 transparent canvas puts the outermost
ink at r=251 of 320, which is 78% — inside the 80% safe circle a maskable icon
is cropped to. Same numbers as the iOS reasoning in `DESIGN.md`.

**Launch canvas, spelled out** for the same reason: the existing wordmark is
295×26 at 1x, one line of type. The replacement keeps that shape at 300×40 — no
mark, so no square. `UILaunchScreen` needs no plist change, and
`LaunchWordmark.imageset/Contents.json` keeps its existing 1x/2x/3x entries.

Fail loudly if Chrome is missing, and check each output is non-empty; a
zero-byte screenshot is how a silently broken render ships. Also write
`brand/manifest.json` recording each source SVG's SHA256 — see Tests.

**Named dependency:** this script only runs on macOS. It needs Chrome and
`sips`. Linux CI cannot reproduce these assets, which is why enforcement is a
structural test rather than a re-render (see Tests).

### 3. Settle the size table, then write it back

Render **both** drawings at 1024, 180, 120, 87, 80, 60, 58, 40, 29 and 16, build
a magnified contact sheet, and pick the drawing per size by eye. Then write the
resulting table into `DESIGN.md` as fact, replacing the "measured, not asserted"
paragraph.

Expect from the review's own renders: full wins down to ~60, small wins from ~58
to 40, and **neither survives 29 or 16** — budget for a third drawing (a plain
gold roundel with the oculus, no lights) for the favicon floor and Settings size.

### 4. iOS assets

- Rewrite `AppIcon.appiconset/Contents.json` in multi-size form, with tinted
  appearance entries alongside the default set. No dark entries — dark inherits
  the default art deliberately (`DESIGN.md`).
- **Verify the `appearances` key shape against Apple's asset-catalogue
  documentation before writing it.** The expected form is
  `"appearances": [{"appearance": "luminosity", "value": "tinted"}]`, but that
  is asserted here, not confirmed. A wrong schema is the bad case: Xcode may
  ignore the entry silently and ship an icon with no tinted variant rather than
  failing the build. Confirm, then write.
- Run `script/brand-render`; delete the old `wordmark*.png` and `icon-1024.png`.

### 5. iOS rename — then build before going further

- `git mv ios/Tastemaker ios/Tondo`
- `git mv ios/Tastemaker.xcodeproj ios/Tondo.xcodeproj`
- `git mv ios/Tondo.xcodeproj/xcshareddata/xcschemes/Tastemaker.xcscheme Tondo.xcscheme`
- `project.pbxproj` — 22 references. `xcscheme` — 9.
- `ios/Config/Shared.xcconfig`: `PRODUCT_NAME = Tondo`,
  `PRODUCT_BUNDLE_IDENTIFIER = com.dhaneshnm.tondo`,
  `INFOPLIST_FILE = Tondo/Info.plist`, and the header comment.
- `ios/Config/Debug.xcconfig` / `Release.xcconfig`: `TASTEMAKER_URL` → `TONDO_URL`.
- `ios/Tondo/Info.plist`: `CFBundleDisplayName` → `Tondo`, key `TastemakerURL` →
  `TondoURL`, and its `$(TONDO_URL)` value.
- `ios/Tondo/Endpoint.swift`: the `forInfoDictionaryKey` lookup and both
  comments — this file traps loudly on a missing key, so a half-done rename here
  is a crash on launch rather than a silent fallback. Good.
- `ios/Tondo/AppDelegate.swift`: `applicationUserAgentPrefix = "Tondo iOS;"`.
  **Not cosmetic** — `hotwire_native_app?` matches on the UA, so getting it
  wrong un-suppresses the chrome `decisions/0006` removed.
- `script/ios-build`: `PROJECT` and `SCHEME`.
- `.github/workflows/ios.yml`: the `-project` path.
- `test/integration/path_configuration_test.rb:17`: the `BUNDLED` constant.
- `test/system/dynamic_type_test.rb:6`: the path in the comment.

**Then run `script/ios-build` before touching anything else.** The `.pbxproj` is
hand-written; "does Xcode still accept this file" has exactly one honest answer
and it is a build.

### 6. Rails

- **Extract `app/views/shared/_masthead.html.erb`.** Six views carry
  near-identical markup and the brand string appears ~15 times across the repo;
  `DESIGN.md` already calls `.masthead` "one bar for every screen" and the code
  disagrees. Every one of those lines is being edited by this story anyway, so
  the extraction is close to free now and a second full pass later.

  Two variances the partial must carry, not flatten:

  ```
  brand   ├── <a href=root_path>   daily/_day:29, days/index:5,
          │                        favorites/index:5, errors/not_found:7,
          │                        paintings/index:2
          └── <span>               daily/empty:4   ← no link; there is no
                                                     archive to go back to
  aside   ├── present              days ("N days"), favorites ("N works"),
          │                        paintings ("N works · Mia")
          └── absent               daily/_day (carries its own date logic),
                                   daily/empty, errors/not_found
  ```

  `daily/_day`'s masthead also holds the conditional date link, so it passes a
  block rather than a string.

- `<title>` and description strings (7 files), including the fallback in
  `layouts/_head.html.erb:14` and `application-name` at line 27.
- `layouts/_head.html.erb`: point `apple-touch-icon` at the new
  `/apple-touch-icon.png` (180) rather than the 512 `/icon.png`.
- `pwa/manifest.json.erb`: `name`, `short_name`, and **split the icon entries**.
  It currently declares the same file for `purpose: any` and `purpose: maskable`;
  one of the two is always wrong. `/icon.png` for `any`, `/icon-maskable.png`
  for `maskable`.
- **`application_controller.rb`: add a per-deploy revision to the `etag` block.**
  The ETag inputs on `/` and `/days` are model rows, the importmap digest and
  the stylesheet digest — none of which move when template text changes. This
  story changes only template text, so without this a revalidating client gets
  a 304 carrying the old brand, forever. Commit `ae742dc` was this same hole
  with CSS four days ago.

  ```
  ETag inputs before                    ETag inputs after
  ├── @pick, @pick.painting             ├── @pick, @pick.painting
  ├── @published_count                  ├── @published_count
  ├── importmap digest                  ├── importmap digest
  └── stylesheet digest                 ├── stylesheet digest
      └── template text: NOT COVERED    └── deploy revision  ← covers all text
  ```

  Source the revision from something that changes per deploy and is readable in
  every environment. `KAMAL_VERSION` is the obvious candidate but is **not
  verified** to be injected into the container — check it, and fall back to a
  build-time `REVISION` file written by the Dockerfile if it is absent. Blank in
  development must be harmless, not a crash.
- `admin/base_controller.rb:20`: the HTTP basic realm. Cosmetic, but it is the
  string the curator sees in the browser's auth dialog.
- `app/assets/stylesheets/application.css:2`: the header comment.
- `config/application.rb:21`: `module TasteMaker` → `module Tondo`. Only
  occurrence in the tree; `config/environment.rb` and `config.ru` go through
  `Rails.application`, so nothing else references it.
- `db/seeds.rb`: the comment.

### 7. Deploy config — the expensive lines

`config/deploy.yml`: `service`, `image`, `proxy.host`, and the volume
`tastemaker_storage` → `tondo_storage`. The file's own comment calls the volume
"the one line in the file that loses data if it is wrong." Safe to change **only**
because nothing has ever been deployed. Confirm that is still true before editing.

`proxy.host` stays a placeholder — the domain is a separate blocker.

### 8. Docs

Rewrite: `CLAUDE.md`, `BET.md`, `README.md`, `DESIGN.md` (title line),
`specs/personas.md`.

**Do not rewrite:** `SHIPLOG.md`, `decisions/0001`–`0006`, and the specs for
shipped stories (`0001`, `0003`, `0004`, `0006`, `0008`, `0009`). They record
what was built and when. `decisions/0007` is the pointer that explains why the
name changes partway down the log. Add one line to `SHIPLOG.md` at ship time,
not a find-and-replace through it.

## Tests

Written during implementation, not after (R1).

- **`test/integration/brand_test.rb`** — new. Asserts the masthead reads Tondo
  on **all six** views (daily, archive index, collection, 404, feed, empty
  state); that the `<title>` fallback and `application-name` say Tondo; that
  `pwa/manifest.json` returns `name` and `short_name` of Tondo **and that its
  `any` and `maskable` icon entries point at different files**.
- **CRITICAL REGRESSION TEST — the empty state's brand is not a link.**
  `daily/empty.html.erb:4` is `<span class="masthead__brand">`; the other five
  are `<a href>`. A partial that flattens that difference turns the empty state
  into a link to the page it is already on. Nothing in the suite covers it
  today. Assert `assert_select "span.masthead__brand"` on the empty state and
  `assert_select "a.masthead__brand"` on the other five. Mandatory — this is an
  existing behaviour the extraction can silently break.
- **The guard, in the same file** — walks `app/` and `config/` and fails on the
  string "Tastemaker", case-insensitively. **Text files only**, so it cannot
  trip on `credentials.yml.enc` or any other binary. The forcing function for
  `decisions/0007`: without it the rename is a one-time sweep that the next
  copy-paste quietly undoes.
- **`test/integration/template_etag_test.rb`** — new, mirroring
  `stylesheet_etag_test.rb` (which is the same bug one file over). Asserts that
  a changed deploy revision stops `/` and `/days` returning 304, that an
  unchanged one still 304s, and that a client sending `Accept: */*` is covered
  — that third case is in the stylesheet test because the first fix missed it.
- **`test/integration/brand_assets_test.rb`** — new. Parses
  `AppIcon.appiconset/Contents.json`, asserts every referenced filename exists
  and that each PNG's real pixel dimensions match its declared size × scale;
  asserts `public/icon.png`, `icon-maskable.png`, `apple-touch-icon.png` and
  `icon.svg` exist at their specified sizes; and asserts each SHA in
  `brand/manifest.json` still matches the current `brand/*.svg`, which is what
  catches a PNG built from a drawing that has since moved.
- **`test/integration/daily_test.rb:45`** and
  **`test/integration/admin/daily_picks_test.rb:157`** — existing brand
  assertions, updated.
- **`test/integration/path_configuration_test.rb:17`** — the bundled-path
  constant. This test already compares shipped JSON against served JSON, so it
  catches the directory rename for free.
- **`script/ios-build`** — the forcing function for the `.pbxproj`. Green before
  the commit; CI runs it on any `ios/**` change. **Named limit:** it runs with
  `CODE_SIGNING_ALLOWED=NO` (`script/ios-build:57`), so it proves the project
  compiles and nothing about signing, provisioning, the App ID, or upload.

## Verification before commit

1. `bin/ci` green.
2. `script/ios-build` green.
3. **Contact sheet review** — the magnified per-size sheet from step 3, with the
   chosen drawing at each size and the tinted variant beside it.
4. Simulator smoke, checking the things no test can see: the rose on the home
   screen at real size, the launch screen, and the masthead balance with a
   five-character brand.

   **The app launching at all is the real check on the iOS rename** —
   `Endpoint.swift` traps loudly on a missing Info-dictionary key, so a
   half-applied `TastemakerURL` → `TondoURL` rename is a crash on launch, not a
   silent fallback. Then read the user agent in the Rails development log to
   confirm the prefix.

   **Do not** verify the UA rename by checking that native chrome is
   suppressed. `LinenNavigationController.swift:36-37` overrides
   `setNavigationBarHidden` to always pass `true`, so that check passes
   unconditionally. `hotwire_native_app?` appears nowhere in `app/`, `config/`,
   `test/` or `lib/` — the UA prefix has no Rails-side consumer and is cosmetic.

5. `git grep -i tastemaker` returns hits only in `SHIPLOG.md`,
   `decisions/0001`–`0006`, the shipped specs, **and this story's own
   `story.md` and `plan.md`**, which quote the old name throughout and are part
   of the record. `git grep`, not `grep -ri` — the latter walks `.git`, `tmp/`,
   `log/` and binaries and makes the gate unreadable.

## Risks

| Risk | Mitigation |
|---|---|
| The hand-written `.pbxproj` does not survive the rename | Build immediately after step 5, before any Rails work. One commit, so `git revert` is clean |
| Neither drawing survives 29 and 16 | Expected. Step 3 budgets a third plain-roundel drawing rather than discovering it late |
| ~~The UA prefix rename is missed and native chrome reappears~~ | **Retired — the claim was false.** `hotwire_native_app?` exists nowhere in the repo; chrome suppression is unconditional in `LinenNavigationController.swift:36-37`. The prefix is cosmetic |
| `com.dhaneshnm.tondo` is unavailable or unprovisioned | **Accepted, unmitigated.** `script/ios-build` disables signing, so nothing here can catch it; it surfaces at upload. Registering the App ID early was offered and declined — collisions on a reverse-domain you control are rare, and the week has no room for portal work |
| The tinted `appearances` schema is wrong | Xcode may ignore it silently rather than fail. Step 4 verifies the key shape against Apple's docs before writing it |
| The masthead partial flattens the empty state's `<span>` into an `<a>` | Mandatory regression test, listed under Tests. No existing test covers it |
| Bundle identifier changed after an upload | Cannot happen — no upload exists. This is the entire reason the story is queued here |
| Volume renamed after a deploy, orphaning SQLite | Cannot happen — nothing deployed. Re-confirm at step 7 rather than assuming |
| ~~Chrome headless renders the SVG unfaithfully~~ | **Retired.** Verified during design review; renders are faithful, and the pipeline now downsamples from one 1024 master |

## NOT in scope

Design decisions considered and explicitly deferred, one line each.

- **A dark-appearance icon drawing.** Gold is dark enough to sit among dark
  neighbours; revisit only if `--gold` lightens.
- **The mark anywhere inside the app.** Artwork is the subject; a logo would be
  a second one.
- **A third wordmark setting.** Three exist and cover masthead, launch and lockup.
- **Motion on any brand surface.** `DESIGN.md` rule 7 allows a fade and nothing else.
- **App Store screenshots and listing copy.** Its own story; this one only makes
  the strings inside the repo agree with it.
- **Social avatars, press kit, About page.** Nobody asked; subtraction default.
- **Re-testing the masthead's full type scale.** Only the brand string changes
  length; a screenshot check is proportionate, a type-scale review is not.

## What already exists — reuse, do not reinvent

- `DESIGN.md` token table, nine rules, one written exception. Every mark here is
  built from `--bg` and `--gold` and adds nothing.
- `.masthead`, `.page`, `.plate`, `.label`, `.coda` — untouched. This story
  changes one string inside `.masthead__brand`.
- `UILaunchScreen` in `Info.plist` — already a colour plus one centred image
  with `UIImageRespectsSafeAreaInsets`. Structure is right; only the image changes.
- `specs/0009-self-hosted-fonts` — Fraunces already ships from this app's own
  pipeline, so the wordmark render needs no network.
- `test/system/design_test.rb` — already fails if screens drift on paper colour,
  type, or the never-crop rule.
- `script/ios-build` — the existing `.pbxproj` forcing function; the rename needs
  no new CI.

## Approved artefacts

| Screen / asset | Path | Direction | Notes |
|---|---|---|---|
| App icon, full | `~/.gstack/projects/tasteMaker/designs/tondo-icon-20260810/inv.svg` | Gilt field, 12 lights, tracery band | Starting geometry for `brand/rose.svg` |
| App icon, small | `~/.gstack/projects/tasteMaker/designs/tondo-icon-20260810/inv-sm.svg` | Gilt field, 8 lights, no band | Starting geometry for `brand/rose-small.svg` |
| Size proof | `~/.gstack/projects/tasteMaker/designs/tondo-icon-20260810/sheet.png` | Both drawings, every size, magnified | The evidence that killed the 120px crossover claim |
| Appearance proof | `~/.gstack/projects/tasteMaker/designs/tondo-icon-20260810/sheet2.png` | True size, tinted, dark, shelf | The evidence for drawing a tinted variant |
| Field comparison | `~/.gstack/projects/tasteMaker/designs/tondo-icon-20260810/sheet3.png` | Linen vs gilt on three wallpapers | The evidence for inverting the field |

## Implementation Tasks

Synthesized from this review's findings. Each derives from a specific finding.

- [ ] **T1 (P1, human: ~1h / CC: ~10min)** — brand sources — invert the field to gilt in both drawings
  - Surfaced by: Pass 1 — linen tile has no edge on light or photographic wallpapers (`sheet3.png`)
  - Files: `brand/rose.svg`, `brand/rose-small.svg`, `DESIGN.md`
  - Verify: render at 60 on dark, light and pale-photo grounds; tile boundary visible on all three
- [ ] **T2 (P1, human: ~30min / CC: ~5min)** — render script — downsample from one 1024 master
  - Surfaced by: Pass 6 — native small renders are blocky; `sips`-downsampled are smooth (`sheet.png`, row 4)
  - Files: `script/brand-render`
  - Verify: 40 and 16 outputs show soft edges, not hard gold/linen blocks
- [ ] **T3 (P1, human: ~1.5h / CC: ~15min)** — icon set — measure the size table, expect a third drawing at ≤29
  - Surfaced by: Pass 5 — DESIGN.md's 120px crossover is false; 8 lights read as a gear at 40
  - Files: `brand/`, `AppIcon.appiconset/Contents.json`, `DESIGN.md`
  - Verify: magnified contact sheet, one chosen drawing per size, table written back to DESIGN.md
- [ ] **T4 (P1, human: ~1.5h / CC: ~15min)** — icon set — draw the tinted appearance
  - Surfaced by: Pass 2 — icon appearances absent from the plan; desaturated gold is a flat grey
  - Files: `brand/rose-tinted.svg`, `AppIcon.appiconset/Contents.json`
  - Verify: tinted entries present; window still legible when the system applies a tint
- [ ] **T5 (P2, human: ~20min / CC: ~5min)** — manifest — split `any` and `maskable` icon entries
  - Surfaced by: Pass 6 — same file declared for both purposes
  - Files: `app/views/pwa/manifest.json.erb`, `script/brand-render`
  - Verify: `test/integration/brand_test.rb` asserts the two entries differ
- [ ] **T6 (P2, human: ~10min / CC: ~2min)** — head — point `apple-touch-icon` at a 180
  - Surfaced by: Pass 6 — currently a 512
  - Files: `app/views/layouts/_head.html.erb`, `script/brand-render`
  - Verify: file exists at 180×180 and the tag resolves
- [ ] **T7 (P2, human: ~20min / CC: ~5min)** — launch screen — wordmark only, no mark
  - Surfaced by: Pass 3 — a first-frame change riding inside a rename story
  - Files: `brand/launch.svg`, `LaunchWordmark.imageset/`, `DESIGN.md`
  - Verify: simulator cold launch shows linen and one line of type
- [ ] **T8 (P2, human: ~15min / CC: ~5min)** — masthead — screenshot after the brand string halves
  - Surfaced by: Pass 1 — ten characters to five, on every screen, unexamined
  - Files: `app/views/**` mastheads
  - Verify: daily page and archive index at 375×667; brand/fact balance still reads
- [ ] **T9 (P3, human: ~10min / CC: ~2min)** — DESIGN.md — record the 5.3:1 contrast measurement
  - Surfaced by: Pass 6 — passing, but asserted rather than measured
  - Files: `DESIGN.md`
  - Verify: line present; ratio matches the token table's gold-on-linen figure

_No new tasks from Pass 4 — AI slop risk rated 9/10._

### From the engineering review

- [ ] **T10 (P1, human: ~1h / CC: ~15min)** — application_controller — add a per-deploy revision to the ETag
  - Surfaced by: Architecture — ETag inputs are model rows + importmap + stylesheet digests; template text is uncovered. Same hole as `ae742dc`
  - Files: `app/controllers/application_controller.rb`, `Dockerfile` (if a REVISION file is needed)
  - Verify: `test/integration/template_etag_test.rb`, mirroring `stylesheet_etag_test.rb`
- [ ] **T11 (P1, human: ~2h / CC: ~20min)** — views — extract `shared/_masthead`, keep the span/link variance
  - Surfaced by: Code quality — six near-identical mastheads, brand string in ~15 places, against DESIGN.md's "one bar for every screen"
  - Files: `app/views/shared/_masthead.html.erb` + the six views
  - Verify: **CRITICAL regression test** — `span.masthead__brand` on the empty state, `a.masthead__brand` on the other five
- [ ] **T12 (P1, human: ~1.5h / CC: ~15min)** — tests — structural asset test plus `brand/manifest.json` SHAs
  - Surfaced by: Architecture — `config/ci.rb` never runs `script/brand-render`, so committed PNGs can drift silently (R1)
  - Files: `test/integration/brand_assets_test.rb`, `script/brand-render`, `brand/manifest.json`
  - Verify: `bin/rails test`; deliberately edit an SVG without re-rendering and watch it fail
- [ ] **T13 (P2, human: ~30min / CC: ~5min)** — plan/verification — fix the grep gate
  - Surfaced by: Outside voice — the whitelist omits this story's own files, so the gate can never pass; `grep -ri` also walks `.git` and binaries
  - Files: this plan, `test/integration/brand_test.rb`
  - Verify: `git grep -i tastemaker` returns only whitelisted paths
- [ ] **T14 (P2, human: ~30min / CC: ~10min)** — render script — specify the maskable and launch outputs
  - Surfaced by: Outside voice — "a separately rendered padded image" has no filename, size or path; the launch asset has no canvas
  - Files: `script/brand-render`, `app/views/pwa/manifest.json.erb`
  - Verify: `brand_assets_test.rb` asserts both files exist at their specified dimensions
- [ ] **T15 (P2, human: ~20min / CC: ~5min)** — icon set — verify the `appearances` schema before writing it
  - Surfaced by: Outside voice — the tinted key shape is asserted, not confirmed; a wrong schema fails silently
  - Files: `ios/Tondo/Assets.xcassets/AppIcon.appiconset/Contents.json`
  - Verify: Apple asset-catalogue docs, then `script/ios-build` green
- [ ] **T16 (P3, human: ~10min / CC: ~2min)** — decisions/0007 — widen the trademark trigger
  - Surfaced by: Outside voice — USPTO classes 9 and 41 do not cover App Store name availability
  - Files: `decisions/0007-the-name-is-tondo.md`
  - Verify: the trigger names both checks

## Deviations (added during build, 2026-08-10)

Eight. Six are things the plan got wrong; two are discoveries.

1. **Step order swapped: the iOS rename ran before the render.** The plan had
   the render script writing into `ios/Tondo/…` two steps before that directory
   existed. Renaming first and building immediately still satisfies the "build
   before going further" gate the ordering was there to protect.

2. **The tinted appearance does not go on per-size entries.** Writing
   `appearances` next to the eight `idiom: iphone` slots built **green** and
   emitted `warning: The app icon set "AppIcon" has 9 unassigned children` —
   Xcode parsed the entries, could not place them, and dropped them. The icon
   would have shipped with no tinted rendition and nothing would have failed.
   The appearance lives on the universal single-size 1024 slot, which coexists
   with the per-size defaults. This is the exact failure step 4 was told to
   check for, and it only surfaced because the build was run and read.

3. **The crossover is 80, not 120.** Rendering both drawings at every size and
   looking at them magnified: twelve lights and the tracery band are clean at 87
   and 80. `FULL_SIZES` is now `1024 180 120 87 80`; `SMALL_SIZES` is `60 58 40`.
   Written into `DESIGN.md` as a table.

4. **The masthead partial takes `aside_html`, not a block.** `render layout:` +
   `yield` looked right and failed silently: `yield` inside a partial is
   `_layout_for`, which returns the surrounding buffer when the partial was
   rendered without `layout:`, so a plain `render "shared/masthead"` produced no
   aside and raised nothing. Two explicit locals instead.

5. **The ETag revision comes from a `REVISION` file, not `KAMAL_VERSION`.** The
   plan flagged the Kamal variable as unverified and it stayed unverified, so
   the Dockerfile writes a build timestamp instead. No dependency on an env var
   that might silently be blank — which for an ETag input is the bug wearing a
   fix.

6. **The renderer sizes by attribute, not by viewport units.** `width:100vw` put
   the launch wordmark ~70px down its canvas with the type clipped off the
   bottom. Caught by opening the PNG, not by any check.

7. **Discovery: the PWA manifest has never been reachable.** `config/routes.rb`
   has no PWA route and no layout carries `<link rel="manifest">`, so
   `app/views/pwa/manifest.json.erb` is Rails 8 scaffolding nothing serves. The
   `any` / `maskable` split is correct and currently inert; `brand_test.rb`
   asserts against the file on disk and says so. **Not fixed — out of scope for
   a rename.** Wiring it up is a decision, not a typo.

8. **Discovery: `db/seeds.rb` carried a camelCase `tasteMaker`** in the outbound
   User-Agent for museum image fetches, matching neither substitution. Found by
   the grep gate, which is the gate working.

## Worktree parallelization

Sequential implementation, no parallelization opportunity. Every lane converges
on the asset catalogue or the view layer, and step 5 gates on a build that must
run before the Rails work starts.

## GSTACK REVIEW REPORT

| Review | Trigger | Why | Runs | Status | Findings |
|--------|---------|-----|------|--------|----------|
| CEO Review | `/plan-ceo-review` | Scope & strategy | 0 | — | — |
| Codex Review | `/codex review` | Independent 2nd opinion | 0 | — | — |
| Eng Review | `/plan-eng-review` | Architecture & tests (required) | 1 | CLEAR | 6 issues, 1 critical gap closed |
| Design Review | `/plan-design-review` | UI/UX gaps | 1 | CLEAR | score: 6/10 → 9/10, 5 decisions |
| DX Review | `/plan-devex-review` | Developer experience gaps | 0 | — | — |

- **CODEX:** ran as outside voice (gpt-5.5, high effort). 16 problems raised; 2 dropped as already-decided scope, 1 confirmed a first-party finding, 6 folded in, 1 accepted unmitigated by the user.
- **CROSS-MODEL:** independent agreement on one item — the UA-prefix claim is false, and `hotwire_native_app?` exists nowhere in the repo. Codex found one thing the first-party review missed entirely: `script/ios-build` disables signing, so a green build proves nothing about the bundle identifier the story's urgency rests on.
- **VERDICT:** DESIGN + ENG CLEARED — 16 tasks queued, 1 mandatory regression test, 0 unresolved. Ready to implement.

NO UNRESOLVED DECISIONS
