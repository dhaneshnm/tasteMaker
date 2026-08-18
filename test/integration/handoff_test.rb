require "test_helper"

# The auth sheet's round trip (story 0017 Release 2).
#
# ASWebAuthenticationSession runs in a Safari-backed container with its own
# cookie jar. Apple gives no way to share it with the WKWebView the reader
# returns to, so the session cannot simply be written at the callback: it would
# authenticate a container about to close. What crosses instead is a token.
#
#   sheet   GET  /auth/start/:provider   auto-submits, carrying native=1
#           POST /auth/:provider         OmniAuth's request phase
#           →    provider consent
#           →    /auth/:provider/callback   ← Safari's jar. NO device cookie.
#           →    tondo://auth?handoff=…
#   shell   GET  /session/handoff?token=…  ← the web view's jar. Device cookie.
#
# The claim happens on the LAST leg for exactly that reason: it is the only
# request in the flow that can see both keys at once.
class HandoffTest < ActionDispatch::IntegrationTest
  def start_native_auth(provider: :google_oauth2, uid: "native-1")
    mock_auth(provider: provider, uid: uid)
    post "/auth/#{provider}?native=1"
    follow_redirect!
  end

  test "the sheet's entry page submits itself into OmniAuth's POST-only door" do
    get auth_start_path("google_oauth2")

    assert_response :success
    assert_select "form[action=?][method=post]", "/auth/google_oauth2?native=1"
    # No layout: this frame exists for milliseconds and must not pull the
    # masthead, the compass or the corner into the sheet.
    assert_select ".masthead", count: 0
  end

  test "an unknown provider is not offered a form to post" do
    get "/auth/start/facebook"

    assert_response :not_found
  end

  # The callback must NOT write a session here. It is the wrong jar.
  test "the native callback hands over a token instead of signing in" do
    start_native_auth

    assert_response :redirect
    assert_match %r{\Atondo://auth\?handoff=}, response.headers["Location"]
    assert_nil session[:user_id], "the sheet's jar must not be authenticated"
  end

  test "the web callback still signs in directly and never sees the scheme" do
    mock_auth
    post "/auth/google_oauth2"
    follow_redirect!

    assert_redirected_to days_path
    assert_not_nil session[:user_id]
  end

  test "the handoff signs the reader in inside the web view's jar" do
    start_native_auth
    token = CGI.unescape(response.headers["Location"][/handoff=(.+)\z/, 1])

    get session_handoff_path(token: token)

    assert_not_nil session[:user_id]
    assert_redirected_to corner_path
  end

  # The whole point of the story. The device cookie only exists on this leg.
  test "the handoff claims this device's works and lands on them" do
    token = register_device
    Favorite.create!(painting: paintings(:sunflowers),
      collector_digest: Device.digest(token))

    start_native_auth
    token = CGI.unescape(response.headers["Location"][/handoff=(.+)\z/, 1])

    get session_handoff_path(token: token)

    assert_redirected_to collection_path, "the works are the receipt"
    assert_equal 1, Favorite.owned_by(User.last).count
    assert_not_nil Device.last.claimed_at
  end

  test "a handoff that moved nothing lands in the corner instead" do
    register_device
    start_native_auth
    token = CGI.unescape(response.headers["Location"][/handoff=(.+)\z/, 1])

    get session_handoff_path(token: token)

    assert_redirected_to corner_path
    assert_nil Device.last.claimed_at
  end

  # The token rides a custom URL scheme, and on iOS a scheme can be claimed by
  # more than one app. Single use is the guard.
  test "a handoff token cannot be spent twice" do
    start_native_auth
    token = CGI.unescape(response.headers["Location"][/handoff=(.+)\z/, 1])

    get session_handoff_path(token: token)
    reset!

    get session_handoff_path(token: token)

    assert_nil session[:user_id], "a replayed token must not authenticate"
    assert_redirected_to corner_path
  end

  test "a forged handoff is answered quietly, not with an error" do
    get session_handoff_path(token: "not-a-real-token")

    assert_nil session[:user_id]
    assert_redirected_to corner_path
  end
end
