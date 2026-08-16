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
   account**, and a legal page behind a login is rejected under 5.1.1.
2. **`allow_browser versions: :modern`** — a 406 to any user agent Rails can identify as
   old, and `public/406-unsupported-browser.html` is what the reader would see instead of a
   policy.

**Neither is skipped. The controller inherits outside the chain instead** — see step 2,
which carries the measurement and the reason. The short version: `allow_browser` installs
an anonymous lambda, `skip_before_action :allow_browser` raises, and the `raise: false`
workaround is a silent no-op. Two `skip_before_action` calls were the original plan and one
of them could not have worked.

These pages are public, static, and identical for everyone, so they keep ordinary caching
and must be added to `public_cache_headers_test.rb`, which currently asserts the front door
is the only public page in the app.

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
2. **`PagesController < ActionController::Base`** — `privacy` and `support`, inheriting
   **outside** `ApplicationController`, with `layout "application"` re-declared. Routes
   `get "privacy"` and `get "support"`.

   **Not `skip_before_action`, and this is the plan's one real correctness fix** (eng
   review, Issue 1). `allow_browser` does not install a named callback. Rails 8.1's
   `actionpack/lib/action_controller/metal/allow_browser.rb` does:

   ```ruby
   before_action -> { allow_browser(versions: versions, block: block) }, **options
   ```

   An anonymous lambda cannot be skipped by name. Verified in this app:

   ```
   skip_before_action :allow_browser               → ArgumentError: callback :allow_browser has not been defined
   skip_before_action :allow_browser, raise: false → no error, silently a no-op
   ```

   The first form fails at class definition. The second — the fix a developer reaches for
   when the first raises — yields a controller that *looks* like it skips the browser gate
   and does not. Inheriting outside the chain removes both the wall and the browser gate
   structurally, so there is nothing to skip and nothing for a later edit to delete.

   The exposure is narrow but real. Measured against production:

   | User agent | Status |
   |---|---|
   | Safari 14 | **406** |
   | `curl/8.4.0` | 200 |
   | empty | 200 |
   | `AppleBot/1.0` | 200 |

   Rails only blocks browsers it can *identify* as old, so Apple's crawler is fine — but a
   reader on old hardware (persona 2, explicitly) tapping the policy link gets the 406 page
   instead of a privacy policy. **And the originally planned test could not catch this**: it
   asserted an empty/non-modern UA returns 200, which it does either way.

   What is lost by inheriting outside the chain: the parent's `etag` blocks. That is
   correct here — those exist for pages that key their ETag on model rows via `fresh_when`
   (`/` and `/days`), which is what made `ae742dc` possible. A static page gets an accurate
   body-digest ETag automatically.

   **Render the compass with `here: nil`.** `ApplicationHelper#compass_destinations`
   *raises* `ArgumentError` on a key outside `COMPASS_KEYS` (`application_helper.rb:75`)
   and `nil` is the documented "not one of the four" case. Passing `:privacy` is a 500 on
   the one page App Review is guaranteed to open. These pages are not compass
   destinations; they are reachable from the App Store listing and from a link in the
   masthead-adjacent coda, not from the four-item nav.

   **The long-form document spec** (design review, pass 5). The privacy policy is the
   longest continuous prose this product has ever rendered — longer than any editorial
   note — and `DESIGN.md` has no component for it. Rather than invent one:
   - Column is `--measure` (42.5rem), same as every reading surface. Nothing wider.
   - Body is Newsreader at the existing body step, `--ink`. Never below 16px (universal
     rule), and the tokens are already AA+ at every size used.
   - Section headings are Fraunces at the existing title step, `--ink`, weight inside the
     380–560 range. No new step in the scale.
   - Sections are separated by the `✦` divider, which rule 6 already names as one of the
     two permitted ornaments. No cards, no rules, no boxes — the alternative would have
     been a new visual idiom needing its own line in `DESIGN.md`.
   - A **last-updated date** at the head of the policy, in the metadata style (`--ink-dim`,
     small caps like the wall label's `C. 1819 — OIL ON WOOD`). Legal pages need it, and
     the plan already says this policy must be edited the day analytics lands — with no
     date, that edit is invisible to anyone who read the old one.
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
   The contact address is **`support@dailytondo.com`** (decided 2026-08-16; the Gmail was
   the alternative). Mail routing for it does not exist yet and the curator sets it up
   before submission — recorded as a blocker below rather than as an assumption, because
   the failure is not cosmetic: **App Review asks its questions through this address**, and
   an unrouted one turns a question into an unanswered rejection with no visible cause.
   The same address goes in App Store Connect's App Information contact field, so it must
   receive mail before step 10, not before launch.
5. **Deploy** — `kamal deploy`. Both URLs must answer 200 to an anonymous `curl` before
   anything is typed into App Store Connect. Verify with no cookie jar.
6. **Schedule today's pick — `Royal Elephant Ramkali with a Mahout`**, identified by its
   **natural key `source: "cma", source_id: "163797"`**, Rajasthan, c. 1761, aspect 1.03.

   **Not by primary key.** The design review wrote "painting id 2691", which is this
   machine's id. `db/seeds.rb` upserts by `(source, source_id)` and production ran its own
   seed, so row ids are an artifact of insert order and are not portable between the local
   database and the box. Naming the local id in a plan step executed against production is
   how you schedule the wrong painting (eng review, outside voice). This is one action doing two jobs, and the second is
   the one that matters. It clears the stale front door — the live masthead currently
   prints `FRI, AUG 14` on Aug 16, because `DailyPick.current` holds the last published
   day over and there is no publish job to advance it. And it fixes the store hero, which
   the plan had been letting the calendar choose. Chosen on the only test a 150px
   search-results thumbnail applies: chroma and instant legibility. Red border, turquoise
   ground, yellow saddle, grey elephant; near-square, so it fills the 55vh plate box with
   almost no linen bleed. Rejected: the gold-ground Kano Sansetsu (id 26, figures too
   small at thumbnail) and Guan Daosheng's `Chrysanthemums` (id 48 — a literal tondo and
   the perfect brand rhyme, but brown on brown, which is the exact failure of the
   incumbent pick). Not a nude, which frame 1 must not be at 12+.

