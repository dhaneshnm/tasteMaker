# 0017 — Your corner · implementation plan

Story: `specs/0017-your-corner/story.md`. Direction record: `decisions/0013`.

## The measurement that changes the chosen design

The intake picked "glyph pinned right **on the compass row**." It does not fit.
The numbers are already in the codebase, in `application.css:296-320` and
`specs/0012-getting-around/plan.md`, and they say so before a line is written:

```
at 375px, Dynamic Type at its cap (root = 20px)

  the gap term, evaluated properly:
    clamp(0.7rem, 3.5vw, 1rem) = clamp(14.000, 13.125, 20.000)
    CSS clamp = max(MIN, min(VAL, MAX)) = max(14.000, 13.125) = 14.000px
    → the vw term LOSES at the cap. It only wins below root 20px.

  four labels ............................ 270.0px
  three gaps at 14.0px .................... 42.0px
  ─────────────────────────────────────────────────
  compass row ............................ 312.0px
  space the page leaves .................. 329.0px
  spare .................................. 17.0px

  adding the glyph: 44px target + one more 14px gap = 58.0px needed
  spare available ........................ 17.0px
  ─────────────────────────────────────────────────
  short by ............................... 41.0px  → the row wraps
```

**Correction, recorded rather than quietly fixed.** The first draft of this plan
used 13.125px for the gap — the `3.5vw` term — and reported a 37.5px shortfall.
That is wrong: at the accessibility cap the root is 20px, so the `0.7rem`
minimum is 14.0px and `clamp` floors to it. The real shortfall is **41.0px**.
The conclusion does not change; the number in every artefact does. Found by the
design panel, 2026-08-17.

**And it is not only a measurement.** `test/system/favorites_test.rb:155-166`
asserts, on this exact element at 375px:

```ruby
assert_selector ".compass .caps-link", count: 4   # exactly four
tops = items.map { |i| i.native.location.y }.uniq
assert_equal 1, tops.size                          # one row
gap >= 10                                          # adjacency floor
```

So a fifth item in the compass fails a written test three ways, not one. There
is no version of the compass-row option that is a measurement argument.

The 44px cannot be shaved: `DESIGN.md` rule 9 is "at least `--tap` in every
direction it has," and ISSUE-002 (commit 866bbc2) is the receipt for what
happens when a glyph gets less. A wrapped compass costs 44px straight out of
the fold budget on every screen — the front door currently clears the
accessibility fold by **9px**, so a wrap puts the day's first written line
below it and `test/system/dynamic_type_test.rb` goes red. Correctly.

## Decisions locked (owner, 2026-08-17)

| # | Decision | Chosen |
|---|---|---|
| 1 | The mark | **The oculus** — the rose window's centre, `circle r=7.4` stroked + `r=2.5` filled, in a 23px box, 1.4px stroke, `--gold`, 44px target |
| 2 | Placement | **Corner glyph + coda word.** Oculus in the masthead's right column on every screen, *and* a `Your corner` caps-link in the coda — the word teaches the mark, which a ring-and-dot cannot do alone |
| 3 | The room | **Threshold for the decision states, prose for the account state.** Device and signed-out get the consequence at display size; signed-in has no decision to dramatise and drops to the quiet-line voice |
| 4 | The name | **Your corner**, route `/you` |
| 5 | The `/` footer | **Deleted entirely.** `sessions#control`, the `signin` turbo-frame and the `/#signin` anchor all go — the glyph and the word are identical markup for every reader, so the landing page needs no per-visitor fragment at all |
| 6 | Sign-out in the app | **Same control as web**, guarded by a confirm that names where the works went |

Decision 5 is the one that makes this plan smaller than it was: it removes an
endpoint, a lazy frame, and the product's most delicate cache hazard rather
than adding to them.

**Resolution on placement: the glyph goes to the masthead's top-right corner,
not the compass row.** It costs zero fold budget because the brand + label rows
are already ~44px of vertical space that the glyph shares rather than adds to.

```
narrow (< 46rem)                     wide (≥ 46rem)
┌──────────────────────────┐         ┌─────────────────────────────────┐
│ TONDO        13 AUG   ◎ │         │ TONDO   TODAY DAYS…  13 AUG  ◎ │
│ Artwork of the day       │         │ Artwork of the day              │
│ TODAY  DAYS  KEPT  GALLERY│        └─────────────────────────────────┘
└──────────────────────────┘
   ↑ compass untouched, four words, one row
```

**The grid line that makes it free — and the version that does not.**
`label` must span the first TWO columns. Put `you` in a third column while
`label` stays in the `1fr` and that column drops **198.19 → 134.19px** at root
20: "Artwork of the day" wraps to two lines and the masthead goes **117.00 →
137.00px**. That is +20px against 9px of fold. Measured on the patched tree.

```css
.masthead {
  grid-template-columns: 1fr auto auto;
  grid-template-areas:
    "brand   aside   you"
    "label   label   you"      /* ← the whole trick: label takes its width back */
    "compass compass compass";
}
```

The `>= 46rem` block at `application.css:352-366` names every area explicitly
and will place a new one implicitly if `you` is omitted there too:
`"brand compass aside you" / "label compass aside you"`.

**Honest cost table, replacing "0px at every root".** Measured on the shipped
stylesheet with the shipped woff2 subsets loaded:

| root | masthead before | after | delta |
|---|---|---|---|
| 20.0 (accessibility cap) | 112.00 | 112.00 | **0.00** |
| 19.2 (largest standard) | 108.02 | 109.14 | **+1.13** |
| 16.0 (default) | 98.17 | 105.78 | **+7.61** |

The cap is the size `dynamic_type_test.rb`'s tightest assertion runs at, and
there the cost is genuinely zero. At the default root the note clears the fold
by roughly 180px, so +7.61 is affordable — but the plan must not claim zero.

**The compass-row shortfall re-confirmed independently.** Two agents
re-measured the four labels at 270.23px (`[69.52, 52.56, 54.17, 93.98]`),
matching story 0012's recorded 270.0. With 14.00px gaps: row 312.23, spare
16.77, a fifth item needs 58.00 → **short by 41.2px**. The figure in this plan
was right; only the earlier 37.5px draft was wrong.

