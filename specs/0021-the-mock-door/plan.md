# 0021 — The mock door · implementation plan

Story: `specs/0021-the-mock-door/story.md`
Status: Implemented 2026-08-19. `bin/ci` green (rubocop, brakeman, bundler-audit, importmap
audit, 421 unit/integration + 49 system tests). `/plan-design-review` skipped — dev-only
tooling with no product surface, no UI significant per build flow step 3 (same reasoning
0009 used).

## Approach

Reuse the exact mechanism `test/test_helper.rb` already proves: flip
`OmniAuth.config.test_mode = true`, hand the middleware a fake `OmniAuth::AuthHash`, then
drive the **real** request-phase route (`POST /auth/:provider`) a reader's tap drives. The
callback still runs `SessionsController#create` unmodified — this story adds a second front
door, not a second way to sign in.

```
GET  /dev/sign_in ──────────► DevSessionsController#new
                                 renders provider/uid/email/name form

POST /dev/sign_in ──────────► DevSessionsController#create
                                 ├─ recognized provider?
                                 │    no  → redirect back, mock_auth untouched
                                 │    yes → OmniAuth.config.test_mode = true
                                 │          Rails.logger.warn (process-global flip)
                                 │          OmniAuth.config.mock_auth[provider] = AuthHash
                                 │          render shared/_auto_submit_auth_form
                                 ▼
                        (browser auto-submits, real Rails CSRF token in the body)
                                 ▼
POST /auth/:provider ───────► OmniAuth::Builder middleware (test_mode ⇒ returns the mock,
                                 skips the real provider network call)
                                 ▼
GET/POST /auth/:provider/callback ─► SessionsController#create — UNMODIFIED
                                 ├─ User.from_omniauth(auth)
                                 ├─ reset_session; session[:user_id] = user.id
                                 ▼
                              redirect_to days_path — reader is now signed in
```

One new controller (`DevSessionsController`), one route pair gated by a routing
**constraint** (not a boot-time `if`), one shared view partial. No gem, no change to
`SessionsController`, `User`, or `omniauth.rb`'s real provider config.

