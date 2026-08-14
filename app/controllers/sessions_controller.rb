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

  def create
    auth = request.env["omniauth.auth"]
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
    no_store

    state =
      if current_user then :signed_in
      elsif current_device || native_shell? then :device
      else :signed_out
      end

    render partial: "sessions/control", locals: { state: state }
  end
end
