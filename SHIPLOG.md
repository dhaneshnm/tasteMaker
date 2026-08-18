# SHIPLOG

Every ship and publish gets a line with a receipt (link, commit, screenshot). A week with
shipped code and zero initiated user contact is builder's gravity — it gets named here.

| Date | What shipped / published | Receipt |
|------|--------------------------|---------|
| 2026-07-24 | Infinite-scroll MVP committed (pre-BET; input metric only — see R7) | fdf28c5 |
| 2026-08-03 | BET.md completed; personas.md built from 31 DailyArt reviews | 286c068, 1dffea4 |
| 2026-08-03 | Story 0001 "Artwork of the Day" built — baseline item 1. Code only, **not published, not deployed, zero users, zero installs**: an input metric under R7. | 4221f55 |
| 2026-08-04 | Story 0007 "no session cookie on public pages" built — a live defect on already-shipped pages, split out of 0006 at eng review. Code only. | 6747990 |
| 2026-08-04 | Story 0006 "favorites" built — **baseline item 4**, the last purely-web baseline item. Design review 6/10 → 9/10 (9 decisions), eng review 8 findings, QA 2 findings / 1 fixed. Code only, **not published, not deployed, zero users, zero installs**: an input metric under R7. | 9b22661, d2e9f7c, ae229ef |
| 2026-08-05 | Story 0004 "the page that isn't there" built — the 404 renders on linen and keeps its status code. Code only. | eeb9946 |
| 2026-08-05 | Kamal + Thruster deploy config written and rehearsed against a real production container. **Still not deployed** — needs a VPS. | 244254f |
| 2026-08-07 | Story 0009 "the typefaces come from us" built — Fraunces and Newsreader self-hosted, two third-party hosts off the critical path. Code only. | 5a6929c |
| 2026-08-07 | Story 0008 "the shell that gets it onto a phone" built — **baseline item 2's precondition**, a Hotwire Native iOS target that builds and runs on an iPhone 17 simulator against `localhost:3000`. Code only, **not on a device, not on TestFlight, not submitted, zero installs**: an input metric under R7. | 39e68c7, 6861b81 |

| 2026-08-10 | Bug fix, not a story: shipping story 0009's CSS moved the asset digest but not the ETag, so any browser holding the previous HTML revalidated into a 304 and kept linking a stylesheet URL that no longer resolved — the page rendered unstyled and did not heal on reload. Found by hitting it locally, not by a test. Code only. | ae742dc |
| 2026-08-13 | Stories 0011 "rename to Tondo" and 0012 "getting around", in one commit — the tree never had a 0011-only state, so splitting them would have mislabelled one story's work as the other's. 0011: the product is Tondo, a rose-window mark, one masthead partial where six copies used to be. 0012: a compass on every screen and a sticky rail on `/feed`, which was a dead end — its only exit was a wordmark that had scrolled off the top. Design review 6/10 → 9/10 (4 decisions), eng review 12 findings, Codex outside voice 9 findings (4 novel, all confirmed). Code only, **not published, not deployed, zero users, zero installs**: an input metric under R7. | bea621c |

