# 0015 — Implementation plan
Status: **Design-reviewed** (`/plan-design-review` 2026-08-14 — triage scope by owner
choice: the bounce, the buttons, signed-in wayfinding; decisions D3–D5 written into the
sections below). Awaiting `/plan-eng-review`.

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

`omniauth`, `omniauth-google-oauth2`, `omniauth-apple`,
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

Device lookup hits the DB once per request. Fine at this scale; `last_seen_at` is
touched at most once a day per device (guarded update, not every request).

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

## Device registration

```ruby
class DeviceRegistrationsController < ApplicationController
  skip_before_action :require_reader
  skip_forgery_protection          # native URLSession caller, no DOM, no session
  rate_limit to: 10, within: 1.minute   # Rails 8 built-in

  def create
    head :unauthorized and return unless valid_app_secret?
    uuid = params.require(:device_token)
    Device.find_or_create_by!(token_digest: Digest::SHA256.hexdigest(uuid))
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
dependent: :delete_all`), `reset_session`, redirect to `/`. No
soft delete, no grace period, no email: there is no mailer and nothing to mail.

## iOS shell

New file `DeviceIdentity.swift`:
- `token`: read Keychain (`kSecClassGenericPassword`, service = bundle id); on miss,
  mint `UUID().uuidString`, store with `kSecAttrAccessibleAfterFirstUnlock` (survives
  reboot-locked background launches; stays device-only — no iCloud sync, that would
  quietly turn the device key into an account key).
- `register(then:)`: URLSession POST to `/device/registrations` with the token and the
  `X-Tondo-App` header; on 204, copy cookies from `HTTPCookieStorage` into
  `WKWebsiteDataStore.default().httpCookieStore`, then continue.

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

- **Wall**: every gated route, cookieless → redirect to `/`, no body leak. Device cookie
  passes. User session passes. Forged (unsigned) device cookie fails. Valid-signature
  cookie whose device row doesn't exist fails.
- **0007 contract**: `/` with no cookies, with a device cookie, and with a session —
  same ETag, no `Set-Cookie`, byte-identical body. This is the story's most important
  test.
- **Registration**: no secret → 401; wrong secret → 401; secret → device row + signed
  cookie; same UUID twice → one row; 11th request in a minute → 429.
- **Sessions**: OmniAuth test mode (`OmniAuth.config.test_mode`) for both providers;
  first Google sign-in creates user; second finds it; Apple first-auth stores name/email,
  later auth without them doesn't null them out; `reset_session` happens on create
  (fixation); failure path redirects home.
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

## GSTACK REVIEW REPORT

| Review | Trigger | Why | Runs | Status | Findings |
|--------|---------|-----|------|--------|----------|
| CEO Review | `/plan-ceo-review` | Scope & strategy | 0 | — | — |
| Codex Review | `/codex review` | Independent 2nd opinion | 0 | — | — |
| Eng Review | `/plan-eng-review` | Architecture & tests (required) | 0 | — | — |
| Design Review | `/plan-design-review` | UI/UX gaps | 1 | issues_open (triage scope) | score: 5/10 → 8/10, 3 decisions (D3 bounce → `/#signin`; D4 house buttons + official marks; D5 account controls placement) |
| DX Review | `/plan-devex-review` | Developer experience gaps | 0 | — | — |

Triage scope, owner-chosen: three named gaps reviewed and resolved; full 7-pass
sweep and mockups declined for speed. Deferred with rationale: in-place
"sign in to keep" rail state (declined at D3 — three fragment states, not
four); responsive/a11y pass beyond the 44px + stacking rules already specced;
mockups. Design-debt candidates live in the D3/D4 sections above.

**VERDICT:** DESIGN reviewed (triage). Eng review required before implementation.

NO UNRESOLVED DECISIONS
