# 0016 — The listing
Date: 2026-08-16
Lane: Full (core, target ≤ 2 days)
Status: Draft

## Who

**Maya** — Daily Ritual Learner, persona 1, the core persona (`specs/personas.md`). 33,
pediatric nurse in Columbus, three 12-hour shifts a week. She does not know this product
exists and there is exactly one way she ever will: she types **"daily art"** into the App
Store on her phone, reads four or five results' worth of name, subtitle and first
screenshot, and taps one. She will not read a description. She will not scroll to reviews
of an app with no reviews.

Secondary: **the curator (Dhanesh)**, whose `BET.md` names one distribution channel and
five thresholds, all of which run through a listing that does not exist, with the kill
review **fifteen days out**.

Not in this story: Jordan, Amara, Zoe, Priya. The listing is not a feature any reader asks
for. It is the only door any of them can arrive through.

## Problem

**The bet has one channel and the channel has no storefront.**

`BET.md` names **ASO / App Store search** as the single distribution channel, chosen
because the category research says distribution decides here and the product is
commoditized. Every threshold in that file is downstream of a listing:

| Threshold | Needs a listing? |
|---|---|
| App live on App Store (was: Aug 14) | it **is** the listing |
| 3 keywords ranked top 100 | ranks the listing's name / subtitle / keyword field |
| 50 installs | installs the listing |
| 4 build-in-public posts | posts about a shipped, openable thing |
| 5 user conversations | about an app somebody can open |

The app now runs on a physical phone against production (SHIPLOG, 2026-08-16). The web
product has been live at `https://dailytondo.com` since Aug 14. **The scoreboard is still
0 / 0 / 0 / 0 / 0**, and `SHIPLOG.md` has been carrying the same sentence since Aug 13:
the App Store Connect listing, the channel this whole bet rides on, still has no spec.
This story is that spec.

### Two hard blockers already in the repo

Neither is a matter of polish. Each one stops submission outright:

1. **There is no privacy policy page.** `config/routes.rb` has no route for one and
   `public/` has no file. App Store Connect requires a privacy policy URL as a mandatory
   field on every app, and the requirement is sharper here than usual: story 0015 ships
   Sign in with Apple and Google, so the app creates accounts and stores `users.email` and
   `users.name`. Account deletion is already handled (`delete "account"`,
   guideline 5.1.1(v)); the policy that has to describe it is missing.
2. **There is no support URL.** Also a mandatory App Store Connect field, and it cannot be
   a `mailto:` — Apple wants a page.

### What the shelf actually looks like

`user-research/0004-app-landscape-catalog.md` swept 366 apps and read 94 in-category. The
findings that bear on this story, not to be re-derived:

- **23 in-category apps launched in 2026 alone**, most bidding on "art history", "learn art
  history", "daily art". The shelf is deeper than it was when `BET.md` was written.
- **The competition is weak where it counts.** Median rating count across the whole
  category is **9**; across the 2025–26 cohort it is **1**. Twenty apps have zero. Rating
  count, not app count, is the ranking barrier, and it is low everywhere except DailyArt
  (37,169).
- **Free-with-no-ads is unoccupied by anyone with traction.** Every incumbent runs ads or
  paywalls the archive. The leader's ads are its most-complained-about surface.
- **Curation beyond the Euro-canon is the most common complaint against everyone else**,
  and Tondo's pool is 53% outside Europe and North America by a quota table that fails the
  build if it regresses (story 0013). This is a checkable claim, not a slogan.
- **Hand-written editorial is named by the leader's own positive reviewers** — "no AI
  here!" — while the 2026 wave is being publicly accused of the opposite ("screams AI coded
  stuff", on Curator's own launch thread).

Three of those four are things the listing can *say* and most competitors cannot say
truthfully. The listing is where the two moats in `CLAUDE.md` — editorial voice, habit
mechanics — either reach a stranger or do not.

### What is already decided and does not reopen

`decisions/0007-the-name-is-tondo.md` fixed the two highest-weighted search fields:

- App Store name: **`Tondo: Daily Art`** (16 of 30 characters)
- Subtitle: **`One painting a day, explained`** (29 of 30)

The 100-character keyword field, the category, the description, the screenshots and the
privacy labels are open. The name and subtitle are not.

## Story

As **Maya**, I want to find a calm, free, one-painting-a-day app by typing "daily art" into
App Store search and to be able to tell from the result what it is, so that I install it
instead of scrolling past it.

As **the curator**, I want a complete, submittable App Store Connect record backed by a
privacy policy and support page that exist at real URLs, so that the one channel this bet
names can start indexing before Aug 31 decides it.

## Intake

- **Problem:** the bet's only distribution channel has no storefront, and two mandatory
  submission fields point at pages this repo does not serve.
- **Evidence:** `BET.md` — one channel, five thresholds, all downstream of a listing; the
  Aug 14 live-by date is already **missed**, not at risk. `user-research/0004` — 94 apps
  read, median 9 ratings, free-and-calm and non-Euro curation both unoccupied.
  `SHIPLOG.md`, Aug 13 — "the App Store Connect listing … still has no spec", unchanged
  since. `decisions/0007` — name and subtitle already spent on search intent.
- **Success signal (prediction), falsifiable and time-bound:** the build is **submitted to
  App Review by Aug 18, 2026** and **accepted without a metadata rejection** — no
  rejection citing 5.1.1 (privacy policy / account deletion), 2.1 (incomplete
  information), or 4.8 (Sign in with Apple). Falsified by any metadata rejection, or by
  submission slipping past Aug 18. The downstream keyword prediction stays where it
  belongs, in `BET.md`: **3 keywords in the top 100 by Aug 31**.
- **In baseline?** **No.** The Proven baseline is the product; this is the channel. The
  evidence that argues for the exception is `BET.md` itself, which names ASO as the sole
  distribution channel and gates all five thresholds behind a listing. Under
  `CLAUDE.md`'s "Do NOT build" rule this is exactly the out-of-baseline case that carries
  evidence, and the evidence is the bet document.

## Out of scope

- **Daily push (baseline item 2).** Unbuilt — no `aps-environment` entitlement, no APNs
  code anywhere. It is the habit driver and one of two named moats, and shipping without
  it is a real cost. It is still a separate story: it cannot change what the listing says,
  and adding it here delays the only thing on the bet's critical path. Named in the plan as
  a known gap, not silently omitted.
- **Session gate 6 operational work** — backups, logged restore test, error tracking,
  analytics. Blocking for *external users*, and publishing is what makes users external, so
  this story does not close the gate; it must be closed before the listing goes live. The
  one gate-6 item that **is** in scope is **accurate App Store privacy labels**, because
  they are part of the record being filed.
- Premium unlock, StoreKit, IAP. Parked by `CLAUDE.md`.
- iPad screenshots or an iPad build. `TARGETED_DEVICE_FAMILY = 1`.
- Localization beyond en-US.
- The "New" differentiator. Still deferred to the Phase 3 gate by `BET.md`.