| 2026-08-13 | Story 0013 "a deeper pool" built — the pool goes from **110 works in one museum to 2,000 across four** (Met, Art Institute of Chicago, Cleveland, Minneapolis). Selection is a quota table in code, not a hand-pick: per-artist ceiling 5, no museum over 50%, no region over 25%, 53% outside Europe and North America, 18% dated 1900+, 83% carrying readable museum text, every plate \u2265 1600px. `db/seeds/pool_report.md` is the receipt; `test/lib/pool_quota_test.rb` fails the build if a reseed regresses any bar. 0.94 GB on disk against CX22's 40 GB. Code only, **not published, not deployed, zero users, zero installs**: an input metric under R7. | c770303 |
| 2026-08-13 | Fix, reported from the running app: the front door read "This work is resting" where the artwork should have been. `Primary_RenditionNumber` carries a suffix (`mia_3003333_001.jpg`) and the regex reading it dropped it, so 43 works downloaded blank and 57 more were wrongly vetoed as unreachable. One of the blank ones had already been published. Dead plates 77 → 20; Minneapolis mirror 1,547 → 1,670. 2,002 rows, 2,002 images. | 1e79c05 |
| 2026-08-14 | Story 0014 "the action rail" built — reader actions leave the bottom of the wall label and become a row of line icons under the plate, because `Keep this` (the habit mechanic, one of two named moats) was measured 40–60pt below the fold on the front door with nothing on screen saying so. Amends `DESIGN.md` rule 6 via `decisions/0010`. QA found ISSUE-001, the rail's zoom control sharing the plate's accessible name; fixed with a regression test. **Logged late** — this shipped in five commits and sat unlogged while the session moved on to hosting. | a4ea62b, 2dd8ca3, e3d977c, 9e298be, a34fd48 |
| 2026-08-14 | **Tondo is live: https://dailytondo.com** — the first receipt in this file that is a URL instead of a commit. One GCP e2-medium in us-central1, Ubuntu 24.04, `kamal setup` exit 0 in 1,171s, valid Let's Encrypt cert, HTTP 301 → HTTPS, `/up` 200. Domain bought and DNS cut over the same day; USPTO Class 9/41 search run and clear before the money was spent. **Nobody has opened it, there is no daily pick scheduled, and the front door reads "The first artwork arrives soon."** | https://dailytondo.com, d292302, b092833, 096c586 |

**The day the URL started existing, and what that is worth (R7), 2026-08-14.** For the
first time in this log the receipt column holds an address instead of a hash. That is the
precondition for every threshold in `BET.md` and it is **not progress against any of them**.
The scoreboard is unchanged: **0 of 4 posts, 0 of 3 keywords, 0 of 5 user conversations, 0 of
50 installs**, and "app live on the App Store by **Aug 14**" is now **missed rather than at
risk** — that was today.

Three hosts were named in two days before one existed. `decisions/0009` chose a Hetzner CX22
in Ashburn; it is not sold there — the CX line is Germany/Finland only — and the €4.49 it
quoted was already two months stale, Hetzner having raised USA CPX pricing ~3× on
2026-06-15. Both were checkable the day 0009 was written. `decisions/0012` supersedes it with
GCP and says plainly that the choice was made on **speed, not price**: the spread between the
cheapest and dearest option, across the entire remaining life of this bet, is **$7.76**. That
$7.76 consumed a decision entry, a price correction, a cost estimate and most of a session.

**Two defects that only production could find.** The first: `bin/docker-entrypoint` runs
`db:prepare`, which seeds on a fresh database, which downloads 2,000 images before the app
answers — against Kamal's default `deploy_timeout` of **30 seconds**. Caught by reading the
entrypoint before deploying rather than by watching a rollback; the failure would have looked
like a broken app instead of an impatient timeout.

