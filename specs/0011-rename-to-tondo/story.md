# 0011 — The app is called Tondo

Date: 2026-08-10
Lane: Express (same-day, reversible — see the note on reversibility below)
Status: Spec written 2026-08-10 — not started

*Number: 0010 is reserved for daily push (`SHIPLOG.md`, 2026-08-07). This story
does not displace it. It jumps ahead of it because the window for doing it
cheaply closes first — see Timing.*

## Who

**The curator (Dhanesh).** One bet, one channel, five thresholds at zero, an
App Store submission target four days out.

Behind him, **Maya** — Daily Ritual Learner, persona 1 (`specs/personas.md`).
She will never read this story. She types "daily art" into App Store search on
her phone, and whether she ever sees this product depends entirely on what is in
two 30-character fields.

This is not a story any reader asked for. It is a story about the words those
readers search for.

## Problem

The product is named for the curator and the App Store indexes for the reader.

`BET.md` names exactly one distribution channel — **ASO / App Store search** —
and the App Store's name field is its highest-weighted signal. "Tastemaker"
spends all thirty of those characters on a term nobody types with art intent. It
is also a crowded generic mark across media, food and fashion, and it describes
the person choosing rather than the thing chosen.

`decisions/0007-the-name-is-tondo.md` settles the name and the reasoning. This
story is not choosing a name. It is executing a settled one, everywhere, in one
commit.

The scale, measured rather than guessed — `grep -ril tastemaker` over the repo
on 2026-08-10:

| Area | Files | Notes |
|---|---|---|
| iOS project | 8 | includes a hand-written `.pbxproj` with 22 references and a scheme with 9 |
| Rails views | 10 | mastheads, `<title>`s, meta descriptions, the PWA manifest |
| Config & scripts | 6 | `deploy.yml`, `application.rb`'s module, `script/ios-build`, the iOS workflow |
| Tests | 4 | two brand assertions, one bundled-path constant, one comment |
| Docs & specs | 12 | most of which stay as they are — see Out of scope |

## Timing — why this is not "later"

Two changes in this story are free today and expensive after the next two
external events, neither of which has happened yet:

1. **`PRODUCT_BUNDLE_IDENTIFIER`** becomes `com.dhaneshnm.tondo`. A bundle
   identifier **cannot be changed once a build has been uploaded** against it in
   App Store Connect. Nothing has been uploaded. The App Store Connect record
   does not exist yet.
2. **The Kamal service, image and storage volume** are renamed. Renaming the
   volume after a deploy orphans the SQLite file — the curator's queue and every
   reader's collection. Nothing is deployed; `config/deploy.yml` still carries
   five `CHANGEME` values.

That is the whole argument for the queue position. After either event this stops
being a rename and becomes a migration.

## Story

As the curator, I want every surface of this product to say Tondo and carry the
rose mark, so that the one distribution channel the bet depends on is pointed at
words a reader actually types — and so that the bundle identifier and the
storage volume are right *before* the two events that freeze them.

## Intake

- **Problem:** the product's name is unsearchable in the only channel `BET.md`
  bets on, and two identifiers that are cheap to change today become permanent
  at the next deploy and the next upload.
- **Evidence:**
  - `BET.md` — one channel (ASO), five thresholds, all zero. Three ranked
    keywords required by Aug 31 with ~2.5 weeks of indexing available.
  - `decisions/0007` — the name analysis, and the collision research that
    disqualified Loupe (Loupe LLC's art-streaming app: same category, same
    features) and Gesso (Gesso app: museum audio guides, 50+ institutions).
    Tondo's App Store namesakes are a community social feed, a food-packaging
    service and a music developer — zero art-category overlap.
  - `DESIGN.md` Brand section — the mark and wordmark, locked 2026-08-10.
  - Apple: bundle identifiers are immutable after first upload.
  - `config/deploy.yml:68` — the volume line, which the file itself calls "the
    one line in the file that loses data if it is wrong."
