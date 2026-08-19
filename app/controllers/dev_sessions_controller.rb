# The dev-only mock sign-in door (story 0021). Local dev has no way behind
# `require_reader` without live Google/Apple credentials, and Apple never
# works locally regardless (sessions_controller.rb — the callback is a
# cross-site POST verified only on the deployed domain). This reuses the
# exact mechanism test_helper.rb already proves for the automated suite,
# for a human clicking around a running `rails s`:
#
#   GET  /dev/sign_in ──────────► #new
#                                    renders provider/uid/email/name form
#
#   POST /dev/sign_in ──────────► #create
#                                    ├─ recognized provider?
#                                    │    no  → redirect back, mock_auth untouched
#                                    │    yes → OmniAuth.config.test_mode = true
#                                    │          Rails.logger.warn (process-global flip)
#                                    │          OmniAuth.config.mock_auth[provider] = AuthHash
#                                    │          render shared/_auto_submit_auth_form
#                                    ▼
#                           (browser auto-submits, real Rails CSRF token in the body)
#                                    ▼
#   POST /auth/:provider ───────► OmniAuth::Builder middleware (test_mode ⇒ returns
#                                    the mock, skips the real provider network call)
#                                    ▼
#   .../auth/:provider/callback ─► SessionsController#create — UNMODIFIED
#                                    ▼
#                                 redirect_to days_path — reader is now signed in
#
# Reachable only when `config.x.dev_sign_in_enabled` is true (development by
# default; see config/routes.rb's routing constraint on `dev/sign_in`).
#
# `ensure_dev_sign_in_enabled!` below is a SECOND guard, not a redundant one
# (code review flagged the original single-guard design). The routing
# constraint alone would make this route unreachable today, but this
# controller mints a real signed-in identity from attacker-chosen
# provider/uid/email through the genuine `SessionsController#create` path —
# an identity-minting endpoint is exactly the kind of surface that should not
# depend on `config/routes.rb` staying correctly shaped forever (a bad merge,
# or a route added outside the `constraints do...end` block, would otherwise
# ship this live with nothing in the controller to stop it). Cheap: one
# boolean read.
#
# `OmniAuth.config.mock_auth`/`test_mode` are process-global (OmniAuth's own
# design, not this controller's) — two concurrent uses of the door for the
# same provider (two tabs, or a multi-worker Puma config) can race and sign
# a tab in as the wrong identity. Accepted for the same reason the
# `test_mode` flip below is: this is a single-developer local convenience,
# not shared or production state, and closing it would add real complexity
# for a threat model that doesn't apply here.
class DevSessionsController < ApplicationController
  # This is how a reader with no identity GETS one. Walling it would lock the
  # door from the inside — the same reason SessionsController skips it.
  skip_before_action :require_reader
  before_action :ensure_dev_sign_in_enabled!

  PROVIDERS = %w[google_oauth2 apple].freeze
  DEFAULT_UID = "dev-uid-1"

  def new
  end

  def create
    provider = params[:provider]
    return redirect_to(dev_sign_in_path) unless PROVIDERS.include?(provider)

    OmniAuth.config.test_mode = true
    Rails.logger.warn(
      "OmniAuth.config.test_mode is now TRUE for this process — restart " \
      "`rails s` to use real Google/Apple sign-in again."
    )
    OmniAuth.config.mock_auth[provider.to_sym] = self.class.build_auth_hash(
      provider: provider, uid: params[:uid], email: params[:email], name: params[:name]
    )

    @provider = provider
    render layout: false
  end

  # Extracted so it is unit-testable with no router or controller instance
  # involved (this repo has no ActionController::TestCase — see
  # test/controllers/dev_sessions_controller_test.rb).
  #
  # A stable default uid (DEFAULT_UID) rather than a random one: a dev who
  # revisits the door without typing a uid signs back in as the SAME local
  # User every time, instead of minting a new row per visit.
  def self.build_auth_hash(provider:, uid:, email:, name:)
    OmniAuth::AuthHash.new(
      provider: provider,
      uid: uid.presence || DEFAULT_UID,
      info: { email: email.presence, name: name.presence }.compact
    )
  end

  private
    # The route-level guard (config/routes.rb) is the primary gate; this is
    # the belt for that suspender — see the class comment above for why an
    # identity-minting endpoint gets one even though it "can't happen" today.
    def ensure_dev_sign_in_enabled!
      raise ActionController::RoutingError, "Not Found" unless Rails.application.config.x.dev_sign_in_enabled
    end
end
