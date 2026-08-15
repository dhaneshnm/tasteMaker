# 0015 — Implementation plan
Status: **Built** 2026-08-14. Design-reviewed (triage, D3–D5), eng-reviewed (19
findings folded + Codex outside voice), implemented with tests as-you-go,
QA'd live, simplified (4 agents), code-reviewed (2 agents — including the
Apple-callback CSRF ship-blocker, fixed with regression coverage). Deviations
recorded below. Remaining: deployed-domain Apple verification + iOS device
smoke (ship checklist).

## Approach

Two identities, one wall, and a promise to keep: **the front door stays public,
byte-identical, and cookie-free** (story 0007's contract), while everything behind it
learns to ask who's there.

```
                        ┌─────────────────────────────┐
   iOS shell            │            Rails            │           Web browser
                        │                             │
   Keychain UUID ──────▶│ POST /device/registrations  │
   + app secret         │   → Device row              │
                        │   → Set-Cookie: device=     │◀────── GET /auth/google_oauth2
                        │     signed(uuid), permanent │        GET /auth/apple
                        │                             │          → User row
   every request ──────▶│  require_reader:            │          → session[:user_id]
   carries the cookie   │    user session?  pass      │
   automatically        │    device cookie? pass      │◀────── every request carries
                        │    neither?  → redirect "/" │        the session cookie
                        └─────────────────────────────┘
```

- **Device key** (app): a UUID minted once, kept in the Keychain, registered with the
  server, carried as a signed permanent cookie by every WKWebView request. Favorites for
  a device reuse the existing `collector_digest` scheme unchanged —
  `sha256(uuid)` is the digest.
- **Account key** (web): OmniAuth with Google and Apple, no passwords, `session[:user_id]`
  in the encrypted Rails session. Favorites for a user use a new nullable
  `favorites.user_id` — the exact column `specs/0006-favorites/plan.md` promised when
  accounts arrived.
- **The wall**: one `before_action` on `ApplicationController`, allowlist-exempted, that
  passes either key and bounces everything else to `/`.

## Load-bearing constraints

1. **`/` keeps story 0007's contract.** Public, `no-cache`, ETag'd, byte-identical for
   every caller, never a `Set-Cookie`. The sign-in buttons therefore cannot be rendered
   into the public HTML — they ride the established private-fragment pattern
   (`favorites#control` is the precedent): a lazy turbo-frame whose `src` is a private,
   `no-store` endpoint that renders sign-in buttons for nobody-yet, a "your collection"
   link for a signed-in reader, and **nothing at all for a device** — which is how the
   app never shows login UI without the shell knowing anything about auth.
2. **Gated pages lose `public`, keep their ETags.** `/days`, `/days/:date`, `/feed` are
   currently `public, no-cache`. Behind a wall, a shared cache holding their bodies is a
   risk we don't need to reason about on every future change: they move to
   `private, no-cache` (ETag revalidation still works per-browser; Thruster's shared
   cache no longer stores them). Accepted cost: gated pages lose shared-cache hits.
   Their entire audience is now authenticated readers and devices, so the cache was
   about to stop earning its keep anyway. `/` — the page strangers actually hit —
   remains publicly cached.
3. **The app must work on first launch, offline-tolerant, with zero auth UI.** The shell
   registers before its first navigation; if registration fails (airplane mode on first
   ever launch), the shell proceeds anyway and retries next launch — the reader sees art,
   and the wall's redirect target is `/`, which still shows today. Degraded, not broken.

## Schema

```ruby
create_table :users do |t|
  t.string :provider, null: false            # "google_oauth2" | "apple"
  t.string :uid,      null: false            # provider's stable subject id
  t.string :email                            # may be Apple's private relay
  t.string :name                             # Apple sends it once; capture or lose it
  t.timestamps
  t.index [ :provider, :uid ], unique: true
end

create_table :devices do |t|
  t.string :token_digest, null: false        # sha256(keychain uuid) — never the uuid
  t.datetime :last_seen_at
  t.timestamps
  t.index :token_digest, unique: true
end

add_column :favorites, :user_id, :bigint     # nullable — device favorites keep using
add_foreign_key :favorites, :users           #   collector_digest, untouched
add_index :favorites, [ :user_id, :painting_id ], unique: true,
  where: "user_id IS NOT NULL"
```

`Favorite` validity becomes: exactly one of `collector_digest` / `user_id` present.
`collector_digest` loses `presence: true`, gains the either/or validation. Devices store
only the digest of the UUID for the same reason `favorites` never stored the cookie
token: the table must not be a credential.

## Gems

`omniauth`, `omniauth-google-oauth2`, `omniauth-apple` (**exact-version pin** — see
the SameSite note under Sessions; upgrades re-verify on the deployed domain),
`omniauth-rails_csrf_protection` (non-negotiable companion — without it the request
phase is a CSRF hole; it forces POST + token to `/auth/:provider`).

Stack deviation (Rails 8 auth generator not used — it is password-shaped, this product
is OAuth-only) recorded in `decisions/0011-the-two-keys.md`.

## Routes

```ruby
# OmniAuth owns GET|POST /auth/:provider and the callback:
get  "/auth/:provider/callback" => "sessions#create"
get  "/auth/failure"            => "sessions#failure"   # declined consent → back to /
delete "session"  => "sessions#destroy", as: :session
delete "account"  => "accounts#destroy", as: :account

# The landing page's private fragment (favorites#control precedent):
get "session/control" => "sessions#control", as: :session_control

# The shell's registration endpoint:
post "device/registrations" => "device_registrations#create"
```

## The wall

```ruby
# ApplicationController
before_action :require_reader

private

def require_reader
  return if current_user || current_device_digest
  redirect_to root_path(anchor: "signin")
end

def current_user
  @current_user ||= User.find_by(id: session[:user_id]) if session[:user_id]
end

def current_device_digest
  return @current_device_digest if defined?(@current_device_digest)
  token = cookies.signed[:device]
  @current_device_digest = token.presence &&
    Device.exists?(token_digest: Digest::SHA256.hexdigest(token)) &&
    Digest::SHA256.hexdigest(token)
end
```

Skips: `daily#show` (the landing page), `errors`, `sessions`, `device_registrations`,
`rails/health`. `Admin::BaseController` skips it too — the curator's key is basic auth,
unchanged, and must not need a Google account to schedule tomorrow's pick.

**The redirect is `status: :see_other` (eng review Q3).** The wall bounces POSTs
too — a signed-out keep tap is a form POST — and Turbo follows a 302 from a POST
by re-issuing the method. 303 makes the follow-up a GET. One argument, one class
of bug gone.

**Active Storage is outside the wall, on purpose (eng review A3).**
`ActiveStorage::BaseController` does not inherit `ApplicationController`, so
image URLs never pass through `require_reader` — and must not: the landing page
shows today's artwork to everyone, signed out included. The protection images
actually have is that blob URLs are signed capability URLs — unguessable, but
sharable once known. Accepted and named here rather than discovered later; the
"every reader-facing endpoint" sentence in `story.md` reads with this exception.

Device lookup hits the DB once per request, memoized for the request. Fine at
this scale. `last_seen_at` is touched at most once a day per device, and with
`update_column` — no validations, no callbacks, no `updated_at` churn — guarded
by `last_seen_at.nil? || last_seen_at < 24.hours.ago` so SQLite doesn't take a
write per pageview (eng review P1).

`current_device_digest` as sketched above hashed twice and leaned on an `&&`
chain that returns `false` sometimes and a string otherwise. Implemented shape
(eng review Q1) — explicit over clever:

```ruby
# Memoizes the Device row, not just the digest (Codex): exists? + a later
# last_seen_at touch would be two queries. find_by is the same one indexed
# read and hands the row to whoever needs it.
def current_device
  return @current_device if defined?(@current_device)
  @current_device = begin
    token = cookies.signed[:device]
    Device.find_by(token_digest: Digest::SHA256.hexdigest(token)) if token.present?
  end
end

def current_device_digest = current_device&.token_digest
```

**The device cookie is a bearer credential, said plainly (Codex).** Signing
prevents forgery, not disclosure: a copied cookie impersonates that device until
its row is deleted. That row deletion *is* the revocation story (decision D2),
there is no expiry by design (permanence is the favorites promise), and the
cookie never appears in logs — `httponly`, and Rails filters cookie values from
request logging by default.

## Sessions controller

- `create`: `request.env["omniauth.auth"]` → `User.find_or_create_by!(provider:, uid:)`,
  capturing email/name when present (Apple sends them **only on first authorization** —
  losing them then is losing them forever, so the create path must persist them).
  `reset_session` first (session fixation), then `session[:user_id] = user.id`,
  redirect to `/days`.
- `failure`: redirect to `/` quietly. A declined OAuth consent is not an error page.
- `destroy`: `reset_session`, redirect to `/`.
- `control`: the private fragment. `no_store`, renders one of three states
  (signed-out web → two buttons; signed-in → collection link + sign out; device → empty).

  Two clarifications the outside voice earned (eng review, Codex):
  - **The fragment may `Set-Cookie`; the front door may not.** The OAuth buttons
    are POSTs and `omniauth-rails_csrf_protection` wants a real CSRF token, so
    rendering the fragment writes `session[:_csrf_token]` — a session cookie on
    the fragment response. That is the 0006 pattern exactly: private, `no-store`
    fragments are *where cookies are allowed to happen*; the 0007 contract is,
    and always was, about the public HTML responses. Stated here so nobody
    "fixes" the fragment's Set-Cookie into a bug report.
  - **An unregistered shell must not see web login UI.** If first-launch
    registration failed, the shell has no device cookie and would otherwise be
    served the signed-out state — Google buttons inside the app. The shell's
    WKWebView appends `Tondo iOS/<version>` to its user agent (one line,
    `applicationNameForUserAgent`); the fragment renders **empty** for that UA
    when no identity is present. The app degrades to art-plus-nothing, never to
    a login screen.

### The sign-in fragment's look (design review D4, 2026-08-14)

House buttons, official marks. Two buttons side by side inside the fragment
(stacked at narrow widths), each: `--bg-lift` field, `--hairline` border, the
2px radius DESIGN.md already grants form controls, `min-height: 44px` (rule 9),
label in Newsreader — "Continue with Google" / "Continue with Apple" — with the
provider's official mark at ~18px leading the label: Google's multicolor G,
Apple's mark in `--ink`. No bold, no third typeface, no pill.

Recognition lives in the logos, not the providers' button chrome; everything
else obeys the token table. **DESIGN.md gains two lines in the same commit
(R1):** a `.signin` component entry, and an accepted exception recording that
Google's G is the only non-token color in the product, confined to this
fragment. Both providers' web guidelines permit custom buttons carrying the
official mark; the exact current guideline pages get checked at implement time
and noted here if anything material changed.

Above the buttons, one quiet line of `--ink-faint` copy naming what the door
opens (see the bounce, below). Under them, nothing — no "or", no divider, no
account-benefits list.

### The bounce (design review D3, 2026-08-14)

`/` is cached and byte-identical, so its compass shows DAYS · KEPT · GALLERY to
signed-out web visitors, and the rail shows the keep glyph. Every gated tap —
compass, keep POST, deep link — redirects to **`/#signin`**: the URL fragment
never reaches the server (cache-safe), and the anchor lands the visitor at the
sign-in fragment. The fragment's signed-out copy therefore always explains what
the wall guards, not just how to get through it: sign in opens *past days, the
gallery, and a collection of your own*. The tap is answered one scroll-jump
away rather than silently swallowed. The `id="signin"` anchor lives on the
turbo-frame wrapper in the public HTML — static markup, identical for
everyone. Accepted cost, stated: a keep tap teleports to the anchor instead of
answering inside the rail; an in-place "sign in to keep" state was considered
and declined to keep the fragment's state machine at three states.

Apple specifics, named so they don't surprise at implement time: `omniauth-apple` needs
team id, key id, Services ID as client id, and the `.p8` private key — all five values
live in Rails credentials. Apple requires an **HTTPS return URL on a registered domain**,
so the Apple button is verified on the deployed domain; local dev exercises Google +
mocked Apple. The callback is a form POST from Apple's origin —
`omniauth-rails_csrf_protection` handles the request phase, and the callback controller
needs `protect_from_forgery` `null_session`-safe handling (the gem's documented setup).

**The SameSite trap, called before it fires (eng review A2).** Apple returns the
callback as a **cross-site POST**, and Rails session cookies default
`SameSite=Lax` — which browsers do not send on cross-site POSTs. So the OmniAuth
`state`/`nonce` written to the session at the request phase is *absent* at the
callback, and auth fails with the `nonce_mismatch`/CSRF errors that fill this
gem's issue tracker. Mitigation, decided now: OmniAuth's state for the Apple
strategy is carried in a **dedicated cookie scoped to `/auth`, marked
`SameSite=None; Secure`** — never by loosening the app session cookie, whose
`Lax` posture is part of the product's CSRF defense. The gem's maintenance is
spotty and forks circulate; **pin the exact version in the Gemfile** and treat
any upgrade as a change needing the deployed-domain re-test. The Apple flow is
verified end-to-end on the production domain before the story is called shipped
— a green local suite cannot exercise this failure. **Time-box, named up front
(Codex):** if the scoped-cookie state store fights OmniAuth's internals for more
than half a day, fall back to the community-documented workaround (the
maintained fork's nonce/state handling) rather than inventing strategy code —
and record which path shipped in the deviations section below.

## Device registration

```ruby
class DeviceRegistrationsController < ApplicationController
  skip_before_action :require_reader
  skip_forgery_protection          # native URLSession caller, no DOM, no session

  # Explicit store (eng review A1): the limiter is backed by the controller
  # cache store. Production's is the default in-process memory store
  # (config/environments/production.rb keeps the "durable alternative" line
  # commented out) and test's is :null_store — so without pinning, the limit
  # is per-process in prod and a silent no-op in every test. Per-process is
  # accepted on one box; a no-op test is not.
  RATE_LIMIT_STORE = ActiveSupport::Cache::MemoryStore.new
  rate_limit to: 10, within: 1.minute, store: RATE_LIMIT_STORE

  def create
    head :unauthorized and return unless valid_app_secret?
    uuid = params.require(:device_token)
    begin
      Device.find_or_create_by!(token_digest: Digest::SHA256.hexdigest(uuid))
    rescue ActiveRecord::RecordNotUnique
      # Two cold launches racing — same idempotent outcome, same idiom
      # favorites#create already uses (eng review Q2).
    end
    cookies.signed.permanent[:device] = { value: uuid, httponly: true,
                                          secure: Rails.env.production?,
                                          same_site: :lax }
    head :no_content
  end
end
```

`valid_app_secret?` compares (secure_compare) an `X-Tondo-App` header against a
credentials value. **Threat model, stated honestly (decision Q3a):** this secret ships
inside the IPA and is extractable by anyone who unpacks it. It stops open/anonymous
access — curl without effort, scrapers, accidental indexing — and does not stop a
determined attacker. The named upgrade path is App Attest verification on this same
endpoint; the endpoint's shape (register → cookie) would not change.

## Favorites: two keys, one controller

`collector_digest` resolution in `FavoritesController` becomes:

- `current_user` → rows keyed by `user_id`
- device cookie → rows keyed by `collector_digest = current_device_digest` (the
  existing scheme, digest now derived from the Keychain UUID instead of a minted
  browser token)
- neither → unreachable (the wall ran first), but fails to a redirect, not a 500.

The old mint-on-read browser cookie path (`mint_collector_token`) **is deleted**: on web
the identity is now the account, on the app it is the device cookie minted at
registration. Nothing is deployed and no reader exists (SHIPLOG: 0 live), so there is no
cookie-migration path to build — delete, don't deprecate.

Queries change from one scheme to two: `Favorite.collected_by(digest)` gains a sibling
`Favorite.owned_by(user)`, and `favorites#index` / `#control` pick by identity. The
unique-tap race handling (RecordNotUnique) stays exactly as is.

## Account deletion & signed-in wayfinding (design review D5, 2026-08-14)

The signed-in fragment state on `/` is one quiet line, not a panel: `Your
collection → · Sign out` — both `.caps-link`, 44px targets, no card, no
avatar, no email address on the front door. Sign out is a `button_to` (DELETE
`/session`) styled as the link.

Delete account lives at the foot of `/collection`, in the coda: one
`--ink-faint` line — "Signed in with Google as dhanesh@…" — followed by
`Delete account`, a `button_to` with `data-turbo-confirm` that names what it
destroys: *"Deletes your account and the N works you've kept. There is no
undo."* Rare controls belong in the reader's own room, not on every screen.

`accounts#destroy`: signed-in only, `destroy` the user (`has_many :favorites,
dependent: :delete_all` — skips callbacks on purpose; favorites have none today,
and if they ever grow any this line is the tripwire to revisit), `reset_session`,
redirect to `/`. No soft delete, no grace period, no email: there is no mailer
and nothing to mail.

Two user-model facts, named rather than implied (Codex):
- **One person, two providers = two accounts.** Uniqueness is `[provider, uid]`;
  no cross-provider linking by email — email-based linking is an account-takeover
  vector and stays out of scope. A reader who signs in with Google one day and
  Apple the next has two separate collections. Accepted for launch.
- **`email` may be nil or an Apple private-relay address, and may go stale.**
  It is display data, never identity. The collection coda's "Signed in with
  {provider}" line falls back to the provider name alone when email is absent.

## iOS shell

New file `DeviceIdentity.swift`:
- `token`: read Keychain (`kSecClassGenericPassword`, service = bundle id); on miss,
  mint `UUID().uuidString`, store with `kSecAttrAccessibleAfterFirstUnlock` (survives
  reboot-locked background launches; stays device-only — no iCloud sync, that would
  quietly turn the device key into an account key).
- `register(then:)`: URLSession POST to `/device/registrations` with the token and the
  `X-Tondo-App` header; on 204, copy cookies from `HTTPCookieStorage` into
  `WKWebsiteDataStore.default().httpCookieStore`, then continue. The request sets an
  explicit `User-Agent: Tondo iOS/<version>` — `allow_browser versions: :modern` on
  `ApplicationController` judges user agents, and the default CFNetwork string's fate
  under it is an implementation detail of Rails we refuse to depend on (eng review A4);
  an integration test pins the registration endpoint open to that UA.

`SceneDelegate` calls `register` before the first `route`; on failure it routes anyway
(constraint 3) and retries on next foreground. The app secret lives in a Swift constant —
extractable, accepted, see threat model above.

`path-configuration.json`: no new rules needed — the shell never navigates to `/auth/*`
because the session fragment renders empty for a device identity. A defensive rule
sending `/auth/*` to Safari anyway costs one line and removes a whole class of "how did
the app end up on Google's consent screen" bugs; add it.

## Caching & headers, the full table

| Path | Before | After |
|---|---|---|
| `/` | `public, no-cache`, ETag, no cookie | **unchanged** (story 0007 guard test extended: still no `Set-Cookie` with the fragment present) |
| `/days`, `/days/:date`, `/feed` | `public, no-cache`, ETag | `private, no-cache`, ETag (constraint 2) |
| `/collection*`, `session/control` | `no-store` (0006 pattern) | `no-store`, unchanged |
| `/auth/*`, `session`, `account`, `device/registrations` | — | `no-store` |

## Tests (Minitest, as-you-go — R1)

- **Wall**: every gated route, cookieless → redirect to `/#signin`, no body leak. Device
  cookie passes. User session passes. Forged (unsigned) device cookie fails.
  Valid-signature cookie whose device row doesn't exist fails. A cookieless POST
  (keep tap) redirects with **303**, not 302 (eng review Q3). The `id="signin"`
  anchor exists in the public HTML of `/`.
- **0007 contract**: `/` with no cookies, with a device cookie, and with a session —
  same ETag, no `Set-Cookie`, byte-identical body. This is the story's most important
  test.
- **Registration**: no secret → 401; wrong secret → 401; secret → device row + signed
  cookie; same UUID twice → one row (including the raced-create rescue path); 11th
  request in a minute → 429 — asserted against the pinned `RATE_LIMIT_STORE`, cleared
  in setup, because the test env's `:null_store` (`config/environments/test.rb:23`)
  makes an un-pinned limiter pass every test while limiting nothing (eng review A1);
  a `Tondo iOS/1 CFNetwork` user agent is accepted (eng review A4).
- **Sessions**: OmniAuth test mode (`OmniAuth.config.test_mode`) for both providers;
  first Google sign-in creates user; second finds it; Apple first-auth stores name/email,
  later auth without them doesn't null them out; `reset_session` happens on create —
  asserted by the session id actually changing across sign-in (fixation); failure path
  redirects home.
- **Images stay reachable**: today's artwork image URL on `/` returns 200 with no
  cookies — the Active Storage exception holds (eng review A3).
- **Admin stays basic-auth, not wall-bounced**: anonymous `/admin` returns 401
  with the `WWW-Authenticate` challenge, never a redirect to `/#signin` — pins
  the skip-order interaction between `require_reader` and `authenticate_curator`
  (Codex).
- **Unregistered shell sees no login UI**: `session/control` with a
  `Tondo iOS` user agent and no cookies renders the empty state.
- **Favorites**: user keeps/unkeeps via session; device keeps/unkeeps via cookie; the
  two never see each other's rows; either/or model validation.
- **Account deletion**: user + favorites gone, session reset, device rows untouched.
- **System test** (Capybara): the signed-out landing page shows sign-in inside the
  fragment; mocked Google sign-in → `/days` renders; sign out → `/days` redirects.
- **Shell**: `DeviceIdentity` token stability covered by a unit test target if the
  project has one; otherwise smoke-tested in the simulator and noted in QA.

## Ship checklist (beyond `bin/ci`)

- Google OAuth client (web) + Apple Services ID/key created; five Apple values + Google
  pair + registration secret in Rails credentials; Kamal secrets updated.
- Apple return URL registered for the production domain; Apple button verified there
  (cannot be verified locally — noted limitation).
- App Store privacy label: **Identifiers → User ID, linked to you, App Functionality**
  (the Keychain UUID). No tracking, no ATT prompt (nothing crosses apps/companies).
- SHIPLOG line with receipt (R7: this is an input metric and will be logged as one).

## Deviations noted during implementation
_(append here, per build flow step 2)_

- **Apple SameSite mitigation shipped as config-standard, not custom state
  store.** The scoped `/auth` cookie cannot be exercised anywhere but the
  deployed domain, so writing it blind would be untestable code. The pinned gem
  + standard config ship now; the ship-checklist deployed-domain verification
  decides whether the plan's scoped-cookie work (or the fork fallback) is
  needed. Time-box clause stands.
- **The defensive `/auth/*` → Safari path-configuration rule was dropped** —
  Hotwire Native's path configuration has no send-to-Safari property; adding
  one means custom route-handler code, which is more than the "one line" the
  plan priced. The fragment's user-agent guard covers the shell.
- **`private, no-cache` is expressed as `cache_control.replace(no_cache: true,
  extras: ["private"])`** — Rails' no_cache header branch honors `:public` and
  `:extras` but ignores `:private`.
- **QA finding (live, dev server): a cookieless keep POST answers 422, not the
  wall's 303** — CSRF runs first in dev/prod (the suite disables it). Not a
  leak: signed-out browsers never render a keep button, so that POST is curl.
  `wall_test` now asserts both halves explicitly.
- **The shell's UA already carried `Tondo iOS;`** (story 0008's
  `applicationUserAgentPrefix`), so the server-side guard needed no iOS change
  beyond the registration request's explicit header.
- **iOS Swift compiled visually only** — no simulator in this session; the
  device smoke (fresh install → art, reinstall → collection survives) is on
  the ship checklist next to the Apple-flow verification.

## GSTACK REVIEW REPORT

| Review | Trigger | Why | Runs | Status | Findings |
|--------|---------|-----|------|--------|----------|
| CEO Review | `/plan-ceo-review` | Scope & strategy | 0 | — | — |
| Codex Review | `/codex review` | Independent 2nd opinion | 1 | issues_found (outside voice) | 19 points: 11 folded into plan, 5 already-accepted risks, 2 scope re-litigations rejected (Step 0 committed), 1 speculative |
| Eng Review | `/plan-eng-review` | Architecture & tests (required) | 1 | clean | 19 issues, 0 critical gaps open — all folded into plan (rate-limit store pinned; Apple SameSite mitigation + time-boxed fallback; AS images named exception; 303 wall redirects; device row memoized; bearer-cookie truth stated; shell never sees login UI) |
| Design Review | `/plan-design-review` | UI/UX gaps | 1 | issues_open (triage scope) | score: 5/10 → 8/10, 3 decisions (D3 bounce → `/#signin`; D4 house buttons + official marks; D5 account controls placement) |
| DX Review | `/plan-devex-review` | Developer experience gaps | 0 | — | — |

**CROSS-MODEL:** Codex confirmed the two named accepted risks (embedded secret
extractable; Apple callback fragility) and added the unregistered-shell login-UI
hole and the fragment-CSRF-session clarification — both folded. Its two
simpler-path proposals (defer device identity; gate fewer endpoints) re-argue
scope the owner settled at story intake and at the Step 0 gate; rejected per the
commit-fully rule.

**VERDICT:** ENG CLEARED + DESIGN reviewed (triage) — ready to implement.

NO UNRESOLVED DECISIONS