7. **Screenshots — four frames, 1320 × 2868** (6.9", iPhone 17 Pro Max simulator; the only
   size Apple still requires, the rest are scaled). Captured from the **Release**
   configuration against production, so the store shows what the build does.

   | # | Frame | Why it earns a slot |
   |---|---|---|
   | 1 | Front door, the elephant | The hero and the search thumbnail. Proves the non-Euro claim in the first image. |
   | 2 | Wall label scrolled | Shows the actual reading experience, museum text attributed as the museum's. |
   | 3 | Zoom, dark mount | `--mount-bg` full screen. Better bar 7, and visually unlike anything on this shelf. |
   | 4 | `/feed` gallery | 2,002 works at a glance — the range claim proved rather than asserted. |

   **Four, not five.** Apple's minimum is one and its maximum is ten. The two frames the
   plan originally listed fifth — the archive and the collection — cannot be shot honestly:
   the archive holds **one row** and the collection is **empty**. A tight four reads as
   considered; a fifth frame advertising emptiness reads as what it is.

   **Capture recipe, both steps load-bearing:**
   ```
   xcrun simctl status_bar booted override --time "9:41" \
     --batteryState charged --batteryLevel 100 \
     --cellularMode active --cellularBars 4 --wifiMode active --wifiBars 3
   xcrun simctl io booted screenshot frame-N.png
   ```
   Without the status-bar override the frames carry a real clock, a partial battery and
   carrier clutter; 9:41 is Apple's own convention. Suppress notification banners before
   capturing — the first capture taken during this review had an "Apple Intelligence"
   banner sitting across the masthead, which would have shipped to the store.

