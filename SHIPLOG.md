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