**Cost, stated:** on `/feed` the compass is a sticky rail and the masthead is
not sticky, so the glyph scrolls away there. Accepted rather than solved: the
rail exists for the *frequent* exits, and the account screen is a rare control
— the same argument design review D5 used in story 0015 to keep account
administration out of every screen. The alternative is wrapping the sticky rail
on the one screen that can least afford permanent chrome.

Owner accepted the `/feed` gap explicitly (2026-08-17). The two alternatives —
rendering the coda on every feed page, or making the feed masthead sticky —
were declined; the second would reverse `decisions/0008` and rule 5's one
narrowing, on the numbers story 0012 already settled (sticky masthead 104px vs
sticky rail 44px on a 667px screen).

## Where the coda word actually goes — a conflict from yesterday

`app/views/shared/_legal.html.erb` is one day old (commit `dd90512`) and its
comment decides the opposite of the obvious placement:

> *"the two screens that already end in a `.coda` are the reader's own room and
> the archive… The daily page is not one of them on purpose — DESIGN.md rule 5
> keeps nothing between the reader and the artwork, and every row of these costs
> a full 44px on a screen already measured tight against the fold."*

So `Privacy · Support` ships on `/collection` and `/days` and deliberately not
on `/`. A `Your corner` caps-link on its own row in the daily coda would
contradict that decision while its ink is wet.

**Resolution (design review 2A): the word ships on `/` ONLY, joining the row
that already exists there.** The first draft of this section said it joins the
existing row on every coda screen. Reading the templates killed that: only `/`
has such a row.

```
/  ONLY                   ─── ✦ ───
                        See you tomorrow.
              WANDER THE FULL GALLERY →   ◎ YOUR CORNER
                        ↑ one row, two caps-links, 0 new px, no arrow (5B)
```

Why not the others, screen by screen:

| Screen | Coda contains | Verdict |
|---|---|---|
| `/` | ornament + "See you tomorrow." + one caps-link | **word ships here** |
| `/days/:date` | ornament + `days/walk` (prev · next · today) | no caps-link row to join; adding one costs 44px |
| `/days`, `/collection` | `.legal` — `aria-label="About this app"` | an account door in a legal nav is the wrong semantics, announced |
| `/feed` | coda renders on the LAST page only — page 200 of 200 at `PER_PAGE = 10` | unreachable in practice |
| `daily/empty`, `404`, `/privacy`, `/support` | no coda row | nothing to join |

The word's job is to teach the mark once. `/` is the screen every reader opens
every day; the oculus carries the other seven surfaces on its own.

This still resurrects one deleted rule. `application.css:752-755` records that
`.coda > .caps-link + .caps-link` was removed in story 0012 *"because no coda
has two adjacent caps-links left."* That stops being true on `/`, so the gap
rule comes back — a small, named CSS delta rather than a surprise at implement
time.

## Three more findings from the design panel, all verified against the repo

1. **`→` is not in the shipped fonts.** `application.css:50` and `:77` declare
   `unicode-range: … U+2191, U+2193 …` — the list steps over **U+2192**, and
   `U+2000-206F` is General Punctuation, which does not reach the Arrows block.
   So *"Wander the full gallery →"* already renders its arrow in a fallback face
   today, live, on every screen that shows it. Not caused by this story, but
   this story would triple the number of places it happens. Either subset the
   arrow into the font, or use `↑`/`·` which are covered, or drop the arrow.
   **Own it here rather than shipping three more instances of a live defect.**
2. **`/feed`'s coda is further away than the story says.** `PaintingsController::
   PER_PAGE = 10` against a pool of ~2,000 works — the last page is page 200,
   not page 11. The "no door on `/feed`" cost is larger than it reads, which
   strengthens the accepted-gap decision rather than weakening it.
3. **A reachability test cannot just visit all five surfaces.** `days_path` and
   `collection_path` are behind `require_reader`, so a test that asserts the
   corner door renders everywhere has to carry an identity or it fails on the
   wall before it renders a masthead.

## Phases

Order chosen so the thing that cannot be tested by `bin/ci` is proven earliest,
on a branch, before the surface work depends on it.

### Phase 0 — Prove the transport (spike, throwaway)

Before any of the below. A branch that renders a bare button on `/you`, runs
`ASWebAuthenticationSession`, and gets a session cookie into the WKWebView jar
on a simulator. If Google 403s this too, or the handoff cannot cross the jar
boundary, the whole native half of the story is wrong and it should be found on
day 0, not day 2. Spike code is deleted, not merged.

**Exit condition:** the simulator shows `/you` reporting a signed-in account
after the sheet closes.

### Phase 1 — The surface (`/you`), web only

Nothing native. Ships standalone and is the half that would have been the
"split" option.

| File | Change |
|---|---|
| `config/routes.rb` | `get "you" => "corners#show", as: :corner` |
| `app/controllers/corners_controller.rb` | **new.** `skip_before_action :require_reader`, `before_action :no_store`. Computes the same tri-state `SessionsController#control` does and renders it. |
| `app/views/corners/show.html.erb` | **new.** Masthead + three-state body. |
| `app/views/shared/_masthead.html.erb` | Add the glyph, unconditionally, in the `aside` column's row band. Static markup — **no per-visitor content**, see the cache note below. |
| `app/views/shared/_account_glyph.html.erb` | **new.** 23px box, 1.4px stroke, `--gold`, `aria-label="Your corner"`. |
| `app/assets/stylesheets/application.css` | `.masthead__you` grid area + the `@media (min-width: 46rem)` grid-areas block, which names every area explicitly (`:352-357`) and will place the new one implicitly if it is not added there too. |
| `app/helpers/application_helper.rb` | `COMPASS` **unchanged** — `/you` is deliberately not a compass destination. |
| `app/controllers/application_controller.rb` | `require_reader`: bounce target `root_path(anchor: "signin")` → `corner_path`, both the redirect (`:85`) and the frame-write link (`:81`). |
| `app/views/sessions/_control.html.erb` | **Deleted**, with `SessionsController#control`, its route, and the `turbo_frame_tag "signin"` at `daily/_day.html.erb:194`. Decision 5 governs; the earlier "`:signed_out` keeps the note + two doors" row contradicted it and was wrong (design review, D-fix). |
| `app/views/favorites/index.html.erb` | Both `<footer class="account">` blocks (`:53-73`) reduce to the honest-limit line; the two delete buttons move to `/you`. |
| `app/views/pages/privacy.html.erb`, `pages/support.html.erb` | Deletion path copy follows the buttons. **Ship blocker** — story 0016's defect was a filed policy naming a path that did not exist. |

