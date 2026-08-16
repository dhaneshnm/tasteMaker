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