8. **Caption the four frames in the product's own type.** One short line per frame, Fraunces
   on the linen `#f4efe6` ground, `--ink`, screenshot bleeding full width beneath it. No
   device frame, no colored band, no sans-serif. Product language, not marketing language:
   `One painting a day` — never `Discover amazing art!`.

   This is the one place the plan deliberately spends pixels on words, and it is not a
   violation of Better bar 1's "zero promo cruft": the bar governs what sits between the
   reader and the art *inside* the app. The store preview is a shelf, and a caption in the
   product's own voice makes the shelf look like the room. The rejected alternatives were
   bare screenshots (silence is not confidence on a shelf where competitors explain
   themselves) and conventional bold-sans benefit banners (a non-token colour breaks rule 1
   on the first surface a stranger meets).

9. **Description and promotional text — written to what actually ships.** Drafted here,
   reviewed, then pasted. The first three lines are all Maya reads.

   **The hand-written editorial claim comes out.** `user-research/0004` §7.2 names it as
   one of four things nobody in the category ships and DailyArt's own reviewers prize it
   — but the queue reports **1 of 1 published day running museum text (100%)**, against
   `decisions/0004`'s bet that it stays under 20%. A listing that claims a voice its own
   screenshots do not show is a claim the product has to grow into after the filing, and
   the filing is not the place to write a promise.

   What the copy leads on instead, both true today and both unoccupied per `0004` §7:
   **free with no ads and no paywalled archive**, and **curation beyond the Euro-canon** —
   53% of the pool outside Europe and North America, held there by a quota table that
   fails the build if a reseed regresses it. The subtitle survives unchanged: museum text
   *does* explain, so `One painting a day, explained` stays honest.
10. **`DELETE /device` — the missing exit door** (eng review, Issue 5). `AccountsController`
    returns early `unless current_user` (`accounts_controller.rb:7`), so **the default iOS
    state — a registered device that never signed in — has no way to delete anything**. Its
    `Device` row and its device-keyed favorites persist. A policy promising in-app deletion
    would be false for the majority of readers, so this ships with the policy rather than
    after it. Mirrors the account door: destroy the `Device` row and its favorites, reached
    from the same collection-page confirm dialog, clear the signed cookie, no soft delete.

11. **App Store Connect metadata, the complete field set.** The design review named
    category, keywords, description, age rating, screenshots and privacy labels. Also
    required and previously missing (outside voice): **Content Rights** (the pool is CC0
    museum imagery — declare third-party content and its licence), **Copyright**,
    **Price and Availability**, **DSA trader status** (an EU requirement; a non-trader
    declaration still has to be filed), **App Review contact information**, and **version
    release settings** — set to *manually release* so approval does not publish on its own.

12. **Privacy labels** — filed to match the policy written in step 3, field by field.
    Contact Info (email, name), Identifiers (device token), and **User Content / Usage
    Data for the favorites a reader keeps**, which the design review omitted. Apple
    requires collected data to be declared even when it is used only for app
    functionality, and a kept work is data about a person's behaviour stored against their
    identifier. No tracking, no data used for advertising. This is the one session-gate-6
    item inside this story, because it is part of the filing rather than part of the
    operations.

13. **Archive and upload** — `xcodebuild archive` + `-exportArchive` with an App Store
    Connect API key, `CURRENT_PROJECT_VERSION` bumped per upload. Upload does not submit.

14. **Stop.** Submission waits on the gate-6 work that is not in this story.

## Sequencing constraints the steps above depend on

Two things must be true before step 7 can be shot at all, and neither is obvious from the
step list:

- **`script/ios-secrets` must have been run** so `Config/Secrets.xcconfig` exists. Without
  it `Release.xcconfig` falls back to `TONDO_APP_SECRET = CHANGEME`, registration answers
  401, `DeviceIdentity.register` swallows it, and the shell degrades to the public landing
  page. **Frame 4 photographs `/feed`, which is behind the wall** — so a wrong secret does
  not produce an error, it produces a screenshot of the sign-in bounce. Verify with the
  204 check, not by looking at the app.
- **`support@dailytondo.com` must route before the pages DEPLOY**, not merely before the
  filing — this supersedes the earlier note (outside voice). Once `/privacy` is live
  telling readers they can request deletion at that address, a dead address makes the
  *published policy itself* false, independent of anything App Store Connect knows.

## Shell behaviour for the two new pages

