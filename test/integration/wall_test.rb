require "test_helper"

# The wall (story 0015). Every reader-facing endpoint answers only the two
# keys — a signed-in web session or a registered device — and everything else
# bounces to the landing page's sign-in anchor. The landing page itself, the
# error pages, and the curator's desk stay outside it, each for a stated
# reason (specs/0015-the-two-keys/plan.md).
class WallTest < ActionDispatch::IntegrationTest
  # A method, not a constant: two of these need fixtures, which only exist
  # once a test is running.
  def gated_paths
    [ "/days", "/feed", "/collection",
      day_path(daily_picks(:yesterday).scheduled_on.iso8601),
      favorite_control_path(paintings(:sunflowers)) ]
  end

  test "cookieless requests bounce to the sign-in anchor and leak nothing" do
    gated_paths.each do |path|
      get path

      assert_redirected_to root_path(anchor: "signin"), "#{path} did not bounce"
      assert_equal 303, response.status, "the wall's redirect must be 303"
      assert_empty response.body.to_s.scan(/label__title/),
        "#{path} leaked page content in the redirect body"
    end
  end

  # Found live at QA: in production the CSRF check answers a cookieless POST
  # first (422) — a signed-out browser never renders a keep button, so that
  # POST is curl, not a person. The wall's own 303 is the answer whenever a
  # POST gets past CSRF. Both halves asserted, so neither env surprises.
  test "a cookieless keep POST is refused either way and never writes" do
    with_forgery_protection do
      assert_no_difference "Favorite.count" do
        post favorite_path(paintings(:sunflowers))
      end
      assert_response :unprocessable_content
    end

    assert_no_difference "Favorite.count" do
      post favorite_path(paintings(:sunflowers))
    end
    assert_equal 303, response.status, "past CSRF, the wall's redirect must be 303"
    assert_redirected_to root_path(anchor: "signin")
  end

  test "a registered device passes" do
    register_device

    get "/days"
    assert_response :success

    get "/feed"
    assert_response :success
  end

  test "a signed-in reader passes" do
    sign_in

    get "/days"
    assert_response :success
  end

  test "a forged unsigned device cookie fails" do
    cookies[:device] = "not-a-signed-value"

    get "/days"
    assert_equal 303, response.status
  end

  test "a validly signed cookie whose device row is gone fails — revocation works" do
    token = register_device
    Device.find_by!(token_digest: Device.digest(token)).destroy

    get "/days"
    assert_equal 303, response.status, "deleting the row is the kill switch and it must kill"
  end

  test "gated pages are private, not publicly cacheable" do
    register_device

    get "/days"
    assert_includes response.headers["Cache-Control"], "private",
      "a shared cache holding a gated page's body outlives a sign-out"
    refute_includes response.headers["Cache-Control"], "public"
  end

  test "the landing page stays open and carries the sign-in anchor" do
    get "/"

    assert_response :success
    assert_select "turbo-frame#signin", count: 1
  end

  test "anonymous admin gets the basic-auth challenge, not a bounce" do
    get "/admin"

    assert_response :unauthorized
    assert response.headers["WWW-Authenticate"].present?,
      "the curator's key is basic auth; the wall must not intercept it"
  end

  # The three identity states, one body (story 0015). The wall must not leak
  # into the public page: a device, a signed-in reader, and nobody at all get
  # the same bytes and the same ETag from `/`. (Lives here rather than in
  # public_cache_headers_test because that file runs with forgery protection
  # on, which the mocked sign-in POST cannot pass.)
  test "the front door is byte-identical across all three identity states" do
    get "/"
    nobody = [ response.body, response.headers["ETag"] ]

    register_device
    get "/"
    device = [ response.body, response.headers["ETag"] ]

    sign_in
    get "/"
    signed_in = [ response.body, response.headers["ETag"] ]

    assert_equal nobody, device, "the device identity changed the front door"
    assert_equal nobody, signed_in, "the account identity changed the front door"
  end

  test "error pages answer without identity" do
    with_rescued_exceptions do
      get "/definitely-not-a-page"
      assert_response :not_found
    end
  end
end
