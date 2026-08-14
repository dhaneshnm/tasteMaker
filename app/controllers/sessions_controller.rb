# The account key's front desk (story 0015): OAuth in, session out, and the
# landing page's per-visitor fragment.
#
#   POST /auth/google_oauth2 ─┐ (omniauth-rails_csrf_protection guards these)
#   POST /auth/apple ─────────┤
#                             ▼
#              provider's consent screen
#                             │
#   GET  /auth/google_oauth2/callback ──┐
#   POST /auth/apple/callback ──────────┤  Apple returns a CROSS-SITE POST —
#                                       ▼  the plan's most-watched edge
#                          create: find-or-create User,
#                          reset_session (fixation), session[:user_id]
#
# No password, no signup form, no mailer. A declined consent is not an error
# page — failure goes quietly home.
class SessionsController < ApplicationController
  # The whole controller is how you GET an identity; walling it would lock the
  # door from the inside.
  skip_before_action :require_reader

  # The class-wide idiom from FavoritesController, for the same reason: a
  # second per-visitor action added here must not be able to ship a storable
  # response by forgetting a line.
  before_action :no_store, only: :control

  # THE APPLE CALLBACK IS A CROSS-SITE POST — no authenticity token, no Lax
  # session cookie — so Rails' own CSRF check would 422 every real Apple
  # sign-in before this action ran a line (code review, both models, ship-
  # blocker). The scoped skip is safe because the callback phase's actual
  # guard is OmniAuth's state validation in the middleware, and the request
  # phase stays covered by omniauth-rails_csrf_protection. `only: :create`,
  # never the whole controller: destroy and control keep their protection.
  # The suite exercises this with forgery protection forced on — the suite-
  # wide off-switch is exactly what hid it.
  skip_forgery_protection only: :create

  def create
    # An unregistered provider name slips past OmniAuth untouched, so the env
    # carries no auth hash. The route constraint keeps those out; this guard
    # is the belt for a misconfigured strategy answering the same way.
    auth = request.env["omniauth.auth"]
    return redirect_to root_path unless auth

    user = User.from_omniauth(auth)

    # reset_session BEFORE writing: a session id handed out pre-auth must not
    # become an authenticated one (fixation).
    reset_session
    session[:user_id] = user.id

    redirect_to days_path
  end

  # Declined consent, provider hiccup, stale state. The reader changed their
  # mind; the landing page is the answer, not an error screen.
  def failure
    redirect_to root_path
  end

  def destroy
    reset_session
    redirect_to root_path, status: :see_other
  end

  # The landing page's private fragment (design review D3-D5). Three states:
  #
  #   signed-out web   → one quiet line + the two provider buttons
  #   signed-in web    → `Your collection → · Sign out`
  #   device / shell   → empty frame — the app never sees login UI, including
  #                      an UNREGISTERED shell (no cookie yet), which is why
  #                      the user-agent check exists and not just the cookie
  #
  # Rendering the buttons writes a session cookie (their CSRF tokens live in
  # the session). That is the 0006 pattern: private no-store fragments are
  # where cookies are allowed to happen; the public HTML of `/` stays clean.
  def control
    state =
      if current_user then :signed_in
      elsif native_shell? || current_device then :device
      else :signed_out
      end

    render partial: "sessions/control", locals: { state: state }
  end
end