`ios/Tondo/path-configuration.json` carries rules for `/`, `/feed` and `/admin` and says
nothing about `/privacy` or `/support`, so today they would inherit the default and open
in the web view with app chrome. **Keep that** — a reader who taps through to the policy
mid-session should not be ejected into Safari, and `LinenSafariRouteDecisionHandler` is
for links that leave the product, which these do not. Worth stating rather than leaving
implicit: the file is served by Rails at `public/configurations/ios_v1.json`, so this rule
can change without an App Store review, which is exactly why an unstated default is easy
to leave wrong for months.

Accessibility on both pages is inherited rather than new: the only controls are links
built on `.caps-link`, which rule 9 already forces to a 44px target, and every token in
use is AA or better at its size. No new component means no new a11y surface.

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
- A test that renders both pages **through the real view**, not just the controller, so the
  `compass_destinations` contract is exercised. `here: nil` is correct and `here: :privacy`
  raises; a controller-only test would pass either way.

Added by eng review:

- **Old-browser access, asserted with a UA Rails actually blocks.** The original test used
  an empty/non-modern UA, which returns 200 whether or not the browser gate applies — it
  would have passed against the broken `skip_before_action`. Use the Safari 14 string
  measured at 406 against production, and assert 200.
- **Extend `test/integration/public_cache_headers_test.rb`.** `PUBLIC_PAGES = %w[/]` today,
  and the file's header comment states the front door "is now the ONLY public page". This
  story makes that false by adding two more. Add `/privacy` and `/support` to the constant
  **and rewrite the stale comment in the same commit** — an out-of-date comment about which
  pages are public is worse than none, and story 0007's whole subject was a `public`
  response carrying `Set-Cookie` into a shared Thruster cache.
- **`DELETE /device`** — a registered device deletes its row and its favorites; a signed-in
  user hitting it is unaffected; an unregistered visitor is redirected. Plus a test that
  the collection page offers the control to a device and the account control to a user.
- **The policy's forcing function** (R1, Issue 3): a test asserting `Gemfile.lock` contains
  none of `ahoy`, `mixpanel`, `segment`, `google-analytics`, `sentry`, `appsignal`,
  `honeybadger`, `scout_apm`, `bugsnag` for as long as the policy claims no analytics and
  no tracking. Session gate 6 requires error tracking, so this fires within weeks — by
  design. When it goes red the fix is to edit the policy and the privacy labels, and the
  test failure is what says so.

`bin/ci` green before QA, per build flow. Note `bin/ci` is Rails-only — the iOS side is
`script/ios-build`, which Issue 2 extends to cover Release.

## Design review decisions (2026-08-16, `/plan-design-review`)

Four decisions, each replacing something the plan had left to chance.

| # | Decision | What it replaced |
|---|---|---|
| D1 | **Shoot what exists; rewrite the copy to match.** | Filing a listing whose central claim — hand-written editorial — its own screenshots contradict. |
| D2 | **`Royal Elephant Ramkali` (id 2691) is frame 1 and today's pick.** | The calendar choosing the store hero, and choosing a dark brown portrait that reads as a smudge at 150px. |
| D3 | **Four frames, not five.** | An archive frame showing one row and a collection frame showing nothing. |
| D4 | **Captions in Fraunces on linen.** | An unresolved tension between conversion convention and Better bar 1, settled by extending the room to the shelf. |

**What D1 costs, stated once.** The evidence in `user-research/0004` §7.2 says hand-written
editorial at daily cadence is the rarest thing in this category and the thing the leader's
own reviewers name. Shipping a listing that does not claim it is shipping without the moat
`CLAUDE.md` names first. The queue is at **100% museum text against a 20% bet**
(`decisions/0004`), so the claim is unavailable rather than declined. This does not need
reopening now; it needs a written day before the copy can ever change.

## Eng review decisions (2026-08-16, `/plan-eng-review`)

Scope accepted as-is — five files, one new class, under both complexity thresholds. Five
findings, all folded. Two of them correct earlier calls in this same document.