**The cache trap.** `/` is `Cache-Control: public` behind Thruster and its HTML
must stay byte-identical across all three identity states (story 0007,
`test/integration/public_cache_headers_test.rb`). The glyph therefore renders
the same markup for everyone — it is a link to `/you`, never a signed-in/out
indicator, never an avatar, never a count. Everything per-visitor stays behind
`/you` itself, which is `no-store`.

### Phase 2 — The claim (device → account)

Pure server. Testable end to end by `bin/ci`, so it lands before the native
work rather than tangled with it.

- `app/models/favorite.rb` — `Favorite.claim!(device:, user:)`. One
  transaction. Rows whose painting the account already keeps are **deleted**,
  not updated, or the partial unique index
  (`index_favorites_on_user_id_and_painting_id`) raises. Sets `user_id` and
  nulls `collector_digest` in the same write — the model validates that exactly
  one is present (`:32-36`), so a two-step update is invalid in between.
- `app/controllers/sessions_controller.rb#create` — after `User.from_omniauth`,
  **before** `reset_session`: read `current_device`, then claim. Order matters;
  `reset_session` does not clear the signed `device` cookie (it is not session
  state) but reading identity before the swap keeps the sequence obvious.
- Idempotent by construction: second sign-in claims an empty relation.
- The `Device` row is **not** destroyed. It stays registered and the wall keeps
  passing it, which is what makes sign-out land on a working device identity.

### Phase 3 — Sign-in inside the shell

| File | Change |
|---|---|
| `db/migrate/*_create_handoff_tokens.rb` | `token_digest` (unique), `user_id`, `expires_at`, `consumed_at`. A **table**, not a signed message with a cached nonce — the cache store is `:null_store` in test, so a cache-backed replay guard is a silent no-op in the suite. |
| `app/models/handoff_token.rb` | **new.** `issue!(user)`, `consume!(raw)`. Single use, 60s TTL, digest-at-rest like `Device` (`device.rb:11`). |
| `app/controllers/sessions_controller.rb` | `#create` detects the native flow and redirects to `tondo://auth?handoff=…` instead of `days_path`. `#handoff` (new, unwalled) consumes and sets `session[:user_id]` in the web view's jar. |
| `config/routes.rb` | `get "session/handoff" => "sessions#handoff"` |
| `app/javascript/controllers/sign_in_controller.js` | **new.** Bridge component. |
| `ios/Tondo/SignInComponent.swift` | **new.** `ASWebAuthenticationSession`, `presentationContextProvider`, callback scheme `tondo`. |
| `ios/Tondo/AppDelegate.swift` | Register the component. **`:28-35`'s comment says "none are registered" — that comment becomes false and is part of this diff.** |
| `ios/Tondo/LinenSafariRouteDecisionHandler.swift` | `matches` is a bare off-host test (`:28`). It must not claim `/auth/*` or the provider hosts, or the sheet opens in the wrong container and the reader returns silently signed out. |
| `ios/Tondo/Info.plist` | `CFBundleURLTypes` → `tondo`. Auth callback only. |
| `app/views/sessions/_control.html.erb` | The `:device` branch stops being empty — it becomes the shell's sign-in doors, routed through the bridge. **This is the line that reverses `decisions/0011` choice 5.** |
| `ios/Tondo/path-configuration.json` + `public/configurations/ios_v1.json` | `/you` presentation. Both files, or `test/integration/path_configuration_test.rb` goes red — which is the test working. |

## Tests (R1 — written with the code, not after)

| Test | Pins |
|---|---|
| `test/integration/public_cache_headers_test.rb` (extend) | `/` still 200, no `Set-Cookie`, identical ETag in all three identity states **with the glyph present**. The story's highest silent-break risk. |
| `test/integration/corner_test.rb` (new) | `/you` unwalled → 200 for a cookieless caller; `private, no-store`; the correct one of three states for each identity. |
| `test/integration/wall_test.rb` (extend) | Bounce lands on `/you`, not `/#signin`. Frame-write branch too. |
| `test/models/favorite_test.rb` (extend) | Claim moves rows; already-kept collision drops rather than raises; second claim is a no-op; `collector_digest` is nulled in the same write. |
| `test/integration/sessions_test.rb` (extend) | Sign-in with a device cookie claims; without one does not; native flow redirects to the `tondo://` scheme; handoff is single-use and expires. |
| `test/integration/privacy_claims_test.rb` (extend) | **The claim in this row was false and is corrected.** The file has three tests (`:40`, `:49`, `:68`) — an analytics-claim string, a lockfile gem scan, and the `POLICY_UPDATED_ON` stamp. **None touches a route.** It did not catch the 0016 defect and would not catch this one. The extension has to be written, not assumed: assert that the deletion path the policy names actually resolves and answers. Found by the outside voice, eng review 2026-08-17. |
| `test/system/dynamic_type_test.rb` (extend) | 375px, Dynamic Type at cap: compass on one row, glyph present, fold budget unchanged. The measurement above, enforced. |
| `test/integration/path_configuration_test.rb` | Already exists; the two config files must not drift. |

**What no test can reach:** the `ASWebAuthenticationSession` round trip.
Simulator verification is the gate, same as story 0015's Apple cross-site POST
— a green suite could not have caught that one either.

## Open questions for review

**Design review — ALL FOUR CLOSED 2026-08-17.** See "Design review decisions"
below. (1) corner, measured, with the label-span fix. (2) the oculus, with a
`DESIGN.md` amendment. (3) claim copy resolved at both ends plus a third state
nobody had specified. (4) `/`'s fragment is deleted outright, not reduced.

**Eng review**
1. Handoff token in a table vs `MessageVerifier` — the `:null_store` argument
   is the reason for the table; challenge it.
2. Claim inside `sessions#create` vs a job. Inline is chosen: a reader watching
   their collection move should not race a queue.
3. Whether `LinenSafariRouteDecisionHandler` should exclude auth hosts by name
   or the bridge should intercept before routing runs at all.