**Guard: a runtime config flag, checked by a routing constraint — not a boot-time `if`.**
The first draft gated `dev/sign_in` with `if Rails.env.development?` directly in
`config/routes.rb`. That guarantees the route can't exist outside development, but it also
means Minitest — which always boots in `test` — can never reach the route at all, so the
happy path (submit the form, land signed in at `/days`) would only ever be verified by
hand. Eng review flagged that against R1 (no artifact without its enforcement in the same
unit of work): the fix is a `Rails.application.config.x.dev_sign_in_enabled` flag —
`true` in `development.rb`, `false` in `test.rb` and `production.rb` — read by a routing
**constraint lambda** instead of an `if` around the route declaration. The route always
exists in the router; the constraint decides whether it resolves. That lets one dedicated
integration test flip the flag on for its own duration (same pattern as
`test_helper.rb`'s `with_forgery_protection`) and drive the real path end to end, while
every other test still gets the `false` default and 404s exactly like production does.

`test.rb`'s and `production.rb`'s `config.x.dev_sign_in_enabled = false` lines carry a
one-line comment pointing at `development.rb`'s `true` — the config, not a controller
`raise`, is still the single point of truth; the comment exists so a future edit doesn't
silently diverge the two sides without someone reading both.

## Steps

1. **Config flag** — `config.x.dev_sign_in_enabled`:
   - `config/environments/development.rb`: `config.x.dev_sign_in_enabled = true`
   - `config/environments/test.rb`: `config.x.dev_sign_in_enabled = false  # dev-only mock
     sign-in door (story 0021) — flip true only inside the one test that needs it, via
     Rails.application.config.x.dev_sign_in_enabled=`
   - `config/environments/production.rb`: same `false`, same comment.

2. **Route** — `config/routes.rb`, near the existing `auth/*` routes. The route is always
   drawn; the constraint decides whether it resolves, which is what makes it reachable from
   a test with the flag flipped on:
   ```ruby
   get  "dev/sign_in" => "dev_sessions#new",    as: :dev_sign_in,
     constraints: ->(_req) { Rails.application.config.x.dev_sign_in_enabled }
   post "dev/sign_in" => "dev_sessions#create", as: :dev_sign_in_submit,
     constraints: ->(_req) { Rails.application.config.x.dev_sign_in_enabled }
   ```

3. **`DevSessionsController`** — `skip_before_action :require_reader` (same reason
   `SessionsController` and `CornersController` skip it: this is how a reader with no
   identity gets one; walling it locks the door from the inside). Header comment carries
   the flow diagram from § Approach, matching the house style already on
   `SessionsController` and `CornersController`.
   - `#new` renders a form: provider select (`google_oauth2` / `apple`), and `uid`/
     `email`/`name` text fields pre-filled with sane defaults.
   - `#create` sets `OmniAuth.config.test_mode = true`, logs
     `Rails.logger.warn("OmniAuth.config.test_mode is now TRUE for this process — restart
     \`rails s\` to use real Google/Apple sign-in again.")` (Eng review Issue 2 — this is
     process-global state, so a dev who uses the door in the morning and demos a real
     provider later that day on the same running server gets mocked silently otherwise),
     builds the `AuthHash` via a class method (`self.build_auth_hash`, extracted so it is
     unit-testable with no router involved), writes it to
     `OmniAuth.config.mock_auth[provider.to_sym]`, then renders the shared self-submitting
     form (step 4) POSTing to `/auth/#{provider}`.
   - An unrecognized `provider` param redirects back to the form rather than setting
     anything or logging — mirrors `SessionsController#create`'s own "no auth hash, go
     home" guard for a misconfigured strategy.

4. **Views**
   - `app/views/dev_sessions/new.html.erb` — plain form, real layout (this is an
     internal tool page, not the auth sheet — no reason to strip chrome).
   - `app/views/shared/_auto_submit_auth_form.html.erb` — **new, extracted** (Eng review
     Issue 3). Takes the target URL as a local. The self-submit-to-OmniAuth idiom
     (`form_with url:, method: :post` + `<noscript>` button + one-line auto-submit script)
     existed once already in `sessions/start.html.erb`; a second hand-written copy for
     `dev_sessions/create.html.erb` would drift the moment either one's CSRF handling or
     markup changes. `sessions/start.html.erb` is refactored to render the partial instead
     of inlining the form — behavior unchanged, existing `handoff_test.rb`/`corners_test.rb`
     coverage of that page stays the regression check.
   - `app/views/dev_sessions/create.html.erb` — `layout: false`, renders the shared
     partial with `url: "/auth/#{@provider}"`.

5. **Provider list stays three separate copies** (Eng review Issue 4, considered and
   declined): `routes.rb`'s two `constraints: { provider: /google_oauth2|apple/ }` regexes
   and `DevSessionsController::PROVIDERS = %w[google_oauth2 apple]` are different shapes
   for different jobs (a routing `Regexp` vs. a form/validity `Array`) over a 2-item list
   that isn't expected to grow. Unifying them would be the premature abstraction CLAUDE.md
   names as a failure pattern, to save two lines.

6. **`OmniAuth.config.test_mode` stays a runtime flip inside `#create`, not a boot-time
   default.** Setting it unconditionally in `omniauth.rb` would silently mock a developer's
   real configured Google credentials the moment they clicked the real sign-in link.
   Flipping it only inside `DevSessionsController#create` means a dev server that never
   visits `/dev/sign_in` behaves exactly as it does today. Documented trade-off: once
   flipped, it stays flipped for the life of that server process (`OmniAuth.config` is
   process-global state) — a `rails s` restart resets it, and step 3's log line is the
   mitigation for the one realistic failure this causes.

## Files

| File | Change |
|---|---|
| `config/environments/development.rb` | `config.x.dev_sign_in_enabled = true` |
| `config/environments/test.rb` | `config.x.dev_sign_in_enabled = false` + comment |
| `config/environments/production.rb` | `config.x.dev_sign_in_enabled = false` + comment |
| `config/routes.rb` | new `dev/sign_in` GET/POST, constraint-gated (not boot-time `if`) |
| `app/controllers/dev_sessions_controller.rb` | new |
| `app/views/dev_sessions/new.html.erb` | new |
| `app/views/dev_sessions/create.html.erb` | new |
| `app/views/shared/_auto_submit_auth_form.html.erb` | new — extracted from `sessions/start.html.erb` |
| `app/views/sessions/start.html.erb` | refactored to render the shared partial; no behavior change |
| `test/controllers/dev_sessions_controller_test.rb` | new |
| `test/integration/dev_sign_in_routing_test.rb` | new |

## Tests (R1 — written with the code)

| Test | Pins |
|---|---|
| `test/integration/dev_sign_in_routing_test.rb` | with the flag at its `test.rb` default (`false`): `GET /dev/sign_in` and `POST /dev/sign_in` both raise `ActionController::RoutingError` — the route does not resolve outside development |
| `test/integration/dev_sign_in_routing_test.rb` | **the happy path, flag flipped on for the test's duration** (setup/teardown around `Rails.application.config.x.dev_sign_in_enabled`), **entirely inside one `with_forgery_protection` block** — both requests, not just the second. Outside-voice review (Codex was rate-limited; Claude subagent ran instead) traced Rails' own `token_tag` (`action_view/helpers/tags/... url_helper.rb`) and found it only emits the hidden `authenticity_token` field when `allow_forgery_protection` is true; the first draft of this test wrapped only the second POST, so the FIRST request — rendering `/dev/sign_in`'s form — would run with `test.rb:29`'s default (`false`) and never embed a token to extract at all. Corrected: `with_forgery_protection { post "/dev/sign_in", params: { provider: "google_oauth2" }; token = extract from body; post "/auth/google_oauth2", params: { authenticity_token: token } }`. **The wrap is load-bearing**, not decoration: this repo has already shipped one test that passed vacuously because of the same default (`forgery-protection-off-in-test-env`, `test/integration/sessions_test.rb`'s Apple CSRF test) — this story exists specifically to not repeat that. Assert redirected to `days_path`, `session[:user_id]` set, and `User.exists?(provider: "google_oauth2", uid: "dev-uid-1")` |
| `test/controllers/dev_sessions_controller_test.rb` | `DevSessionsController.build_auth_hash` returns an `OmniAuth::AuthHash` with the given provider/uid, `info.email`/`info.name` present when passed and absent (not blank-stringed) when not — called directly, no router involved |
| `test/controllers/dev_sessions_controller_test.rb` | an unrecognized `provider` param does not touch `OmniAuth.config.mock_auth` |
| `test/system/design_test.rb` or existing `sessions`/`handoff` coverage | unchanged expectations against `sessions/start.html.erb` after the partial extraction — this is the regression check for step 4's refactor |
| `test/integration/dev_sign_in_routing_test.rb` | `Rails.application.config.x.dev_sign_in_enabled` is `false` at the CURRENT env's default (asserted directly, no request) — closes the one critical gap the Failure Modes review flagged: `test.rb`'s and `production.rb`'s `false` defaults are otherwise enforced only by a comment, and a future edit that flips one by mistake would ship silently |

Every codepath the plan introduces now has automated coverage; nothing is
"manually verified only."

## NOT in scope

- Real Apple sign-in locally — permanently impossible (cross-site POST callback verified
  only on the deployed domain), unrelated to this story.
- The native/`ASWebAuthenticationSession` handoff flow (`/session/handoff`,
  `Favorite.claim!`) — the mock door drives only the plain web sign-in path
  (`SessionsController#create`). Considered as a follow-up TODO during eng review and
  explicitly declined — not captured, can be re-derived from scratch if it becomes a real
  blocker.
- Unifying the three separate provider-list copies (routes.rb ×2, `DevSessionsController`)
  — considered, declined as premature abstraction over a 2-item list (eng review Issue 4).
- Any CI/test-suite change — `test_helper.rb`'s `mock_auth` already covers automated tests;
  this tool is the human-driven equivalent for a browser.

## What already exists

- `test/test_helper.rb:16-88` (`OmniAuth.config.test_mode`, `mock_auth`) — the mechanism
  this story reuses rather than reinventing.
- `test/test_helper.rb:29-35` (`with_forgery_protection`) — reused by the happy-path test
  above rather than reinvented.
- `sessions/start.html.erb`'s self-submit-to-OmniAuth idiom — reused via extraction into
  `shared/_auto_submit_auth_form.html.erb` rather than copy-pasted.
- `application_system_test_case.rb`'s `sign_in_as_reader`/`behind_the_wall!` — unrelated
  and untouched. That harness drives the real UI sign-in frame for system tests directly
  via `mock_auth`, with no HTTP round-trip through OmniAuth's request phase; this story's
  door is a separate, human-facing tool for a running `rails s`, not a replacement for it.

## Deviations (added during build)

- **No `ActionController::TestCase` in this repo** — `rails-controller-testing` isn't in
  the Gemfile and `test/controllers/` was empty before this story. `DevSessionsController
  .build_auth_hash` is a plain class method with no request/controller instance involved,
  so `test/controllers/dev_sessions_controller_test.rb` is a plain `ActiveSupport::TestCase`
  calling it directly. The behavioral tests (routing, the bad-provider guard, the full
  sign-in path) all live in `test/integration/dev_sign_in_routing_test.rb`, where an actual
  request is the point anyway.
- **A routing miss is `assert_response :not_found`, not `assert_raises(RoutingError)`.**
  `config/application.rb` sets `config.exceptions_app = routes`, so a routing miss is
  rescued and rendered as a normal 404 response through this app's own `errors#not_found` —
  the same shape `sessions_test.rb` already pins for the constrained-out
  `auth/:provider/callback` route. Discovered by running the test as originally specified
  in this plan and watching it fail with "nothing was raised."
- **The happy-path test needs a THIRD leg, not two.** `SessionsController#create` carries
  `skip_forgery_protection only: :create` (Apple's real cross-site POST cannot carry a
  Rails CSRF token). `DevSessionsController#create` carries no such skip — same-origin form
  submission, no reason to need one — which means under `with_forgery_protection` it also
  requires a REAL token to accept the POST, not just to render one. The test now does
  `GET /dev/sign_in` first (extract its token) → `POST /dev/sign_in` with that token
  (extract the auto-submit form's token) → `POST /auth/:provider` with that second token.
  All three legs inside one `with_forgery_protection` block. This is stricter than "wrap
  both requests" (the outside-voice fix) and incidentally also proves
  `DevSessionsController#new`'s own form isn't CSRF-broken — a free bonus, not the point.
- **Manually verified against a real `rails s`, both providers** (2026-08-19): full round
  trip via curl with a cookie jar — `GET /dev/sign_in` → `POST /dev/sign_in` → auto-submit
  `POST /auth/google_oauth2` → lands at `/days`, `/you` shows "Google as dev@example.com",
  `/collection` returns 200, and the process-global warning line appears in
  `log/development.log`. Repeated for `apple` with blank email/name — lands at `/days`,
  `/you` shows bare "Apple" (no email), matching `User#signed_in_summary`'s fallback.
- **`/simplify` pass (4 parallel angles), one fix applied:** the two `constraints:` lambdas
  on the GET/POST route pair were identical and written twice — collapsed into one
  `constraints(->(_req) { ... }) do ... end` block wrapping both.
- **`/simplify` — two findings skipped, both flagged by 3 of 4 angles:**
  - The provider list is now three independent copies (`omniauth.rb`'s `provider
    :google_oauth2`/`:apple` DSL calls, `routes.rb`'s two regex constraints, and
    `DevSessionsController::PROVIDERS`). This is the same question eng review's Issue 4
    already put to you this session — different comparison point (the OmniAuth initializer
    instead of the routes.rb regex), same decision: a 2-item list not expected to grow,
    already explicitly declined once. Not re-litigated.
  - `DevSessionsController.build_auth_hash` and `test/test_helper.rb`'s `mock_auth`
    (`:82-88`) both build an `OmniAuth::AuthHash` from provider/uid/email/name, with
    already-drifted presence/compact rules. Real duplication, verified the fix would be
    behaviorally safe for every existing call site (checked: no test ever passes a blank
    string for uid/email/name, only real values or explicit `nil`) — but the fix means
    editing `test_helper.rb`, this project's suite-wide auth harness with 7+ callers across
    the whole suite. Disproportionate blast radius to bundle into a dev-only door's story.
    Left as a named future cleanup, not done here.
- **`/code-review` pass (10-angle, parallel-forked), one P0 and two real fixes applied:**
  - **P0 — the door was inert in a real browser.** `dev_sessions/new.html.erb`'s form had
    no `data: { turbo: false }`. Turbo Drive is pinned and imported globally
    (`config/importmap.rb`, the default layout); it intercepts non-GET form submissions and
    requires a redirect or turbo-stream response, and `#create`'s happy path renders a
    plain 200 ("Form responses must redirect to another location"). Neither the integration
    test (drives requests directly, no Turbo) nor this story's own curl-based manual
    verification (no JS engine) could have caught this — both bypass the exact mechanism
    that broke. **Added `test/system/dev_sign_in_test.rb`**, a real headless-Chrome click
    through `#new` → `#create` → `/auth/:provider` → `/days`; confirmed it fails red without
    the fix (temporarily reverted, re-ran, reverted the revert) before trusting it green.
  - **Reversed the Approach section's "no controller-level guard" call.** Code review's
    argument: this controller mints a real signed-in identity from attacker-chosen
    provider/uid/email through the genuine `SessionsController#create` path, and an
    identity-minting endpoint shouldn't depend on `config/routes.rb` staying correctly
    shaped forever (a bad merge, or a route added outside the `constraints do...end` block,
    would otherwise ship it live with nothing in the controller to stop it). Added
    `before_action :ensure_dev_sign_in_enabled!`, a one-boolean-read belt for the routing
    constraint's suspender. The original reasoning ("don't validate what can't happen")
    still holds for ordinary bugs; it doesn't hold for a control surface this sensitive.
  - **`DEFAULT_UID` constant** replaces the `"dev-uid-1"` string literal duplicated between
    `build_auth_hash`'s fallback and the form's pre-filled value.
  - **Noted, not fixed:** `OmniAuth.config.mock_auth`/`test_mode` are process-global
    (OmniAuth's own design), so two concurrent uses of the door for the same provider (two
    tabs, or a multi-worker Puma config) can race and sign one tab in as the other's
    identity. Same root cause and same acceptance as the `test_mode` flip's existing
    trade-off — single-developer local convenience, not shared state; closing it would add
    real complexity for a threat model that doesn't apply here. Now documented in the class
    comment alongside the `test_mode` note rather than only in this deviation entry.