| # | Finding | Decision |
|---|---|---|
| E1 [P1] | `skip_before_action :allow_browser` raises; `raise: false` is a silent no-op. Verified in this app. | `PagesController < ActionController::Base` — nothing to skip |
| E2 [P2] | Nothing builds Release; both defects fixed on 2026-08-16 lived there unseen | `script/ios-build` gains a Release pass + Info.plist assertions |
| E3 [P1] | The policy's "no analytics" claim has no enforcement (R1) | A test on `Gemfile.lock` that goes red when it stops being true |
| E4 | **Reverses the design review.** 5.1.1(i) requires an in-app policy link | Privacy + Support in the existing `.coda`, not a new footer |
| E5 | **Reverses an assumption.** Device-only readers cannot delete anything | Build `DELETE /device` alongside the policy |

**Outside voice (Codex, `model_reasoning_effort=high`).** Independently found E1. Also
supplied E4, E5, the natural-key correction in step 6, the `public_cache_headers_test.rb`
gap, the incomplete App Store Connect field set, and the `support@` sequencing correction.
Every claim above was verified against this repo before being folded in; none was taken on
the outside voice's word.

**Cross-model agreement on the strategic point.** Codex, unprompted, reached the same
conclusion as this plan's own unresolved-decisions list: uploading a build while daily
advancement is unsolved is the lower-leverage move, and making the app actually sustain a
daily cadence through Aug 31 matters more than the upload. Recorded, not acted on — the
listing work is what the curator chose, and the tension is named rather than buried.

## NOT in scope — considered and deferred

- **A nudity screen on the pool.** 12+ is the category norm and the honest filing; a filter
  would narrow the pool that story 0013's quota table exists to keep broad. One line: the
  *thumbnail* must not be a nude, which D2 satisfies.
- ~~**A footer.**~~ **Reversed by eng review (Issue 4) — this deferral was wrong.** The
  design review deferred any in-app route to the policy on the grounds that site-wide chrome
  costs 44px a row. Guideline **5.1.1(i) requires the privacy policy link in App Store
  Connect metadata *and* within the app in an easily accessible manner**, so deferring it
  would have caused precisely the 5.1.1 rejection this plan's success signal is written to
  avoid. **In scope now:** Privacy and Support as `.caps-link`s in the existing `.coda` on
  the collection and archive screens, which already carry one. Not a new site-wide footer,
  and deliberately not on the daily page, whose job `DESIGN.md` rule 5 protects.
- **An empty-state pass on `/collection`.** It is what every new installer meets on day one
  and it is a product story, not a listing one. Named here so it is not discovered by a
  reviewer.
- **Regenerating mockups.** The gstack designer needs an OpenAI key that is not configured;
  real captures from the Release build against production were used instead, which for this
  artifact is better evidence, not a downgrade.

## What already exists — reuse, do not reinvent

`DESIGN.md` (414 lines, 9 rules, 3 named exceptions, tokens with measured contrast), and in
the codebase: `_masthead`, `_compass`, `.caps-link`, `--measure`, the `✦` divider, the
linen 404 from story 0004, `.plate__img`'s 55vh cap, and the `--mount-bg` full-screen view
that frame 3 photographs. Both new pages are assembled entirely from these; the review
added **no new component**, which is why pass 5 lands where it does.

## Known gaps, named rather than omitted

- **Daily push does not exist.** No `aps-environment` entitlement, no APNs code in `app/`,
  `lib/` or `ios/`. Baseline item 2 and one of two named moats. Submitting without it means
  the listing describes a daily habit the app cannot start on its own. Its own story; the
  App ID will need the Push Notifications capability added then.
- **`support@dailytondo.com` does not receive mail yet.** Curator-owned, due before
  submission (step 10), not before the page ships — the page can carry the address while
  the routing is pending, the *filing* cannot. Verify by sending mail to it from an
  unrelated account and reading it, the same way a restore test is a restore, not a
  snapshot.
- **Session gate 6 is open** — no backups, no logged restore test, no error tracking, no
  analytics, against a SQLite file on one GCP disk. This story files accurate privacy
  labels and closes nothing else. **The gate blocks Submit for Review, not this plan.**