4. Sign-out on iOS returns to the device identity with an empty collection.
   Is a confirm dialog enough, or does sign-out need to be a different control
   in the app than it is on the web?

---

# Design review — 2026-08-17

Reviewed: this file. Seven passes. Initial **5/10**, final **9/10**.
13 decisions taken, 0 unresolved. Two prior learnings applied, two pre-existing
defects found, one of them fixed in this story.

## Design review decisions

| # | Issue | Decision |
|---|---|---|
| 1A | Wall bounce lands signed-out readers on `/you`, where 3 of 4 compass doors bounce them back | **Unlink the walled doors on `/you`**, using the compass's own current-page treatment: `--ink-dim`, no `<a>`, same 44px box |
| 1B | The corner oculus is a self-link on `/you` | **Unlink it there**, `--ink-dim` + `aria-current="page"` — the rule the compass already states |
| 2A | "Joins the existing caps-link row" describes only 1 of 8 surfaces | **Front door only.** The word teaches the mark once, on the screen every reader opens daily |
| 2B | The threshold hero names a count; most devices have zero kept works | **Same shape, future tense at zero** — the rule gets taught before the reader has anything to lose |
| 2C | Three destructive confirms run as `window.confirm()` in WKWebView, unexamined | **Cap the strings, front-load the consequence, screenshot all three on device before ship** |
| 3A | After sign-out the collection shows the first-day empty state, saying nothing about where the works went | **A third empty-collection variant**, gated on new column `devices.claimed_at` |
| 3B | Nothing confirms the claim succeeded | **Land on `/collection` when works moved, `/you` when none did.** The works are the receipt |
| 5A | `DESIGN.md:169-171` says the mark appears nowhere inside the app | **Keep the oculus, amend `DESIGN.md`** — the rule's stated objection is the gilt *field*, not the geometry |
| 5B | `→` is absent from the shipped font subsets | **Ship the new link with no arrow.** Compass words carry none either. Existing defect logged, not fixed here |
| 6A | Glyph and coda word both announce "Your corner" on `/`; `daily_test.rb:155` forbids it | **Exempt links sharing one `href`,** with the reason written into the test |
| 6B | Every measurement came from headless Chrome; the runtime is WKWebView | **Both** — extend `dynamic_type_test.rb` *and* verify once on a simulator |
| 7A | `.legal .caps-link` misses the 44px list — live rule-9 defect | **Fix in this story.** One line |
| 7B | `/feed`'s aside credits one museum for a four-collection pool | **Log as TODO.** Different component, needs its own copy decision |

## Interaction states

What the reader SEES. Not backend behaviour.

| Surface | Loading | Empty | Error | Success | Partial |
|---|---|---|---|---|---|
| Corner oculus | none — static markup in the cached page | n/a | n/a | n/a | on `/you`: unlinked, `--ink-dim`, `aria-current` |
| Coda word (`/` only) | none — static | n/a | n/a | n/a | n/a |
| `/you` account | full page, no frame | n/a | n/a | provider + email, Sign out, Delete account | n/a |
| `/you` device, N>0 | full page | n/a | n/a | claim sentence naming N, two doors, delete | n/a |
| `/you` device, N=0 | full page | **"Nothing is kept on this phone yet. Sign in and what you keep will belong to your account, not to this phone."** | n/a | two doors, delete | n/a |
| `/you` signed-out web | full page | n/a | n/a | what signing in opens, two doors | 3 of 4 compass doors unlinked |
| Auth sheet | system sheet over `/you` | n/a | **cancelled → back on `/you`, nothing changed, no error screen** | handoff → `/collection` if works moved, else `/you` | expired/replayed handoff → `/you`, one quiet line, still the device |
| `/collection` empty, never claimed | — | today's copy, unchanged | — | — | — |
| `/collection` empty, `claimed_at` set | — | **"Your kept works are with your account. Sign in and they come back."** | — | — | — |
| Confirms (×3) | — | — | — | capped string, consequence in the first clause | Cancel/OK is all iOS gives; verified on device |

## User journey — the claim arc

| Step | User does | User feels | Plan specifies |
|---|---|---|---|
| 1 | Opens `/you` on the phone, 12 kept | curious, mildly protective | threshold sentence names 12 and the consequence, at display size |
| 2 | Taps Continue with Google | committed, slightly exposed | Safari-backed sheet, no login gate before this point, ever |
| 3 | Sheet closes | **anxious — did it work?** | **lands on `/collection`, 12 works on screen** (D9) |
| 4 | Weeks later, taps Sign out | routine | confirm names where the works go and that nothing is deleted (D7) |
| 5 | Opens Kept | **alarmed — they're gone** | **third empty variant answers it on the screen showing the alarm** (D8) |
| 6 | Signs back in | relieved | works return; the claim was a move, not a delete |

Steps 3 and 5 were both unspecified before this review. They are the two moments
the whole persona-6 copy effort exists for, and neither was on a screen.

## NOT in scope — considered and deferred

- **`/feed` aside staleness** — different component, needs its own copy decision (7B).
- **Re-subsetting the fonts for `→`** — story 0009's byte-identical property is worth more than one glyph, two weeks from the kill review (5B).
- **iOS Display Zoom / 320px** — `application_system_test_case.rb:17` already declares 375 the floor in writing. Not reopened here.
- **Native confirm dialogs via a bridge** — real improvement, but a second bridge component and two confirm systems for a control used twice a year (2C).
- **The ledger layout** — deferred at mock stage; revisit when push settings and curation preferences give the page facts worth tabulating.
- **Motion** — none specified, none needed. The product has no motion vocabulary and this is not the story to start one.

## What already exists — reuse, do not invent

`.coda` / `.coda__line` / `.coda__note` · `.caps-link` · `.signin` + `.signin__door` +
`.signin__mark` · `.account__delete` + `.account__form` · `.ornament` · `.legal` ·
`.page--empty` · `.masthead` grid + `.masthead__aside` · the `.rail__act` glyph
contract (23px box, 1.4px stroke, `--gold`, 44px target) · `compass_destinations`
and its raise-on-unknown-key contract · both delete-confirm strings verbatim from
`favorites/index.html.erb:58` and `:71`.

## Implementation Tasks

