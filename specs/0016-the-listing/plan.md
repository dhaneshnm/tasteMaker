# 0016 — Implementation plan
Status: Draft

## Approach

Three things, in an order that is not negotiable because each one is an input to the next:

1. **Two public pages shipped to `dailytondo.com`** — `/privacy` and `/support`. These are
   code, tested, deployed. They exist because App Store Connect has two mandatory URL
   fields and this repo serves neither.
2. **The App Store Connect record filled in** — the metadata that points at those URLs,
   plus category, keywords, description, age rating, privacy labels, screenshots.
3. **A build uploaded** against `com.dhaneshnm.tondo`, App ID already registered
   (`7UHVJKQDCU.com.dhaneshnm.tondo`, Xcode-managed, created 2026-08-16).

Reversed, this fails: the privacy URL is validated when the record is saved, and a URL that
404s or bounces to a sign-in page is a metadata rejection.

No new models. No new gems. Two routes, one controller, two views, plus copy that lives in
this file until it is pasted into App Store Connect — App Store metadata has no home in the
repo and inventing one is infrastructure for later.

### The two constraints that decide the controller

Both come from `app/controllers/application_controller.rb` and both would have been found by
App Review rather than by us:

1. **`before_action :require_reader`** — story 0015's wall bounces every reader-facing
   endpoint to `/#signin` with a 303. Apple fetches the privacy policy URL **without an
   account**, and a legal page behind a login is rejected under 5.1.1. The new controller
   skips the wall, and a test asserts it, because the skip is one deletion away from
   silently re-walling a page nobody looks at again.
2. **`allow_browser versions: :modern`** — a 406 to any user agent Rails can identify as
   old. Unknown agents pass today, so a crawler probably survives; "probably" is not the bar
   for the field that gates submission, and `public/406-unsupported-browser.html` is what a
   reviewer would see instead of a policy. Skipped on this controller too.

These pages are public, static, and identical for everyone, so they also skip `no_store`
and keep ordinary caching.

### Category and age rating — decided from our own catalog, not from taste

`user-research/data/0004-app-landscape.json`, 94 in-category apps, queried 2026-08-16:

| Question | Evidence | Decision |
|---|---|---|
| Primary category | **Education 57**, Lifestyle 14, Games 12, Reference 2. Every competitor with traction is Education-primary: DailyArt, Artly, Artlist, ArtHist, ArtDay, ArtBite, Curator. | **Education** |
| Secondary category | DailyArt and Paintly use Entertainment; Artlist and ArtDay use Reference; Artly and Curator use Lifestyle. | **Reference** — Tondo is an archive with a daily door, not entertainment |
| Age rating | **12+ is the category norm**: DailyArt (37,169 ratings), Artly (2,363), Artlist (644), ArtHist (111), ArtDay (58), ArtBite (9), Curator (9) — all 12+. The 4+ apps are the ones with 4 and 10 ratings. | **Answer the questionnaire honestly and expect 12+** |

The age rating is not a preference. **The pool has no nudity filtering of any kind** —
`lib/pool/` and `db/seeds.rb` have no content screen, and 2,002 works drawn from the Met,
AIC, Cleveland and Minneapolis unquestionably include classical nudes. The questionnaire
asks about "Infrequent/Mild — Sexual Content or Nudity" and the honest answer is yes.
Answering 4+ to keep a wider audience would be a false filing on a checkable fact, and the
whole category has already priced 12+ in. **Not building a nudity filter for this story**:
it would gate the pool the quota table in story 0013 was built to keep broad, and 12+ costs
nothing the evidence says matters.

### The keyword field

Apple indexes name + subtitle + keywords as one bag and builds phrases across them, so a
term already in the first two fields is a wasted character in the third.

Spent already (`decisions/0007`): `Tondo: Daily Art` (16/30) and
`One painting a day, explained` (29/30) — which puts **tondo, daily, art, one, painting,
day, explained** in the index for free. "art history" and "daily art" therefore both rank
off a single new word.

Draft, verified at exactly 100 of 100 characters, no spaces (a space costs a character and
buys nothing):

```
history,museum,masterpiece,gallery,artist,curated,artwork,culture,learn,classical,canvas,renaissance
```

Rationale per term is one of: (a) completes a phrase with a field we already own —
`history` → "art history", the category's most-bid term; (b) is how a reader describes the
thing without knowing the word — `museum`, `gallery`, `masterpiece`, `canvas`; (c) names
the range the pool actually has — `classical`, `renaissance`, `culture`.

**Not included, deliberately:** `free` and `no ads`. Free-with-no-ads is our strongest
uncontested position (`0004` §7.4) and it belongs in the subtitle-adjacent copy a reader
*reads*, not the keyword field — nobody searches "free art app" with intent, and Apple's
guidelines treat price terms in keywords as spam.

## Steps