- **Nothing advances the day.** `app/jobs/` holds only `application_job.rb`, Solid Queue is
  not in the Gemfile, and `DailyPick.current` holds the last published day over
  indefinitely — which is why the live masthead read `FRI, AUG 14` on Aug 16 and why a
  store frame shot without step 6 would have carried a stale date. Step 6 clears it once,
  by hand. **It does not fix it.** The listing will say "one painting a day" about a
  product whose day only advances when the curator schedules one. Its own story, and a
  more urgent one than push: an installer who opens the app on a day nobody scheduled sees
  yesterday, silently.
- **Editorial voice is unwritten, not merely unclaimed** (D1). 0 hand-written notes across
  1 published day, against `decisions/0004`'s under-20% bet.

## Implementation Tasks
Synthesized from this review's findings. Each task derives from a specific finding above.

- [ ] **T1 (P1, human: ~10min / CC: ~5min)** — content — Schedule `Royal Elephant Ramkali`
  (painting id 2691) as today's pick
  - Surfaced by: Pass 1 — live masthead prints `FRI, AUG 14` on Aug 16; store hero was
    being chosen by calendar
  - Files: `/admin/daily_picks` on production
  - Verify: `curl -s https://dailytondo.com/ | grep -o 'AUG 1[0-9]'` shows today
- [ ] **T2 (P1, human: ~2h / CC: ~30min)** — `PagesController` — Ship `/privacy` and
  `/support`, skipping `require_reader` and `allow_browser`, compass rendered with `here: nil`
  - Surfaced by: Approach — two mandatory App Store Connect URL fields point at pages this
    repo does not serve; `compass_destinations` raises on an unknown key
  - Files: `config/routes.rb`, `app/controllers/pages_controller.rb`, `app/views/pages/`
  - Verify: `bin/ci`, then anonymous `curl -I https://dailytondo.com/privacy` → 200
- [ ] **T3 (P1, human: ~1h / CC: ~20min)** — screenshots — Capture four frames at
  1320 × 2868 with the 9:41 status-bar override and banners suppressed
  - Surfaced by: Pass 1 / D3 — archive has one row and collection is empty, so the planned
    fifth frame cannot be shot honestly; first capture in this review had a system
    notification across the masthead
  - Files: `~/.gstack/projects/tasteMaker/designs/appstore-hero-20260816/`
  - Verify: `sips -g pixelWidth -g pixelHeight` on each frame reads 1320 × 2868
- [ ] **T4 (P2, human: ~1h / CC: ~20min)** — screenshots — Compose caption canvases in
  Fraunces on linen, one line per frame
  - Surfaced by: D4 — captions in the product's type system rather than bare frames or a
    marketing band
  - Files: same designs directory
  - Verify: no non-token colour present; type is Fraunces, not a system stack
- [ ] **T5 (P2, human: ~45min / CC: ~15min)** — copy — Rewrite description and promo text to
  lead on free-with-no-ads and non-Euro curation; remove the hand-written editorial claim
  - Surfaced by: D1 — queue reports 100% museum text against `decisions/0004`'s 20% bet
  - Files: this plan, then App Store Connect
  - Verify: no sentence in the description asserts a hand-written note
- [ ] **T6 (P3, human: ~10min / CC: ~5min)** — `path-configuration.json` — State the rule for
  `/privacy` and `/support` explicitly rather than inheriting the default
  - Surfaced by: Shell behaviour section — served from Rails, changeable without review,
    and an unstated default is easy to leave wrong for months
  - Files: `ios/Tondo/path-configuration.json`, `public/configurations/ios_v1.json`
  - Verify: tap a policy link in the shell and confirm it stays in the web view
- [ ] **T7 (P1, human: ~1.5h / CC: ~25min)** — `DevicesController` — Build `DELETE /device`
  so device-only readers can delete their row and favorites
  - Surfaced by: Eng review E5 — `accounts_controller.rb:7` returns early unless
    `current_user`, so the default iOS state has no deletion path and the policy would lie
  - Files: `config/routes.rb`, `app/controllers/devices_controller.rb`,
    `app/views/favorites/index.html.erb`, `test/integration/`
  - Verify: `bin/ci`; a registered device deletes and its favorites go with it