Synthesized from this review's findings. Each derives from a specific finding above.

- [ ] **T1 (P1, human: ~1h / CC: ~10min)** — masthead — Add the `you` grid area with `label` spanning two columns
  - Surfaced by: Pass 6 — the one-column version drops label 198→134px, wraps the title, costs +20px against 9px of fold
  - Files: `app/assets/stylesheets/application.css`, `app/views/shared/_masthead.html.erb`
  - Verify: `bin/rails test test/system/dynamic_type_test.rb`
- [ ] **T2 (P1, human: ~45min / CC: ~10min)** — compass — Give `/you` `here: nil` and unlink walled doors on that page only
  - Surfaced by: Pass 1 issue 1A + prior learning `compass-raises-on-unknown-key`
  - Files: `app/helpers/application_helper.rb`, `app/views/shared/_compass.html.erb`, `app/controllers/corners_controller.rb`
  - Verify: render-level test; must NOT vary the compass on `/` (story 0007)
- [ ] **T3 (P1, human: ~2h / CC: ~20min)** — corners — Third empty-collection variant + `devices.claimed_at`
  - Surfaced by: Pass 3 issue 3A — the post-sign-out empty state is persona 6 built to spec
  - Files: `db/migrate/*_add_claimed_at_to_devices.rb`, `app/models/favorite.rb`, `app/views/favorites/index.html.erb`
  - Verify: claim → sign out → `/collection` names where the works went
- [ ] **T4 (P1, human: ~30min / CC: ~5min)** — sessions — Land on `/collection` when the claim moved works, `/you` otherwise
  - Surfaced by: Pass 3 issue 3B — the irreversible action had no receipt
  - Files: `app/controllers/sessions_controller.rb`
  - Verify: integration test asserting both redirect targets
- [ ] **T5 (P1, human: ~20min / CC: ~5min)** — sessions — Delete `sessions#control`, its route, the `signin` frame and the `/#signin` anchor
  - Surfaced by: Pass 7 — the plan contradicted itself in three places; decision 5 governs
  - Files: `app/views/sessions/_control.html.erb`, `app/controllers/sessions_controller.rb`, `config/routes.rb`, `app/views/daily/_day.html.erb`
  - Verify: `test/integration/public_cache_headers_test.rb` — `/` still byte-identical, no `Set-Cookie`
- [ ] **T6 (P2, human: ~30min / CC: ~5min)** — DESIGN.md — Three amendments
  - Surfaced by: Pass 5 issue 5A + the dead rule-6 clause
  - Files: `DESIGN.md`
  - Verify: read it back — the gilt-tile ban survives, outline glyphs are named, `.masthead__you` is in the component list, rule 6's "never share a screen with the ✦" is widened (already false at `_day.html.erb:76` + `:174`)
- [ ] **T7 (P2, human: ~20min / CC: ~5min)** — a11y — Exempt same-`href` links from the duplicate-name rule, with the reason in the test
  - Surfaced by: Pass 6 issue 6A
  - Files: `test/integration/daily_test.rb`
  - Verify: the suite still fails on two same-named buttons
- [ ] **T8 (P2, human: ~5min / CC: ~2min)** — a11y — Add `.legal .caps-link` to the 44px selector list
  - Surfaced by: Pass 7 issue 7A — live rule-9 defect on an App-Review-required nav
  - Files: `app/assets/stylesheets/application.css` (the list at ~724-730)
  - Verify: system test measuring the two legal links
- [ ] **T9 (P2, human: ~1h / CC: ~15min)** — corners — Zero-keeps device copy + capped confirm strings
  - Surfaced by: Pass 2 issues 2B and 2C
  - Files: `app/views/corners/show.html.erb`, `app/views/favorites/index.html.erb`
  - Verify: `/you` on a device with 0 kept works reads as an invitation, not a warning
- [ ] **T10 (P2, human: ~30min / CC: manual)** — verification — Simulator screenshots: masthead at 3 Dynamic Type sizes, all 3 confirms
  - Surfaced by: Pass 6 issue 6B — every number in this plan came from the wrong engine
  - Files: none — a gate, not a change
  - Verify: compass stays one row; fold clearance holds; no confirm truncates

---

# Engineering review — 2026-08-17

Reviewed: this file. Four sections plus an outside voice. **10 issues, all resolved.**
Mode: SCOPE_REDUCED — the plan is split into two releases on the App Store line.
Codex was rate-limited (`usage limit... try again Sep 9`), so the outside voice
ran as an independent Claude subagent with fresh context. It found seven things
both prior reviews missed; six were verified against the repo and folded.

## Release split

Step 0's complexity check triggered: ~24 files, 5 new classes, against a
threshold of 8 files / 2 classes. The plan also never named the App Store review
that Phase 3's `CFBundleURLTypes` addition requires. Split on that line, then
corrected by architecture issue 3 — the claim cannot execute in a web-only
release, because `device_registrations_controller.rb:42-46` is the only code
that mints a device cookie and `ios/Tondo/DeviceIdentity.swift:71-80` is its
only caller.

```
RELEASE 1 — pure Rails, no App Store queue, bin/ci covers all of it
  /you surface, three states (device state: NO sign-in doors)
  oculus on 8 masthead sites  ·  "Your corner" caps-link on / only
  compass here:nil on /you  ·  walled doors unlinked on /you ONLY
  require_reader bounce → corner_path
  DELETE sessions#control + route + signin frame + /#signin anchor
  sign-out + both delete doors → /you; labelled signpost stays on /collection
  reader_favorites promoted to ApplicationController
  .legal .caps-link 44px  ·  DESIGN.md amendments  ·  wall diagram updated
  sign_in_as_reader repointed at /you

RELEASE 2 — native, gated on the Phase 0 spike and its own submission
  ASWebAuthenticationSession + handoff (generates_token_for, not a table)
  Favorite.claim! + devices.claimed_at + third empty-collection variant
  post-claim redirect  ·  sign-in doors turn on in /you's device state
```

## Findings

