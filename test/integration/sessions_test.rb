require "test_helper"

# The account key (story 0015): OAuth in, session out, and the landing page's
# three-state fragment. Providers are mocked suite-wide (test_helper) — the
# Apple flow's real cross-site POST is verifiable only on the deployed domain
# and is on the ship checklist, not in this file.
class SessionsTest < ActionDispatch::IntegrationTest
  test "first Google sign-in creates the user; the second finds it" do
    assert_difference "User.count", 1 do
      sign_in
    end

    delete "/session"

    assert_no_difference "User.count" do
      sign_in
    end
  end

  test "sign-in lands on the archive, signed in" do
    sign_in

    assert_equal "/days", path
    assert_response :success
  end

  test "the session id rotates across sign-in — fixation" do
    key = Rails.application.config.session_options.fetch(:key)

    # Prime a pre-auth session (the fragment writes one for its CSRF tokens).
    get "/session/control"
    pre_auth_cookie = cookies[key]

    sign_in
    post_auth_cookie = cookies[key]

    refute_equal pre_auth_cookie, post_auth_cookie,
      "a session id handed out before auth must not become an authenticated one"
  end

  test "Apple's first-auth name and email survive a later auth that omits them" do
    sign_in(provider: :apple, uid: "apple-uid", email: "relay@privaterelay.appleid.com", name: "A Reader")
    delete "/session"

    # Apple sends name/email only on first authorization.
    sign_in(provider: :apple, uid: "apple-uid", email: nil, name: nil)

    user = User.find_by!(provider: "apple", uid: "apple-uid")
    assert_equal "relay@privaterelay.appleid.com", user.email
    assert_equal "A Reader", user.name
  end

  test "declined consent goes quietly home" do
    OmniAuth.config.mock_auth[:google_oauth2] = :access_denied

    post "/auth/google_oauth2"
    follow_redirect! # into the middleware's failure leg
    follow_redirect! # /auth/failure

    assert_redirected_to root_path
  end

  test "sign out resets the session and the wall closes" do
    sign_in

    delete "/session"
    assert_equal 303, response.status

    get "/days"
    assert_equal 303, response.status, "the wall must close behind a sign-out"
  end

  test "the fragment renders sign-in doors for a signed-out web visitor" do
    get "/session/control"

    assert_response :success
    assert_select "turbo-frame#signin .signin__door", count: 2
    assert_includes response.headers["Cache-Control"], "no-store"
  end

  test "the fragment renders the quiet line for a signed-in reader" do
    sign_in

    get "/session/control"

    assert_select ".signin--in", count: 1
    assert_select ".signin__door", count: 0
    assert_select "a[href=?]", collection_path
  end

  test "the fragment renders empty for a device" do
    register_device

    get "/session/control"

    assert_select "turbo-frame#signin", count: 1
    assert_select ".signin", count: 0
  end

  test "the fragment renders empty for an UNREGISTERED shell" do
    # First launch, registration failed or in flight: no cookie, shell UA.
    # The app must degrade to art-plus-nothing, never to login UI (Codex).
    get "/session/control",
      headers: { "User-Agent" => "#{ApplicationController::NATIVE_UA_TOKEN}; Mozilla/5.0" }

    assert_select "turbo-frame#signin", count: 1
    assert_select ".signin", count: 0
    assert_select ".signin__door", count: 0
  end
end
