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

  # The ship-blocker both review models found: Apple's callback is a
  # cross-site POST with no authenticity token, and the suite-wide forgery
  # off-switch hid that Rails would 422 it. Protection forced ON here — this
  # test fails against a SessionsController without the scoped skip.
  test "the Apple callback POST survives CSRF protection" do
    mock_auth(provider: :apple, uid: "apple-uid", email: "a@example.com")

    with_forgery_protection do
      post "/auth/apple/callback"
    end

    assert_redirected_to days_path
    assert User.exists?(provider: "apple", uid: "apple-uid")
  end

  test "an unknown provider's callback is a 404, not a 500" do
    with_rescued_exceptions do
      get "/auth/anything/callback"

      assert_response :not_found
    end
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

  # The four fragment tests that lived here moved to `corners_test.rb` with the
  # fragment itself. `SessionsController#control` and `/session/control` are
  # gone: story 0017 gave the sign-in doors a page of their own, so there is no
  # per-visitor fragment on the landing page left to render.
  test "the deleted fragment endpoint is gone, not merely unlinked" do
    get "/session/control"

    assert_response :not_found
  end
end