The second is the more useful one. The seed stored **1,780 of 2,000** plates. Every one of
the 220 failures was the Art Institute — 220 AIC works in the pool, 220 failures, zero AIC
images. `lib/pool/sources.rb` had already paid for both lessons (no email address in the
User-Agent, and AIC's Cloudflare wants its own `AIC-User-Agent` header) and `db/seeds.rb`
carried a **duplicate copy of the string** that had learned neither. Fixed by deleting the
duplicate rather than syncing it. What makes it worth writing down: from a residential IP the
old headers work fine and from the datacenter they 403, so this bug was **invisible to every
local test and certain in production**. The first stated diagnosis was contradicted by the
first test and only held up when run on the box.

**Still owed before a single external reader**, unchanged and now overdue rather than
upcoming: no backups, no logged restore test, no error tracking, no analytics — session gate
6, against a SQLite file on one disk. A VM snapshot of a live SQLite file can capture a torn
WAL and is not a restorable backup. Choosing a third host in two days did not make that work
smaller.

| 2026-08-14 | Story 0015 "the two keys" built — every reader-facing endpoint now answers only a signed-in web session (Google/Apple OAuth, no passwords) or a registered device (Keychain UUID → signed cookie); everything else bounces to the landing page's sign-in anchor. The landing page stays public and byte-identical across all three identity states. Design review triage 5/10 → 8/10 (3 decisions), eng review 19 findings + Codex outside voice (19 points, 11 folded), 4-agent simplify (17 applied), 2-agent code review that caught a real ship-blocker: Apple's cross-site POST callback would have 422'd on CSRF in production while the suite stayed green. **The Apple flow is still unverified end-to-end — it cannot be exercised off a deployed domain, and there is no deployed domain.** Code only, **not published, not deployed, zero users, zero installs**: an input metric under R7. | 74c4516, 5db1dfb, b5301d1 |

| 2026-08-16 | **Story 0015's first door actually opens in production.** The sign-in buttons had been live on dailytondo.com for two days and neither one worked: the ship checklist's provider setup was never run, so both strategies booted with blank client ids and every tap died at Google's door. Google web client created, consent screen published (non-sensitive scopes, no verification review), credentials committed, deployed. Request phase verified against Google on the live domain — real `client_id`, `redirect_uri` accepted, sign-in page returned. Shipped alongside two bug fixes found the same day: museum HTML reaching the wall label as literal `<em>` (only 1 of 4 adapters flattened it; **424 rows rewritten in prod**), and a suite that typed `ENV`'s secret while the controllers read credentials — every admin and device test had been 401'ing since `a6dba37`, invisibly, because a clone with no master.key kept passing. **Apple is still dead**: its five values are absent from credentials, so that button fails exactly as before. Two doors, one open. | ed55a8e, 184164d, 17eae52, https://dailytondo.com |

| 2026-08-16 | **Both doors open. Story 0015 works against a real Apple ID on the live domain.** Apple's Services ID, team id, key id and `.p8` written and deployed — and the flow then failed exactly where `specs/0015-the-two-keys/plan.md` said it would, twelve days after the plan said it. Apple returns the callback as a cross-site POST; `_tondo_session` is `SameSite=Lax`; the browser sends nothing; `omniauth.state` is gone. The one thing the plan did not predict was the error string: not `csrf_detected` but **`undefined method 'bytesize' for nil`**, because omniauth-oauth2's `secure_compare` compares against the nil session value with no guard. Fixed with the scoped-cookie option the plan had already chosen — a signed `/auth` cookie, `SameSite=None; Secure`, carrying state **and** nonce, spent on first use, with `_tondo_session` left at `Lax`. No fork fallback, no time-box breach. **A green suite could not have caught this and did not**: `OmniAuth.config.test_mode` skips the request phase, so the middleware is tested as Rack and a mutation run proves the test reproduces the production nil. Still an input metric: **zero users have opened either door.** | 247b613, 7472be9, https://dailytondo.com |

| 2026-08-16 | **Tondo is on a phone.** Story 0008's shell, built Aug 7, had never left the simulator; it now runs on a physical iPhone 13 Pro (iOS 26.5.2) against `https://dailytondo.com`, signed `Apple Development (7UHVJKQDCU)`, installed by `devicectl`. Three blockers had to go first, none of which raised an error: no `DEVELOPMENT_TEAM` anywhere (a simulator build never asks, a device build cannot sign), `TONDO_APP_SECRET = CHANGEME` still in `Release.xcconfig`, and `UIRequiredDeviceCapabilities` declaring `armv7` — a 32-bit capability no iOS 17 device has. The secret one is the one worth keeping: verified against production, the real value answers **204** and `CHANGEME` answers **401**, and `DeviceIdentity.register` swallows the 401 and routes anyway — so shipping the placeholder would have reached App Review as "sign-in is broken", not as a misconfiguration. Secret now generated from credentials by `script/ios-secrets` into a gitignored `Config/Secrets.xcconfig`. **One device, mine, dev-signed. Not TestFlight, not submitted, zero App Store installs**: an input metric under R7. | f025187 |

| 2026-08-18 | **Story 0017 Release 2: sign-in reaches the app, and the collection stops belonging to the phone.** Google answers an embedded web view with `403 disallowed_useragent` by policy, so OAuth cannot happen in the shell's WKWebView. `ASWebAuthenticationSession` can — but it has its own cookie jar and Apple gives no way to share it, so what crosses is a 60-second single-use token: tap → `/auth/start/:provider` matched and cancelled by a new `AuthRouteDecisionHandler` → sheet → consent → callback in **Safari's** jar → `tondo://auth?handoff=…` → `/session/handoff` in the **web view's** jar, which spends the token, writes the session, and claims. **The claim happens on the last leg because that is the only request in the flow that can see both keys at once** — the callback has no device cookie. Two corrections the build made to the plan: `native=1` had to move to the QUERY STRING, because OmniAuth stashes `request.GET` as `omniauth.params` and a POST-body field is never seen again (found by running it — the callback was redirecting to `/days`); and the doors render as LINKS for a native reader, because a form submit is not a `VisitProposal` and would sail past the handler into the 403. `generates_token_for` plus a counter column replaced the planned `handoff_tokens` table — Rails signs and expires it, so there is nothing to store or sweep. **The version gate, measured on a simulator rather than assumed**: the eng review found `applicationUserAgentPrefix` carried no version, so the server could not tell one binary from another while Rails deploys in seconds and binaries do not. Version and bridge now ship together, so presence is the whole test — instrumented the wall, booted the shell, read `Tondo iOS/1.0 → bridge=true` against an old shell's `Tondo iOS; → bridge=false`, removed the probe. Verified on production after deploy: both `/auth/start` routes 200 and `facebook` 404s on the constraint, a forged handoff answers 303 to `/you` rather than an error, a versioned shell gets two door links and an unversioned one gets zero, and `/` still answers `public, no-cache` with **no `Set-Cookie`**. Migration ran on container boot via `db:prepare`. `bin/ci` 342 runs / 1760 assertions, 48 / 293 system. **Not verified, and it needs a human**: the OAuth round trip through a real sheet against real Google credentials — `simctl` has no pointer input, so everything up to the tap is proven and the tap is not. **Still zero on every BET threshold**: the binary has never been uploaded, so no reader can reach any of this from a phone, and nothing advances the daily pick. | e4dbc42, https://dailytondo.com/auth/start/google_oauth2 |
| 2026-08-18 | **Story 0017 "Your corner", Release 1: the account surface, and the fragment the front door stopped needing.** `/you` is the fifth reader surface and the second unwalled one, reached by an oculus in the masthead on all eight screens that wear it and by a word in the front door's coda. Sign-out and both delete doors moved there; `/collection` keeps a labelled signpost so the majority iOS reader — a registered device that never signed in — did not trade a button that says what it does for a mark that does not. **The landing page's per-visitor fragment is deleted, not relocated**: `sessions#control`, its route, the `signin` frame and the `/#signin` anchor. That removes a round trip from every front-door render and takes the product's most delicate cache hazard off the one page Thruster stores. `/you` has **four** states, not three — the unregistered shell holds nothing, claims nothing, and is offered no delete button, because `DevicesController` answers one with a silent redirect when `current_device` is nil. Sign-in doors stay suppressed for the shell entirely: Google answers an embedded web view with `403 disallowed_useragent`, so they arrive with the native transport in Release 2 or not at all. **Four review passes found six things the build did not.** The wall's retarget turned out to be a detector for tests that were silently measuring the bounce target — `dynamic_type_test` had been comparing the front door with itself on its second route since story 0015 walled the archive (36 → 78 assertions), and `design_test` had the identical bug against `/feed`. Two eager frame GETs were being written over with "Content missing": the keep frame, which only ever worked because the old bounce landed on a page carrying the same frame, and `/feed`'s pagination sentinel, which the first fix missed and whose comment asserted the case was unreachable. `/simplify` found a real defect — `locked:` was derived from the view's render enum rather than the wall's predicate, so the unregistered shell rendered four live compass links that all bounced back to `/you` (measured 4 links / 0 locked; now 0 / 3). Three pre-existing defects fixed in passing: `.legal`'s two links, the nav App Review requires, were shipping at ~15px against a 44px rule; `.page--empty` lost its top padding to a compass sibling rule on every empty screen; and `privacy_claims_test` never tested a route despite the plan claiming it caught the 0016 defect. `bin/ci` 321 runs / 1682 assertions integration, 48 / 293 system, 0 failures. **Still an input metric, and the two things that are not both remain untouched**: the binary has never been uploaded — the `BET.md` live-by date was Aug 14 — and nothing advances the daily pick, so the front door holds the last published day over forever with no job and no spec. Zero of five user conversations. **Deployed to dailytondo.com** in 55.1s, no migration, and verified against production rather than the exit code: `/you` 200 where it was 404, `/session/control` 404 where it was 200, the three walled paths 303 to `/you`, and `/privacy` and `/support` still 200 for the anonymous fetches App Review makes. The two properties most able to fail silently both hold live — `/` answers `public, no-cache` with an ETag and **no `Set-Cookie`** (the story 0007 contract, which a per-visitor mark in the masthead would have broken), and `/you` under the shell's user agent with no device cookie renders **zero sign-in doors** and three locked compass words. | 9c26906, 6d0a46b, b616cf4, f71c152, 7cb3f75, 6baf3e0, 9e4fe05, https://dailytondo.com/you |
| 2026-08-16 | **Story 0016 "the listing", part one: the two pages Apple opens are live, and the exit door most readers never had is built.** `https://dailytondo.com/privacy` and `/support` answer **200 anonymously, to Safari 14, and to AppleBot** — the three fetches that decide whether App Store Connect accepts the record. `PagesController` inherits `ActionController::Base` rather than `ApplicationController`, because the planned `skip_before_action :allow_browser` **raises at class definition** (Rails installs it as an anonymous lambda) and the `raise: false` workaround is a **silent no-op**. Measured before writing the fix: Safari 14 → 406, curl → 200, empty UA → 200, AppleBot → 200, so the victim was never Apple's crawler but a reader on old hardware. `DELETE /device` is the other half: `accounts_controller.rb:7` returns early unless `current_user`, so **the default state of every iOS reader — registered device, never signed in — could not delete anything** while the policy promised in-app deletion. Also today's pick, scheduled by natural key (`cma`/`163797`) after production turned out to assign id **860** where this machine says 2691 — the front door had been reading `FRI, AUG 14` for two days. `bin/ci` 308 runs / 1614 assertions / 0 failures, 47 system tests. **Three store frames captured at 1320×2868 from the Release build against production.** Not submitted: no upload, no review, **zero App Store installs** — an input metric under R7. | dd90512, https://dailytondo.com/privacy |

**What the reviews caught that the build would not have, 2026-08-16.** Worth recording
because the ratio is unusual. `/plan-design-review` scored the plan 4/10 and the reason had
nothing to do with layout: the app's own admin queue reports **1 of 1 published day running
museum text (100%)** against `decisions/0004`'s under-20% bet, the archive held one row and
the collection was empty — so **three of the five planned screenshots could not be shot
honestly**, and the listing's strongest claim would have been contradicted by its own
screenshots. The decision was to shoot what exists and write the copy to match, which means
**the hand-written editorial claim is not in the App Store description**. That is the moat
`CLAUDE.md` names first, absent from the storefront because it is unwritten rather than
because it was declined.

The outside voice (Codex) then found four things a first-party review had already missed,
all verified before folding: guideline **5.1.1(i) requires the privacy link inside the app**,
not only in metadata — which reversed a "not in scope" call made an hour earlier and would
have been a rejection; **device-only readers had no deletion path at all**; the plan named a
**local database id** for the store hero where production assigns its own (confirmed wrong at
scheduling time, 2691 vs 860); and `public_cache_headers_test.rb` still asserted the front
door was the only public page. Two independent reviewers found the `allow_browser` defect
separately.

**What is still owed, and one of them got worse today.** `support@dailytondo.com` **does not
receive mail**, and it is now printed on two live pages telling readers they can request
deletion there — that moved from "blocks the filing" to "the published policy overstates a
channel". And **nothing advances the day**: `app/jobs/` holds only `application_job.rb`,
Solid Queue is not in the Gemfile, and `DailyPick.current` holds the last published day over
indefinitely. Today's pick was scheduled by hand; tomorrow the front door goes stale again,
under a description that says "one painting a day". Both reviewers named this as outranking
push. It still has no spec.

**Builder's gravity, named a fifth time (R7 / session gate 5), 2026-08-13.** Two more
stories built today and **still zero initiated user conversations** — the count `BET.md`
needs five of, and has none of, with eighteen days to the kill review. The App Store
submission target was ~Aug 11 and the live-by date is **tomorrow, Aug 14**. There is still
no VPS, nothing is deployed, and the App Store Connect listing — the ASO channel this whole
bet rides on — still has no spec.

What today actually produced: navigation polish on an app nobody outside this repo has
opened. It is worth noting that the day's most valuable find was not the feature — it was
that `ApplicationSystemTestCase` claimed a 375px viewport and had been running at 500px
since it was written, so every fold measurement in this product had been looser than the
phone it named. That is a real defect fixed. It is also still an input metric.

Every threshold in `BET.md` is unchanged and zero: not live, 0 of 4 posts, 0 of 3 keywords,
0 of 5 user conversations, 0 of 50 installs.

**Log gap, named rather than backfilled:** stories 0002 (feed zoom, `1ddc20b`), 0003 (past
days, `62bd3db`) and 0005 (museum note fallback, `22aec4c`) shipped without a line here. The
log was not current when this session started.

**Builder's gravity, named a third time (R7 / session gate 5), 2026-08-07.** Apple Developer
enrollment is done, which unblocks App Store Connect, TestFlight and an APNs key — and the
shell now exists to put into them. **None of that has happened.** There is still no VPS
(`config/deploy.yml` carries five `CHANGEME` values), so nothing is deployed and the Release
build points at a placeholder host. Baseline item 2 — daily push, the habit driver and the
only reason the shell was urgent — has no spec, no number, and no code; it is story 0010 and
it is not started.

Every threshold in `BET.md` is still zero: not live, 0 of 4 posts, 0 of 3 keywords, **0 of 5
user conversations**, 0 of 50 installs. The App Store deadline is Aug 14 and the submission
target was ~Aug 11, which is four days out. Nobody outside this repo has opened this app.

Two things that are not on any list and gate the bet directly: the App Store Connect listing
— name, subtitle, keyword field, screenshots, privacy labels — has no spec at all, and it
*is* the ASO channel `BET.md` bets everything on. And session gate 6 is unmet: no error
tracking, no analytics, no backup or logged restore test for a SQLite file living on a
single volume.

**Builder's gravity, named again (R7 / session gate 5), 2026-08-05.** The Proven baseline is
now 4/5 and the deploy config is rehearsed, and **every one of BET.md's five thresholds is
still zero**: not live on the App Store, 0 of 4 posts published, 0 of 3 keywords ranked, 0 of
5 user conversations, 0 of 50 installs. Nine days to the Aug 14 deadline, six to the ~Aug 11
submission. Nothing below this line is progress until something is deployed and somebody
outside this repo has opened it.

**Builder's gravity, named (R7 / session gate 5):** three stories built today and **zero
initiated user conversations** all week. BET.md needs 5 two-way exchanges by Aug 31 and has
0. Baseline items 1, 3 and 4 are done; item 2 (push) still needs an iOS shell that does not
exist, the App Store deadline is Aug 14, and nothing is deployed. Every line above is an
input metric. None of them is progress.

**What story 0013 actually cost, and what it did not buy (R7), 2026-08-13.** The pool was
never what was stopping this bet: 110 works is 3.6 months of dailies and the kill review is
in **eighteen days**. This moved none of BET.md's five numbers. The scoreboard is unchanged
at 0 live / 0 posts / 0 keywords / 0 conversations / 0 installs, the App Store live-by date
is **tomorrow**, and `config/deploy.yml` still carries two `CHANGEME` values.

What it did produce, beyond the count: five defects that only existed because something
checked. The quota table failed its own first run five works short and wrote nothing. The
first report that passed every bar was 46% South Asian — the range floor met by draining
one collection, which answers persona 3 with a different monoculture. 156 works counted as
"range" turned out to be Dutch and Flemish. 983 Minneapolis image URLs were well-formed and
every one of them 403'd. And pointing the existing fold-budget test at the new pool's worst
case put the day's first written line 193px below the fold on a 297-character title.

None of that is progress either. It is the difference between shipping 2,000 paintings and
shipping 2,000 rows.