- [ ] **T8 (P1, human: ~45min / CC: ~15min)** — `.coda` — Add Privacy and Support links on
  the collection and archive screens
  - Surfaced by: Eng review E4 — guideline 5.1.1(i) requires an in-app policy link; the
    design review's footer deferral would have caused a 5.1.1 rejection
  - Files: `app/views/favorites/index.html.erb`, `app/views/days/index.html.erb`
  - Verify: `test/system/favorites_test.rb` asserts `.coda .caps-link count:2` today — that
    assertion changes, per the `masthead-nav-breaks-system-tests` learning
- [ ] **T9 (P1, human: ~30min / CC: ~10min)** — tests — Extend
  `public_cache_headers_test.rb` to the two new public pages and rewrite its stale comment
  - Surfaced by: Outside voice — `PUBLIC_PAGES = %w[/]`, and the header comment claims the
    front door is the ONLY public page, which this story makes false
  - Files: `test/integration/public_cache_headers_test.rb`
  - Verify: `bin/ci`
- [ ] **T10 (P1, human: ~30min / CC: ~10min)** — tests — Assert no tracking dependency in
  `Gemfile.lock` for as long as the policy claims none
  - Surfaced by: Eng review E3 — R1, an artifact without its enforcement
  - Files: `test/integration/privacy_claims_test.rb`
  - Verify: `bin/ci`; adding `sentry-ruby` turns it red
- [ ] **T11 (P2, human: ~30min / CC: ~10min)** — `script/ios-build` — Add a Release pass
  with Info.plist assertions
  - Surfaced by: Eng review E2 — the Debug-only build check let `CHANGEME` and the missing
    `DEVELOPMENT_TEAM` sit in the tree until 2026-08-16
  - Files: `script/ios-build`
  - Verify: `script/ios-build` fails when `Config/Secrets.xcconfig` is removed

## Approved Mockups

| Screen | Path | Direction | Notes |
|---|---|---|---|
All under `~/.gstack/projects/tasteMaker/designs/appstore-hero-20260816/`. Real
Release-build captures against production at 1320 × 2868, 9:41 status bar.

| Slot | Captioned file | Raw capture | Caption |
|---|---|---|---|
| 1 | `store-1.png` | `frame-1-front-door.png` | One painting a day. |
| 2 | `store-3.png` | `frame-3-zoom.png` | Look as close as you like. |
| 3 | `store-4.png` | `frame-4-gallery.png` | Two thousand works. No ads, no paywall. |

`raw-02-front-door-clean.png` is kept as the before: the same screen carrying the
rejected incumbent pick and a two-day-stale date. `frame-2-label.png` is the
failed scroll attempt, kept so the next person does not repeat it.

## The copy, as filed (T5)

**Promotional text** (170 char limit, editable without a review):

> One painting a day from the world's open museum collections. Free, no ads,
> nothing locked away.

**Description.** First three lines are all Maya reads; they carry the two claims
`user-research/0004` §7 says are true here and unoccupied by anyone with traction.
No hand-written editorial claim anywhere in it (D1).

```
One painting a day, from the world's great museum collections. Free, with no
advertising and nothing locked away.

Tondo opens on a single artwork — a Rajput elephant, a Mughal bird study, a
Japanese screen, a Dutch harbour — with its title, its maker, and the museum's
own note on what you are looking at. Read it in a minute with your tea, or stay
and look closer. Then it is done until tomorrow.

WHAT IS IN IT
• 2,000 works from the Metropolitan Museum of Art, the Art Institute of Chicago,
  the Cleveland Museum of Art and the Minneapolis Institute of Art
• More than half from outside Europe and North America — Japan, China, India,
  Persia and beyond, not the same forty paintings everywhere else shows you
• Every image public domain, every plate high resolution, zoomable to the
  brushwork
• Every day you have seen stays in the archive, and you can keep the ones worth
  returning to

WHAT IS NOT IN IT
• No advertising
• No paywalled archive
• No account needed — sign in only if you want your collection to follow you to
  a new phone
• Nothing between opening the app and the artwork

Made by one person. Write to support@dailytondo.com and that person reads it.
```

