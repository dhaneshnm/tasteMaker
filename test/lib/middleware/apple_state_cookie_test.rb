require "test_helper"

# The production failure this fixes, reproduced as a unit: Apple's callback
# arrives with NO session cookie (cross-site POST, `SameSite=Lax`), so without
# the handoff cookie `omniauth.state` is nil and omniauth-oauth2 raises
# `undefined method 'bytesize' for nil` (bug, 2026-08-16).
#
# Rack rather than an integration test on purpose: `OmniAuth.config.test_mode`
# short-circuits the request phase, so no state is ever written and the app
# stack cannot show this either failing or fixed. That gap is how it shipped.
class AppleStateCookieTest < ActiveSupport::TestCase
  STATE = "b0a1c2d3e4f5"
  NONCE = "n0n1c2e3"
  PARAMS = { "native" => "1" }.freeze

  test "the request phase parks state and nonce in a cookie the cross-site POST can carry" do
    response = request("https://tondo.test/auth/apple", method: "POST",
      session: { "omniauth.state" => STATE, "omniauth.nonce" => NONCE })

    cookie = set_cookie(response, Middleware::AppleStateCookie::COOKIE)

    assert cookie, "the request phase set no handoff cookie"
    assert_includes cookie, "path=/auth"
    assert_match(/samesite=none/i, cookie)
    assert_match(/;\s*secure/i, cookie)
    assert_match(/httponly/i, cookie)
  end

  test "the callback gets both values back even though it arrives with no session" do
    handoff = handoff_cookie

    seen = nil
    request("https://tondo.test/auth/apple/callback", method: "POST",
      cookie: handoff, session: {}) { |env| seen = env["rack.session"].dup }

    assert_equal STATE, seen["omniauth.state"]
    assert_equal NONCE, seen["omniauth.nonce"], "without the nonce, verify_nonce! rejects the id token"
  end

  # Bug, 2026-08-18: `omniauth.params` was missing from `CARRIED`, so the
  # native shell's `native=1` flag never survived Apple's cross-site POST.
  # `SessionsController#native_auth?` read a dropped session as "web", wrote
  # the session into the auth sheet's own jar instead of handing off a token,
  # and the shell's `WKWebView` never saw the sign-in.
  test "the callback gets the native flag back too" do
    handoff = handoff_cookie(state: STATE, nonce: NONCE, params: PARAMS)

    seen = nil
    request("https://tondo.test/auth/apple/callback", method: "POST",
      cookie: handoff, session: {}) { |env| seen = env["rack.session"].dup }

    assert_equal PARAMS, seen["omniauth.params"],
      "without this, native_auth? reads false and the shell never gets the handoff token"
  end

  test "a session that did survive is never overwritten by a stale handoff" do
    seen = nil
    request("https://tondo.test/auth/apple/callback", method: "POST",
      cookie: handoff_cookie, session: { "omniauth.state" => "the-live-one" }) do |env|
        seen = env["rack.session"].dup
      end

    assert_equal "the-live-one", seen["omniauth.state"]
  end

  test "the handoff is spent once — the callback clears it" do
    response = request("https://tondo.test/auth/apple/callback", method: "POST",
      cookie: handoff_cookie, session: {})

    cookie = set_cookie(response, Middleware::AppleStateCookie::COOKIE)

    assert cookie, "the callback did not clear the handoff cookie"
    assert_match(/expires=Thu, 01 Jan 1970/i, cookie)
  end

  # The cookie is what the callback's CSRF check is compared against, so a
  # value an attacker can write is not a CSRF defense at all.
  test "a forged handoff is ignored" do
    seen = nil
    request("https://tondo.test/auth/apple/callback", method: "POST",
      cookie: "#{Middleware::AppleStateCookie::COOKIE}=forged-by-hand", session: {}) do |env|
        seen = env["rack.session"].dup
      end

    assert_nil seen["omniauth.state"]
  end

  test "a request phase that wrote nothing sets nothing" do
    response = request("https://tondo.test/auth/apple", method: "POST", session: {})

    assert_nil set_cookie(response, Middleware::AppleStateCookie::COOKIE)
  end

  test "every other path is left alone" do
    response = request("https://tondo.test/days", method: "GET",
      session: { "omniauth.state" => STATE })

    assert_nil set_cookie(response, Middleware::AppleStateCookie::COOKIE)
  end

  private

  # The cookie exactly as the request phase writes it, fed back in as the
  # browser would send it on Apple's POST.
  def handoff_cookie(state: STATE, nonce: NONCE, params: nil)
    session = { "omniauth.state" => state, "omniauth.nonce" => nonce }
    session["omniauth.params"] = params if params

    response = request("https://tondo.test/auth/apple", method: "POST", session: session)

    set_cookie(response, Middleware::AppleStateCookie::COOKIE).split(";").first
  end

  def request(url, method:, session: {}, cookie: nil, &inner)
    inner_app = lambda do |env|
      inner&.call(env)
      [ 200, { "content-type" => "text/plain" }, [ "ok" ] ]
    end

    stack = ActionDispatch::Cookies.new(Middleware::AppleStateCookie.new(inner_app))

    env = {
      "rack.session" => session,
      "action_dispatch.key_generator" => Rails.application.key_generator,
      "action_dispatch.signed_cookie_salt" =>
        Rails.application.config.action_dispatch.signed_cookie_salt,
      "action_dispatch.cookies_serializer" =>
        Rails.application.config.action_dispatch.cookies_serializer,
      "action_dispatch.cookies_rotations" =>
        Rails.application.config.action_dispatch.cookies_rotations,
      "action_dispatch.use_cookies_with_metadata" =>
        Rails.application.config.action_dispatch.use_cookies_with_metadata
    }
    env["HTTP_COOKIE"] = cookie if cookie

    Rack::MockRequest.new(stack).request(method, url, env)
  end

  def set_cookie(response, name)
    Array(response.headers["set-cookie"]).flat_map { |h| h.split("\n") }
      .find { |c| c.start_with?("#{name}=") }
  end
end