| # | Section | Finding | Decision |
|---|---|---|---|
| 1 | Arch | `/you` renders inside WKWebView; without the transport a provider tap returns Google's `403 disallowed_useragent` | **Carry the `native_shell? \|\| current_device` guard onto `/you`** in Release 1. Doors ship in Release 2 |
| 2 | Arch | `Favorite.claim!` specified as behaviour, not statements; the partial unique index rejects colliding updates | **One transaction, two statements**: delete colliding device rows, then bulk update. O(2) regardless of collection size |
| 3 | Arch | The claim cannot execute in a web-only release — only the shell mints a device cookie | **Move the whole claim into Release 2.** Building it in Release 1 is infrastructure for later |
| 4 | Arch | `handoff_tokens` table chosen for a reason aimed at `MessageVerifier` + a cache, which is not what is used | **`generates_token_for` + a counter column.** Rails 8.1.3.1, unused here, built for exactly this |
| 5 | Arch | Plan spends the product's first bridge component; a route decision handler pattern already ships | **Phase 0 spike decides**, route handler as the default (`CLAUDE.md`: bridge components only where genuinely required) |
| 6 | Quality | `/you`'s delete confirms need the same identity-to-rows query private to `FavoritesController` at `:126-132` | **Promote `reader_favorites` and `reader_identity_attributes` to `ApplicationController`**, beside the identity readers |
| 7 | Tests | Nothing asserts `/` renders the same bytes for every reader; the oculus is the first identity-adjacent element on the cached page | **Assert byte-identical body across anonymous / device / signed-in** |
| 8 | Outside | `application_system_test_case.rb:76-88` signs in by visiting `#signin` and clicking a button Release 1 deletes; `behind_the_wall!` has 7+ callers | **Repoint `sign_in_as_reader` at `/you`** — two lines, preserves the helper's stated intent |
| 9 | Outside | Release 1 removes the majority iOS reader's labelled delete door and replaces the route with a wordless ring | **Doors live on `/you`; a labelled signpost stays in the `/collection` footer.** One destructive control, one confirm string |
| 10 | Outside | Seven verified corrections (below) | **Apply all seven** |

## Corrections applied (issue 10)

1. **`privacy_claims_test.rb` does not do what this plan claimed.** Its three
   tests (`:40`, `:49`, `:68`) cover an analytics-claim string, a lockfile gem
   scan and the `POLICY_UPDATED_ON` stamp. **None touches a route.** It did not
   catch the 0016 defect. The named ship blocker had no forcing function at all
   — an R1 violation, written by this plan. The extension must be authored:
   assert the deletion path the policy names resolves and answers.
2. **The policy copy must move.** `privacy.html.erb:61` and `:65`, and
   `support.html.erb:32`, all read "open your collection." With issue 9's
   signpost that stays partly true, but each needs the extra step named.
3. **The oculus must be pure view logic.** `privacy.html.erb:8` and
   `support.html.erb:5` render the masthead, and `PagesController` inherits
   `ActionController::Base` — no `current_user`, no `current_device`, no
   `native_shell?`. A helper call in the oculus **500s the two pages App Review
   fetches.** Use `request.path` / `current_page?`, never a controller helper.
4. **`application_controller.rb:121-122` is false.** It says the shell appends
   `Tondo iOS/<version>`; `ios/Tondo/AppDelegate.swift:26` sets
   `applicationUserAgentPrefix = "Tondo iOS;"` with no version. The version
   exists only on `DeviceIdentity`'s URLSession header. Consequence for Release
   2: there is **no server-side lever** to gate the sign-in doors by shell
   version, so a binary built before the transport that loads a Release 2
   `/you` would render doors with nothing behind them. The spike decides
   whether to add a version to the prefix.
5. **The fourth `/you` state is unspecified**: native shell, no device cookie
   (registration failed or in flight). As an empty frame that was safe; as a
   full page it must say something true, and its delete button reaches
   `devices_controller.rb:20-21`, which silently redirects when `current_device`
   is nil.
6. **Measure, do not assert.** Two numbers in this plan were eyeballed: the coda
   "one row, two caps-links" claim, and the masthead cost table. `application.css:243`
   sets `align-items: baseline` on `.masthead`, and a 44px flex box spanning two
   rows has no text baseline — a plausible mechanism for the table being wrong.
   Measure both before T1, not after.
7. **Comment the SQLite dependency at the `claim!` call site.**
   `db/schema.rb:66`'s `collector_digest` unique index is **non-partial**,
   unlike its `user_id` sibling at `:68`. Bulk-nulling `collector_digest` works
   only because SQLite treats NULLs as distinct in a unique index. That is
   load-bearing against `CLAUDE.md`'s "Postgres only with a written reason."

## Failure modes

| Codepath | Realistic production failure | Test? | Error handling? | Silent? |
|---|---|---|---|---|
| `/you` in an unregistered shell | renders device copy naming a device that has no row; delete silently redirects | **no** | partial | **yes — critical gap until issue 10.5 lands** |
| oculus on `/privacy` `/support` | helper call raises `NoMethodError` → 500 on App Review's fetch | **no** | none | no, but it is a rejection |
| `/` byte-identity | a future per-visitor change poisons the Thruster cache | **issue 7 adds it** | none | **yes** |
| compass `here:` on `/you` | `ArgumentError` from `compass_destinations` — raised in the view | **no** | none | no |
| `Favorite.claim!` | retried handoff hits the unique index mid-loop, half-moving a one-way operation | **issue 2 closes it** | transaction | no |
| handoff token | replay inside the TTL via URL-scheme hijack | needed | single-use | no |

**Two critical gaps**, both now assigned: the unregistered-shell page and the
`/` byte-identity assertion.

## Parallelization

| Step | Modules touched | Depends on |
|---|---|---|
| Surface | `app/controllers/`, `app/views/corners/`, `app/views/shared/`, `app/assets/stylesheets/` | — |
| Deletions | `app/views/sessions/`, `app/views/daily/`, `config/routes.rb` | Surface (bounce target must exist) |
| Copy + docs | `app/views/pages/`, `DESIGN.md` | — |
| Test migration | `test/` | Surface, Deletions |
| Release 2 native | `ios/Tondo/`, `app/models/`, `app/controllers/sessions_controller.rb` | Release 1 shipped + spike |

```
Lane A: Surface → Deletions → Test migration   (sequential, shared views/ and routes)
Lane B: Copy + docs                            (independent — pages/ and DESIGN.md)
Lane C: Release 2 native                       (waits on Lane A shipping + the spike)

Launch A + B in parallel. Merge both. Then C.
```

