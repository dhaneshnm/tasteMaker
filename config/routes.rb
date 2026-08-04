Rails.application.routes.draw do
  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # The artwork of the day is the front door.
  root "daily#show"

  # The infinite-scroll gallery, moved off the root (decisions/0002).
  get "feed" => "paintings#index", as: :feed

  # The days behind you. The constraint keeps obvious junk out of the controller;
  # a well-formed date that is not a real one (2026-02-31) still reaches #show
  # and 404s there.
  resources :days, only: %i[index show], param: :date,
    constraints: { date: /\d{4}-\d{2}-\d{2}/ }

  namespace :admin do
    root "daily_picks#index"

    resources :daily_picks, except: :show do
      # Preview lives inside the authenticated namespace on purpose: a public
      # preview route would hand out tomorrow's artwork to anyone guessing IDs.
      member { get :preview }
    end
  end
end
