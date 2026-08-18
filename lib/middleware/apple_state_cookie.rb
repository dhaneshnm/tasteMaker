# The Apple half of story 0015's front door, repaired against production
# (bug, 2026-08-16).
#
# Apple returns its callback as a cross-site POST (`response_mode=form_post`),
# and `_tondo_session` is `SameSite=Lax` — which browsers do not send on a
# cross-site POST. So `omniauth.state` and `omniauth.nonce`, written to the
# session at the request phase, are simply absent when the callback lands.
# omniauth-oauth2 then compares Apple's state against `nil` and its
# `secure_compare` has no nil guard (`string_a.bytesize == string_b.bytesize`,
# omniauth-oauth2-1.9.0/lib/omniauth/strategies/oauth2.rb:149), so the failure
# reached the reader as `undefined method 'bytesize' for nil` rather than a
# clean `csrf_detected`. The plan called this trap before it fired
# (`specs/0015-the-two-keys/plan.md`); only the error string was a surprise.
#
# The fix is the one the plan chose: carry those two values across the
# cross-site hop in a dedicated cookie scoped to `/auth` and marked
# `SameSite=None; Secure`, and leave `_tondo_session` alone. Loosening the
# session cookie instead would work in one line and is the wrong line —
# its `Lax` posture is part of this product's CSRF defense, and it carries
# `user_id` for anyone already signed in.
#
# Signed, not plain: state is only a CSRF defense if an attacker cannot write
# the value the callback compares against.
#
# The suite cannot reach this through the app stack — `OmniAuth.config
# .test_mode` short-circuits the request phase, so no state is ever written,
# which is exactly how this shipped green. It is tested as what it is: a piece
# of Rack.
module Middleware
  class AppleStateCookie
    REQUEST_PATH  = "/auth/apple"
    CALLBACK_PATH = "/auth/apple/callback"
    COOKIE        = "_tondo_apple_handoff"

    # Not just state: omniauth-apple reads the nonce back out of the session
    # too (`stored_nonce`), and `verify_nonce!` rejects the id token without
    # it. `omniauth.params` carries the native shell's `native=1` flag (story
    # 0017 Release 2) — without it, `SessionsController#native_auth?` reads a
    # dropped session as "web", writes the session into the auth sheet's own
    # jar instead of handing off a token, and the shell never sees the sign-in
    # (bug, 2026-08-18: Apple's native flow signed the reader into the sheet's
    # web view only).
    CARRIED = %w[omniauth.state omniauth.nonce omniauth.params].freeze

    # Long enough to read Apple's consent screen, short enough that a stolen
    # handoff is worth little.
    TTL = 10.minutes

    def initialize(app)
      @app = app
    end

    def call(env)
      request = ActionDispatch::Request.new(env)

      # Before OmniAuth sees the callback — it reads state out of the session
      # the moment its callback phase begins.
      restore(request) if callback?(request)

      response = @app.call(env)

      # After OmniAuth has run the request phase — whatever it just wrote to
      # the session is what the callback will come back needing.
      stash(request) if request_phase?(request)
      discard(request) if callback?(request)

      response
    end

    private

    def request_phase?(request)
      request.post? && request.path == REQUEST_PATH
    end

    def callback?(request)
      request.path == CALLBACK_PATH
    end

    def stash(request)
      carried = CARRIED.index_with { |key| request.session[key] }.compact
      return if carried.empty?

      request.cookie_jar.signed[COOKIE] = attributes(request).merge(value: carried)
    end

    def restore(request)
      carried = request.cookie_jar.signed[COOKIE]
      return if carried.blank?

      # `||=`, so a session that did survive the hop is never overwritten by a
      # stale cookie from an abandoned attempt.
      CARRIED.each { |key| request.session[key] ||= carried[key] }
    end

    def discard(request)
      request.cookie_jar.delete(COOKIE, **attributes(request).except(:expires))
    end

    def attributes(request)
      {
        path: "/auth",
        same_site: :none,
        # Browsers ignore `SameSite=None` on a cookie that is not Secure.
        # Production is `force_ssl`, so this is true where it matters; the
        # suite speaks http and would otherwise never see the cookie return.
        secure: request.ssl?,
        httponly: true,
        expires: TTL.from_now
      }
    end
  end
end
