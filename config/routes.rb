Rails.application.routes.draw do
  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # The dead man's switch for story 0023's daily fill job — point an external
  # uptime monitor here. Deliberately not /up: that only proves the app
  # boots, not that the queue is actually being kept full.
  get "queue-health" => "queue_health#show", as: :queue_health

  # Where `config.exceptions_app` sends a rescued error. `via: :all` because the
  # request that failed could have been any verb. 422 shares the 404 page: a
  # rejected request is not a page either. 500 stays on its static file — see the
  # plan; an error page that depends on the layout can fail the same way the
  # request did.
  match "/404" => "errors#not_found", via: :all
  match "/422" => "errors#not_found", via: :all

  # The artwork of the day is the front door.
  root "daily#show"

  # The account key (story 0015). OmniAuth owns POST /auth/:provider; these are
  # the return legs. `via: [:get, :post]` because Apple sends its callback as a
  # cross-site POST — the plan's most-watched edge — while Google returns GET.
  # Constrained to the two real providers: an unregistered name passes the
  # OmniAuth middleware untouched (no auth hash) and used to 500 on demand —
  # an anonymous error-tracker flood. Now it is a plain 404 (code review F3).
  match "auth/:provider/callback" => "sessions#create", via: %i[get post],
    constraints: { provider: /google_oauth2|apple/ }
  # The auth sheet's entry and exit (story 0017 Release 2). Both GET, because
  # ASWebAuthenticationSession can only open a URL: `start` turns that into the
  # POST OmniAuth requires, and `handoff` spends the token that carries the
  # session back into the web view's cookie jar.
  #
  # Constrained to the two real providers for the same reason the callback is —
  # an unregistered name would otherwise render a form posting into middleware
  # that ignores it.
  get "auth/start/:provider" => "sessions#start", as: :auth_start,
    constraints: { provider: /google_oauth2|apple/ }
  get "session/handoff" => "sessions#handoff", as: :session_handoff

  get "auth/failure" => "sessions#failure"
  delete "session" => "sessions#destroy", as: :session

  # The dev-only mock sign-in door (story 0021). The route is always DRAWN —
  # the constraint decides whether it RESOLVES, checked at request time
  # against `config.x.dev_sign_in_enabled` (true only in development.rb).
  # A boot-time `if Rails.env.development?` around the route declaration
  # would guarantee the same production safety but make the route
  # permanently unreachable by Minitest, since routes load once at boot and
  # the suite always boots in `test`. The constraint form lets one test flip
  # the flag for its own duration and drive the real path.
  constraints(->(_req) { Rails.application.config.x.dev_sign_in_enabled }) do
    get  "dev/sign_in" => "dev_sessions#new",    as: :dev_sign_in
    post "dev/sign_in" => "dev_sessions#create", as: :dev_sign_in_submit
  end

  # The reader's own corner (story 0017) — the fifth surface, and the second
  # unwalled one after `/`. It holds the sign-in doors, so it cannot require an
  # identity: `require_reader` bounces every cookieless visitor here.
  #
  # The landing page's per-visitor fragment that used to live at
  # `/session/control` is gone with it. The corner glyph in the masthead and the
  # coda word on `/` are identical markup for every reader, so the landing page
  # needs no per-visitor fragment at all — which also takes a round trip off
  # every front-door render and removes the product's most delicate cache
  # hazard rather than adding to it.
  get "you" => "corners#show", as: :corner

  # The exit door the category's leader never built. Signed-in only.
  delete "account" => "accounts#destroy", as: :account

  # The same door for the other identity (story 0016). `accounts#destroy`
  # returns early unless `current_user`, so until this route existed the DEFAULT
  # state of every iOS reader — a registered device that never signed in — could
  # not delete anything it had left behind. A privacy policy promising in-app
  # deletion was false for the majority case, which is how this was found.
  delete "device" => "devices#destroy", as: :device

  # The device key (story 0015). The shell registers its Keychain UUID here on
  # launch and receives the signed device cookie every later request rides on.
  post "device/registrations" => "device_registrations#create"

  # The push opt-in (story 0010). POST is the shell's native call (enroll on
  # tap, refresh on every cold launch); DELETE is the plain web Turbo form on
  # /you. `you/push/enable` is what the invitation link points at — in a
  # browser it just bounces back to /you; in the shell PushRouteDecisionHandler
  # intercepts it before the request ever reaches Rails.
  post   "device/push_registrations" => "push_registrations#create"
  delete "device/push_registration"  => "push_registrations#destroy", as: :push_registration
  get "you/push/enable" => redirect("/you"), as: :push_enable

  # The two pages App Store Connect requires by URL (story 0016). Served by a
  # controller that does NOT inherit ApplicationController — see PagesController
  # for why skipping the wall and the browser gate by name was not an option.
  get "privacy" => "pages#privacy", as: :privacy
  get "support" => "pages#support", as: :support

  # The infinite-scroll gallery, moved off the root (decisions/0002).
  get "feed" => "paintings#index", as: :feed

  # The wing label (story 0027) — the filter's own screen, one glyph away
  # from the sticky rail rather than a row of controls in front of the art.
  # A second action on `PaintingsController`, not a new controller: it shares
  # the wall, the params, and the model calls `#index` already has (eng
  # review D1). `ios/Tondo/path-configuration.json` gives this route its own
  # rule — a modal sheet, not a pushed screen.
  get "feed/index" => "paintings#wings", as: :feed_index

  # The permanent address (story 0030) — every painting gets a page independent
  # of whether it was ever a Daily Pick. Numeric PK, not a slug: `Painting` has
  # no per-work slug, and this page is walled with no sharing surface, so a
  # readable natural key buys nothing (plan's recorded PK-vs-slug boundary —
  # revisit if this page ever goes public). Constrained like every sibling
  # `:painting_id` route below, so a junk path 404s at routing with the
  # generic message, not `PaintingsController::NotFound`'s painting-specific one.
  get "paintings/:id" => "paintings#show", as: :painting,
    constraints: { id: /\d+/ }

  # The days behind you. The constraint keeps obvious junk out of the controller;
  # a well-formed date that is not a real one (2026-02-31) still reaches #show
  # and 404s there.
  resources :days, only: %i[index show], param: :date,
    constraints: { date: /\d{4}-\d{2}-\d{2}/ }

  # Everything Tondo holds by one hand (story 0018). Slug, not id — readable,
  # cacheable, and it is the address `Painting#artist_slug` already computes.
  # Two DIFFERENT artists could in principle share a slug (`parameterize`
  # collision); none do in the pool as measured (eng review E4) — they would
  # merge onto one page, accepted until observed.
  #
  # `_` is in the character class, not just `a-z0-9-`: `String#parameterize`
  # keeps a literal underscore rather than collapsing it to the separator
  # (`"Weird_Name".parameterize` => `"weird_name"`), so a slug this route
  # cannot match is one `artist_slug_for` can still produce and persist. A
  # narrower constraint here 500s `artist_path` (`UrlGenerationError`) on
  # every render of that work, on `/feed` and `/days/:date` alike — found by
  # /code-review, not present in the current pool but not prevented by
  # anything either.
  get "artists/:slug" => "artists#show", as: :artist,
    constraints: { slug: /[a-z0-9_\-]+/ }

  # A reader's own collection. `control` is the only per-visitor fragment in the
  # product: the day pages stay byte-identical for everyone and publicly
  # cacheable, and this endpoint — private, no-store — carries the personal part.
  # It is also where the reader's cookie is issued, so every write already has an
  # identity and two cold-start tabs cannot mint two.
  # The sit (story 0032). The impression frame's two doors mirror Keep's:
  # `#control` answers everyone (the controller skips the wall — a bounce
  # would paint "Content missing" into the cached front door, eng A1), the
  # write stays walled and user-only. The beacon is identity-free by design:
  # no cookie, no CSRF (nothing to forge — it can only add 1 to a public
  # tally), constrained to the two event names at the routing layer.
  get  "impression/:painting_id/control" => "impressions#control", as: :impression_control,
    constraints: { painting_id: /\d+/ }
  post "impression/:painting_id" => "impressions#create", as: :impression,
    constraints: { painting_id: /\d+/ }
  post "sit/:event" => "sit_beacons#create", as: :sit_beacon,
    constraints: { event: /shown|completed/ }

  get    "collection" => "favorites#index", as: :collection
  get    "collection/:painting_id/control" => "favorites#control", as: :favorite_control,
    constraints: { painting_id: /\d+/ }
  post   "collection/:painting_id" => "favorites#create",
    constraints: { painting_id: /\d+/ }
  delete "collection/:painting_id" => "favorites#destroy", as: :favorite,
    constraints: { painting_id: /\d+/ }

  namespace :admin do
    root "daily_picks#index"

    resources :daily_picks, except: :show do
      # Preview lives inside the authenticated namespace on purpose: a public
      # preview route would hand out tomorrow's artwork to anyone guessing IDs.
      member { get :preview }
    end
  end
end