1. **`decisions/0013-the-listing-is-education-12-plus.md`** — category, secondary category
   and age rating are direction-level calls with a falsifiable prediction attached (R4).
   Prediction: the three ranked keywords at kill review come from `history`, `museum` and
   the name/subtitle phrase "daily art"; if the ranked terms are instead `tondo` or
   `renaissance`, the phrase-building model above is wrong.
2. **`PagesController`** — `privacy` and `support`, both skipping `require_reader` and
   `allow_browser`. Routes `get "privacy"` and `get "support"`. Static views, existing
   linen layout, masthead and compass per `DESIGN.md`.
3. **Write the privacy policy** against the actual schema, not a template. What the app
   stores, verified in `db/schema.rb`:
   - `users`: `email`, `name`, `provider`, `uid` — **only** when a reader signs in with
     Google or Apple. Apple's Hide My Email means `email` may be a relay address; say so.
   - `devices`: `token_digest` (SHA of a UUID minted in the Keychain on first launch),
     `last_seen_at`. Not an advertising identifier, not the IDFV, not tied to a person.
   - `favorites`: a painting id keyed to either a user or a device digest.
   - Server logs hold IP addresses (Rails + Thruster). Disclose it.
   - **Not collected:** no ads, no third-party analytics (none is wired — see gate 6
     below), no cross-app or cross-site tracking, no IDFA, no location, no contacts, no
     health data, no purchases. This section is short today and must be edited the day
     analytics lands, or the filing becomes false.
   - Deletion: in-app, `delete /account` (already built, guideline 5.1.1(v)), plus the
     support address.
   - Not directed at children.
4. **Write the support page** — what the app is, how to reach a human, link to privacy.
   **Open question, one line, yours:** the contact address. `dhanesh.n.m19@gmail.com` works
   today and costs nothing; `support@dailytondo.com` reads like a product but needs mail
   routing that does not exist. Recommendation: **ship the Gmail**, revisit if volume ever
   justifies the forwarding. Standing up mail infrastructure for an app with zero installs
   is the named failure pattern.
5. **Deploy** — `kamal deploy`. Both URLs must answer 200 to an anonymous `curl` before
   anything is typed into App Store Connect. Verify with no cookie jar.
6. **Screenshots** — 6.9" (1320 × 2868, iPhone 17 Pro Max simulator) is the only size Apple
   still requires; the rest are scaled. Five frames, in reading order: the front door with
   the plate and wall label; the same day scrolled to the editorial note; the zoom; the
   archive; the collection. Captured from the **Release** configuration against production,
   so what a reader sees in the store is what the build does. **This step wants
   `/plan-design-review`** — the screenshots are the highest-leverage visual artifact this
   product has, seen by more people than the app itself, and they are the one place a
   reader decides.
7. **Description and promotional text** — drafted in this file, reviewed, then pasted. The
   first three lines are all Maya reads; they carry hand-written editorial, free with no
   ads, and curation beyond the Euro-canon, because `0004` §7 says those three are the ones
   competitors cannot truthfully claim.
8. **Privacy labels** — filed to match the policy written in step 3, field by field.
   Contact Info (email, name) and Identifiers (device token) linked to the user; no
   tracking; no data used for advertising. This is the session gate 6 item that is in
   scope, and it is the one gate-6 item that is part of the filing rather than part of the
   operations.
9. **Archive and upload** — `xcodebuild archive` + `-exportArchive` with an App Store
   Connect API key, `CURRENT_PROJECT_VERSION` bumped per upload. Upload does not submit.
10. **Stop.** Submission waits on the gate-6 work that is not in this story.

## Tests

Minitest, written with the code (R1), not after:

- `PagesControllerTest` — `/privacy` and `/support` answer **200 with no session and no
  device cookie**. This is the enforcement for the whole story: a legal page behind story
  0015's wall is a 5.1.1 rejection, and the failure mode is silent.
- Same test asserts a **non-modern / empty user agent** still gets 200, not the 406 page.
- A content assertion per page that the required elements are present — the deletion route
  and the contact address on privacy, the contact address on support — so an edit that
  guts the policy fails the build rather than the review.
- Route test that both paths are reachable by name, and a `brand_test`-style assertion that
  neither page says "Tastemaker".

`bin/ci` green before QA, per build flow.

## Known gaps, named rather than omitted

- **Daily push does not exist.** No `aps-environment` entitlement, no APNs code in `app/`,
  `lib/` or `ios/`. Baseline item 2 and one of two named moats. Submitting without it means
  the listing describes a daily habit the app cannot start on its own. Its own story; the
  App ID will need the Push Notifications capability added then.
- **Session gate 6 is open** — no backups, no logged restore test, no error tracking, no
  analytics, against a SQLite file on one GCP disk. This story files accurate privacy
  labels and closes nothing else. **The gate blocks Submit for Review, not this plan.**

## Deviations (added during build)