Two phrasings are deliberately narrow. "Every day you have seen stays in the
archive" describes the mechanism rather than claiming a volume, because the
archive holds **two days**. And "more than half from outside Europe and North
America" is the quota table's 53%, which `test/lib/pool_quota_test.rb` fails the
build over — a checkable number rather than a mood.

## Deviations (added during build)

- **2026-08-16 — frame 2 was not captured, and the set ships as three.** The plan
  called for four frames; the "wall label scrolled" one could not be produced
  reliably. Four approaches failed: an instantaneous `cliclick` drag (no scroll),
  a slow stepped drag (WKWebView read it as a long-press and selected text), a
  fast flick (no scroll), and a throwaway build whose start URL carried the
  `#daily-note` anchor (rendered a blank linen page). `xcrun simctl` has no
  pointer input, so there is no first-party way to drive it.

  Frames 1, 3 and 4 are captured, captioned and store-ready at 1320 × 2868.
  Apple's minimum is one. **The loss is small**: frame 1 already shows the title,
  artist, medium, the opening of the note, `MORE` and the museum attribution
  above the fold, which is most of what frame 2 was for.

  Two ways to close it later, neither blocking: record the scroll by hand in the
  Simulator with a human doing the swipe, or add a `?scroll=note` query the daily
  page honours. The second is code written for a screenshot, which is the failure
  pattern `CLAUDE.md` names, so the first is the recommendation.

- **2026-08-16 — the store hero is `source: cma / source_id: 163797`, production
  id 860.** The design review named local id 2691. Confirmed at scheduling time
  that production assigns different ids, exactly as the outside voice warned. The
  natural key found it; the local id would have scheduled a different painting.

- **2026-08-16 — captions are composed in HTML, not an image editor.** No image
  library is available on this machine (no PIL, no ImageMagick, no libvips — the
  same absence `config/application.rb` records for Active Storage variants), so
  each frame is a small HTML page rendering the caption in the app's own Fraunces
  woff2 over `#f4efe6`, screenshotted headless at 1320 × 2868. Sources are kept
  next to the output as `cap-*.html` so a caption can be reworded without redoing
  the capture.

## GSTACK REVIEW REPORT

| Review | Trigger | Why | Runs | Status | Findings |
|--------|---------|-----|------|--------|----------|
| CEO Review | `/plan-ceo-review` | Scope & strategy | 0 | — | — |
| Codex Review | `/codex review` | Independent 2nd opinion | 1 | ISSUES_FOUND | outside voice, 5 verified corrections folded |
| Eng Review | `/plan-eng-review` | Architecture & tests (required) | 1 | CLEAR (PLAN) | 5 issues, 0 critical gaps |
| Design Review | `/plan-design-review` | UI/UX gaps | 1 | ISSUES_OPEN | score: 4/10 → 8/10, 4 decisions |
| DX Review | `/plan-devex-review` | Developer experience gaps | 0 | — | — |

**CODEX:** Independently found the `allow_browser` defect. Also supplied the
5.1.1(i) in-app policy requirement, the missing device deletion path, the
local-vs-production painting id, and the `public_cache_headers_test` gap. All
verified against the repo before folding; the painting id was confirmed wrong at
scheduling time (local 2691, production 860).

**CROSS-MODEL:** Two reviewers reached the `allow_browser` finding independently,
and both reached the same strategic conclusion: daily advancement outranks the
upload. The second is recorded, not acted on.

**VERDICT:** ENG + DESIGN CLEARED — implemented, deployed, `bin/ci` green
(308 runs / 1614 assertions / 0 failures, 47 system tests). T1–T11 done except
the frame-2 capture, which is a recorded deviation rather than an open decision.

**UNRESOLVED DECISIONS:**
- `support@dailytondo.com` has no mail routing, and it is now **live on two
  published pages** telling readers they can request deletion there. This moved
  from "blocks the filing" to "the deployed policy is currently overstating a
  channel", and it is the most urgent item on this list.
- Nothing advances the day. Step 6 scheduled Aug 16 by hand; on Aug 17 the front
  door holds it over again. Both reviewers flagged it, it still has no story, and
  the listing copy now says "one painting a day" in public.
