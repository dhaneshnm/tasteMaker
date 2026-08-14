Rails.application.routes.draw do
  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

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
  match "auth/:provider/callback" => "sessions#create", via: %i[get post]
  get "auth/failure" => "sessions#failure"
  delete "session" => "sessions#destroy", as: :session

  # The landing page's per-visitor fragment (the favorites#control precedent):
  # sign-in buttons for a signed-out web visitor, a quiet account line for a
  # signed-in one, nothing at all for a device.
  get "session/control" => "sessions#control", as: :session_control

  # The exit door the category's leader never built. Signed-in only.
  delete "account" => "accounts#destroy", as: :account

  # The device key (story 0015). The shell registers its Keychain UUID here on
  # launch and receives the signed device cookie every later request rides on.
  post "device/registrations" => "device_registrations#create"

  # The infinite-scroll gallery, moved off the root (decisions/0002).
  get "feed" => "paintings#index", as: :feed

  # The days behind you. The constraint keeps obvious junk out of the controller;
  # a well-formed date that is not a real one (2026-02-31) still reaches #show
  # and 404s there.
  resources :days, only: %i[index show], param: :date,
    constraints: { date: /\d{4}-\d{2}-\d{2}/ }

  # A reader's own collection. `control` is the only per-visitor fragment in the
  # product: the day pages stay byte-identical for everyone and publicly
  # cacheable, and this endpoint — private, no-store — carries the personal part.
  # It is also where the reader's cookie is issued, so every write already has an
  # identity and two cold-start tabs cannot mint two.
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