- **Success-signal prediction (falsifiable, time-bound):** by **2026-08-12**,
  `grep -ri tastemaker` over the repo returns hits **only** in `SHIPLOG.md`,
  `decisions/0001`–`0006`, and the specs for already-shipped stories; `bin/ci`
  is green; `script/ios-build` is green; and the app installs on an iPhone 17
  simulator showing the rose icon on the home screen, the rose launch screen,
  and a masthead reading Tondo. Falsified if the Xcode project fails to open
  after the directory rename, if any icon size needs the mark re-drawn rather
  than re-rendered, or if the `module TasteMaker` rename breaks boot.
- **In baseline?** No, and it does not claim to be. It is a precondition for
  baseline item 5's surface — the App Store listing — and for the ASO channel
  `BET.md` names. The exception it carries is `decisions/0007`.
- **Lane:** Express. One commit, same day, and reversible by `git revert` right
  up until the first upload or the first deploy. **After either, it is not
  reversible at all** — which is the story, not a footnote.

## Scope

**In:**
1. Every reader-facing string: mastheads, `<title>`s, meta descriptions, the PWA
   manifest, the HTTP basic realm on the curator's desk.
2. The rose mark rendered to every size iOS and the web need, from one committed
   SVG source, by a script — not by hand (R1).
3. The iOS project renamed: directory, `.xcodeproj`, scheme, `PRODUCT_NAME`,
   `PRODUCT_BUNDLE_IDENTIFIER`, `INFOPLIST_FILE`, the `TASTEMAKER_URL` build
   setting and the `TastemakerURL` Info.plist key it feeds.
4. `config/deploy.yml`: service, image, proxy host, **storage volume**.
5. `module TasteMaker` in `config/application.rb`.
6. A new launch wordmark: mark over caps wordmark, per `DESIGN.md`.
7. `public/icon.png` and `public/icon.svg`, which are still Rails defaults.
8. Minitest that fails if "Tastemaker" reappears under `app/` or `config/` (R1).

**Out — named, so it stays out:**
- **Rewriting history.** `SHIPLOG.md`, `decisions/0001`–`0006`, and the specs
  for shipped stories keep the old name. They are a record of what was built and
  when; editing them to say Tondo would falsify it. `decisions/0007` is the
  pointer that explains the discontinuity.
- **The App Store listing itself.** Name, subtitle, keyword field, description,
  screenshots and privacy labels are their own story and their own work. This
  story only makes the strings inside the repo agree with them.
- **The domain purchase and DNS.** External, blocking the deploy rather than
  this story. `dailytondo.com` was unregistered as of 2026-08-10.
- **A design system change.** The tokens do not move. The mark is built entirely
  from `--bg`, `--gold` and `--ink`.
- **Any new brand surface** — social avatars, a press kit, an About page. None
  of them is on any list and none of them is asked for.

## Blocked on, and not by code

1. **The USPTO search has not been run.** Class 9 (software) and Class 41
   (education — the tutor). Ten minutes at `trademarkcenter.uspto.gov`. It runs
   **before** this commit lands, not after; a live mark in either class kills
   `decisions/0007` and the shortlist reopens. This is the one genuine gate.
2. **The domain.** Not blocking this story, blocking the deploy behind it.

## The adversarial note (R7)

This story ships nothing to a human. No install, no post, no conversation, no
ranked keyword. Renaming a repo is an input metric of the purest kind: it will
feel like a productive day and every threshold in `BET.md` will still be zero
when it is done — not live, 0 of 4 posts, 0 of 3 keywords, **0 of 5 user
conversations**, 0 of 50 installs.

It earns its place on exactly one argument: it is cheaper today than at any
later date, and two of its changes become impossible after events that are days
away. That argument does not extend one inch further. The moment the rename is
green, the next thing is the VPS and the blurbs — not another brand surface.