**Conflict flag:** Lane A and Lane C both touch `app/controllers/sessions_controller.rb`.
Lane C waits anyway, so this is ordering rather than a merge risk.

## NOT in scope — added by this review

- **Submitting the binary and specifying the daily publish job.** The outside voice
  showed `SHIPLOG.md:71` says "not submitted: no upload, no review", `BET.md`'s
  live-by date of Aug 14 is three days past, and the publish job that advances
  `DailyPick.current` has no spec. Both outrank this story against every threshold.
  Put to the owner as D11 on 2026-08-17; **owner chose to proceed with both releases
  as planned.** Recorded, not re-argued.
- **`support@dailytondo.com` receiving no mail** while two live pages promise
  deletion requests to it (`SHIPLOG.md:94`). Curator-side, outside this plan.
- **Adding a version to `applicationUserAgentPrefix`.** Deferred to the Phase 0
  spike, which is the only place it can be verified.
- **Re-cutting the fonts for `→`**, `/feed`'s stale aside, iOS Display Zoom —
  all carried forward from the design review.

## What already exists — reuse, do not rebuild

`DeviceIdentity.swift:96-103` **already** copies a `Set-Cookie` from a native
`URLSession` response into `WKWebsiteDataStore.default().httpCookieStore` — the
hard-sounding half of the handoff, shipping today. `LinenSafariRouteDecisionHandler.swift`
is a working `RouteDecisionHandler` registered through `Hotwire.registerRouteDecisionHandlers`.
`favorites_controller.rb:126-132` owns the identity-to-rows query. `Device.digest`
is the digest-at-rest idiom. `sessions_test.rb:127` already exercises
`ApplicationController::NATIVE_UA_TOKEN`, so the shell-guard test pattern exists
and only moves. `filter_parameter_logging.rb:7` already filters `:token`.

## Implementation Tasks — engineering review

- [ ] **E1 (P1, human: ~15min / CC: ~3min)** — corners — Suppress sign-in doors on `/you` for `native_shell? || current_device` in Release 1
  - Surfaced by: Arch issue 1 — a provider tap in the shell returns Google's 403 page
  - Files: `app/controllers/corners_controller.rb`, `app/views/corners/show.html.erb`
  - Verify: request `/you` with `ApplicationController::NATIVE_UA_TOKEN` and no cookie
- [ ] **E2 (P1, human: ~45min / CC: ~10min)** — favorite — `Favorite.claim!` as one transaction: delete collisions, then bulk update *(Release 2)*
  - Surfaced by: Arch issue 2 — partial unique index rejects colliding updates
  - Files: `app/models/favorite.rb`
  - Verify: collision, retry, and 200-work collections each cost two queries
- [ ] **E3 (P1, human: ~20min / CC: ~5min)** — release-plan — Move the claim, `claimed_at`, the empty variant and the post-claim redirect into Release 2
  - Surfaced by: Arch issue 3 — a browser never holds a device cookie
  - Files: `specs/0017-your-corner/plan.md`
  - Verify: every line of Release 1 is reachable by a real request
- [ ] **E4 (P2, human: ~30min / CC: ~8min)** — sessions — `generates_token_for` + counter column, not a `handoff_tokens` table *(Release 2)*
  - Surfaced by: Arch issue 4 — Rails 8.1.3.1 ships this
  - Files: `app/models/user.rb`, `app/controllers/sessions_controller.rb`
  - Verify: expiry and single-use both fail closed
- [ ] **E5 (P2, human: ~10min / CC: manual)** — ios — Spike decides bridge component vs route decision handler
  - Surfaced by: Arch issue 5 — `CLAUDE.md` permits bridges only where genuinely required
  - Files: `ios/Tondo/AppDelegate.swift`
  - Verify: the spike reports which mechanism carried the session
- [ ] **E6 (P2, human: ~20min / CC: ~5min)** — controllers — Promote `reader_favorites` / `reader_identity_attributes` to `ApplicationController`
  - Surfaced by: Quality issue 6 — `/you`'s confirms need the same query
  - Files: `app/controllers/application_controller.rb`, `app/controllers/favorites_controller.rb`
  - Verify: `/you`'s count and `/collection`'s list cannot disagree
- [ ] **E7 (P2, human: ~10min / CC: ~3min)** — docs — Update the wall ASCII diagram; add the handoff leg in Release 2
  - Surfaced by: your standing rule that diagram maintenance is part of the change
  - Files: `app/controllers/application_controller.rb:29-37`, `app/controllers/sessions_controller.rb:4-16`
  - Verify: read it back against the routes
- [ ] **E8 (P1, human: ~45min / CC: ~10min)** — tests — Assert `/` is byte-identical across three identity states
  - Surfaced by: Test issue 7 — existing guards catch mechanisms, not markup
  - Files: `test/integration/public_cache_headers_test.rb`
  - Verify: mutate the oculus per-visitor and watch it go red
- [ ] **E9 (P1, human: ~1h / CC: ~15min)** — tests — Repoint `sign_in_as_reader` at `/you`; migrate `wall_test` and `sessions_test`
  - Surfaced by: Outside voice issue 8 — `behind_the_wall!` has 7+ callers
  - Files: `test/application_system_test_case.rb`, `test/test_helper.rb`, `test/integration/wall_test.rb`, `test/integration/sessions_test.rb`
  - Verify: `bin/ci` green
- [ ] **E10 (P1, human: ~1h / CC: ~15min)** — tests — New `corners_test.rb`: three states, unwalled 200, no-store, unregistered shell
  - Surfaced by: Test review — the unregistered shell is the case that historically leaked buttons
  - Files: `test/integration/corners_test.rb`
  - Verify: UA without cookie renders no doors
- [ ] **E11 (P1, human: ~45min / CC: ~10min)** — tests — Author the deletion-path assertion `privacy_claims_test.rb` never had
  - Surfaced by: Correction 10.1 — the named ship blocker had no forcing function
  - Files: `test/integration/privacy_claims_test.rb`
  - Verify: it fails when the policy names a path that does not resolve
