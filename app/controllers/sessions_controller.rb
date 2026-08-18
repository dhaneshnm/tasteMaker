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

  # `#control` and its `no_store` guard were deleted by story 0017. The landing
  # page's per-visitor fragment is gone with them: the corner mark in the bar
  # and the coda word are identical markup for every reader, so `/` needs no
  # private fragment. The sign-in doors moved to `CornersController`, which
  # carries the class-wide `no_store` this used to.

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

  # The auth sheet's front door (story 0017 Release 2).
  #
  # `ASWebAuthenticationSession` can only OPEN a URL — a GET — and OmniAuth's
  # request phase is POST-only (`config/initializers/omniauth.rb` sets that, and
  # it is what `omniauth-rails_csrf_protection` guards). So the sheet lands here
  # and this page immediately submits itself.
  #
  # `native=1` rides the form because the callback cannot otherwise tell this
  # flow apart: the sheet is Safari, not the shell, so its user agent carries no
  # `Tondo iOS` and `native_shell?` is false throughout. OmniAuth stashes the
  # request-phase params and hands them back as `omniauth.params`.
  def start
    @provider = params[:provider]
    render layout: false
  end

  def create
    # An unregistered provider name slips past OmniAuth untouched, so the env
    # carries no auth hash. The route constraint keeps those out; this guard
    # is the belt for a misconfigured strategy answering the same way.
    auth = request.env["omniauth.auth"]
    return redirect_to root_path unless auth

    user = User.from_omniauth(auth)

    # The native flow stops here and hands over a token instead of a session.
    #
    # This request is running in the auth sheet's own cookie jar, which the
    # WKWebView cannot read — Apple gives no way to share them. Writing a
    # session here would authenticate a container the reader is about to close.
    # So: sign nothing in, mint a 60-second single-use token, and bounce out to
    # the custom scheme the shell is listening on. `#handoff` finishes the job
    # in the jar that matters.
    if native_auth?
      return redirect_to "tondo://auth?handoff=#{CGI.escape(user.generate_token_for(:handoff))}",
        allow_other_host: true
    end

    # reset_session BEFORE writing: a session id handed out pre-auth must not
    # become an authenticated one (fixation).
    reset_session
    session[:user_id] = user.id

    redirect_to days_path
  end

  # The other side of the sheet (story 0017 Release 2). Runs in the WEB VIEW.
  #
  # This is the only request in the flow that can see both keys at once: the
  # token proves who signed in, and the device cookie — which lives in this jar
  # and only this jar — says whose collection is sitting on the phone. So the
  # claim happens HERE, not at the callback, where the device cookie does not
  # exist.
  #
  #   tondo://auth?handoff=…  ──shell──> GET /session/handoff?token=…
  #                                          │
  #                     find_by_token_for ───┤ nil → home, quietly
  #                                          │
  #                     reset_session, sign in
  #                     spend the token (single use)
  #                     claim this device's works
  #                                          │
  #                     moved? ──> /collection   (the works ARE the receipt)
  #                     none?  ──> /you
  def handoff
    user = User.find_by_token_for(:handoff, params[:token])

    # Expired, replayed, or forged. Not an error screen: the reader is looking
    # at a web view that just came back from a sheet, and the honest answer is
    # the room they started in. They are still the device they were.
    return redirect_to(corner_path, status: :see_other) unless user

    device = current_device

    reset_session
    session[:user_id] = user.id
    user.spend_handoff_tokens!

    moved = device ? Favorite.claim!(device: device, user: user) : 0

    # The works are the receipt. A reader who watched a sheet open and close on
    # a promise that twelve works would move should land on the twelve works,
    # not on a screen that says the account exists.
    redirect_to(moved.positive? ? collection_path : corner_path, status: :see_other)
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

  private
    # Set by `#start`'s form and echoed back by OmniAuth. The user agent cannot
    # answer this — the sheet is Safari.
    def native_auth?
      request.env["omniauth.params"].to_h["native"] == "1"
    end
end