- [ ] **E12 (P1, human: ~20min / CC: ~5min)** — pages — Move the deletion copy and keep the oculus free of controller helpers
  - Surfaced by: Corrections 10.2 and 10.3 — `PagesController` inherits `ActionController::Base`
  - Files: `app/views/pages/privacy.html.erb`, `app/views/pages/support.html.erb`, `app/views/shared/_masthead.html.erb`
  - Verify: `/privacy` and `/support` still answer 200 anonymously
- [ ] **E13 (P2, human: ~30min / CC: ~8min)** — corners — Specify the unregistered-shell state and its delete button
  - Surfaced by: Correction 10.5 — `devices_controller.rb:20-21` silently redirects when `current_device` is nil
  - Files: `app/views/corners/show.html.erb`, `app/controllers/devices_controller.rb`
  - Verify: shell UA, no cookie — the page says something true and the button does something visible
- [ ] **E14 (P2, human: ~30min / CC: manual)** — measurement — Measure the coda row and the `align-items: baseline` effect before T1
  - Surfaced by: Correction 10.6 — both numbers were asserted, not measured
  - Files: none — a gate
  - Verify: numbers replace the eyeballed claims in this plan


## Implement-time notes — Release 1, 2026-08-17

Built and green: `bin/ci` 318 runs / 1673 assertions integration, 48 / 293
system, 0 failures. Baseline before the story was 308 / 1614 and 47 / 267.

**Measured, replacing two asserted numbers (E14).** At 375px:

| root | masthead | compass rows | coda rows | corner box |
|---|---|---|---|---|
| 16.0 | 105.78 | 1 | 2 | 44×44 |
| 19.2 | 109.14 | 1 | 2 | 44×44 |
| 20.0 | 112.00 | 1 | 2 | 44×44 |

The cost table above was **right to the pixel**. The coda claim was **wrong**:
"one row, two caps-links" is two rows at every text size. Accepted rather than
fixed — the coda sits below the artwork and the wall label, so a second row
there costs no fold budget, and two centred caps-links stack cleanly. The
`align-items: baseline` concern (correction 10.6) did not materialise. Both
numbers are now pinned by a new assertion in `dynamic_type_test.rb`.

**Three things the build found that no review did.**

1. **The keep frame's bounce worked by accident.** The frame on `/` is eager;
   its GET bounced 303, and Turbo followed it to `/`, which happens to carry a
   matching `keep_<id>` frame, so it swapped in that page's identical
   placeholder. Retarget the bounce to `/you` — no such frame — and Turbo writes
   "Content missing" over the resting keep mark. Fixed by unwalling
   `favorites#control` and answering the null state directly, which is
   byte-identical to what the cached page already draws. `wall_test.rb` now
   asserts both halves separately. A 204 was tried first and does not preserve
   the frame.
2. **`dynamic_type_test` was vacuous on its second route**, and had been since
   story 0015 walled the archive. It loops `[root_path, day_path(...)]`
   unauthenticated; `/days/:date` bounced to `/`, which renders the same partial
   and satisfies every selector. It measured the front door twice. Adding
   `behind_the_wall!` took it from 36 assertions to 78.
3. **`design_test` had the same bug**, comparing `/` against `/feed` while
   `/feed` bounced to `/`. Same fix. The wall retarget turned out to be a
   detector for tests that were silently measuring the bounce target.

**E8 was already satisfied.** `wall_test.rb:107-122` has asserted the front door
byte-identical across all three identity states since story 0015. Both this
review and the outside voice missed it. No new test written.

**Deviations from the plan, all noted here rather than silently:**

- `/you` has **four** states, not three. `:shell` — native user agent, no device
  row — is its own branch: it holds nothing, so it claims nothing and is offered
  no delete button, because `DevicesController#destroy` answers one with a
  silent redirect when `current_device` is nil. This is correction 10.5, built.
- `compass_destinations` gained `locked:` rather than a fourth tri-state value.
  `/you` is the only caller and the helper raises on unknown keys in that list
  too.
- The oculus is inline in `_masthead` via `shared/_oculus`, not a
  `_account_glyph` partial; one caller, one name.
- No new control classes. `.signin__out` and `.account__delete` already carried
  the exact treatment, so `/you` reuses them; only `.corner__consequence` and
  `.coda__doors`/`.corner__doors` are new.
- `identified?` was added to `ApplicationController` alongside the promoted
  `reader_favorites`, because `CornersController` and now `favorites#control`
  can both reach it with neither key.

**Not yet done in Release 1:** nothing. Release 2 is unstarted by design.

## GSTACK REVIEW REPORT

| Review | Trigger | Why | Runs | Status | Findings |
|--------|---------|-----|------|--------|----------|
| CEO Review | `/plan-ceo-review` | Scope & strategy | 0 | — | — |
| Codex Review | `/codex review` | Independent 2nd opinion | 5 | ISSUES_FOUND (2026-08-17) | outside voice ran as Claude subagent; Codex rate-limited |
| Eng Review | `/plan-eng-review` | Architecture & tests (required) | 5 | CLEAR (PLAN, 2026-08-17) | 10 issues, 2 critical gaps, mode SCOPE_REDUCED |
| Design Review | `/plan-design-review` | UI/UX gaps | 4 | CLEAR (FULL, 2026-08-17) | score: 5/10 → 9/10, 13 decisions |
| DX Review | `/plan-devex-review` | Developer experience gaps | 0 | — | — |

**CODEX:** unavailable — `codex exec` returned `You've hit your usage limit... try again at Sep 9th`. The outside voice ran as an independent Claude subagent with fresh context instead. It produced seven findings neither prior review had; six were verified against the repo and folded, one (the coda row arithmetic) was found muddled and downgraded to "measure it."

**CROSS-MODEL:** the outside voice and this review agreed on the release split and on every folded finding. They diverged on sequencing: this review treated shipping 0017 as given, while the outside voice argued the story should not be in flight at all with the binary unsubmitted (`SHIPLOG.md:71`), `BET.md`'s Aug 14 live-by date three days past, and the daily publish job unspecified. Put to the owner as D11; **owner chose to proceed with both releases as planned.** Recorded, not re-argued.

**VERDICT:** ENG + DESIGN CLEARED — 10 issues folded, 0 unresolved, 2 critical gaps both assigned (E10, E8). Ready to implement Release 1.

NO UNRESOLVED DECISIONS
