require "test_helper"

# The wall (story 0015, retargeted by 0017). Every reader-facing endpoint
# answers only the two keys — a signed-in web session or a registered device —
# and everything else bounces to `/you`, the reader's corner, which holds the
# sign-in doors and is therefore unwalled itself. The landing page, the error
# pages, the two legal pages and the curator's desk stay outside it too, each
# for a stated reason (specs/0015-the-two-keys/plan.md, specs/0017).
class WallTest < ActionDispatch::IntegrationTest
  # A method, not a constant: two of these need fixtures, which only exist
  # once a test is running.
  def gated_paths
    # `favorite_control_path` left this list in story 0017. It answers an
    # unidentified caller with the null keep state — the same outline mark the
    # publicly cached page already draws — because bouncing that eager frame
    # wrote "Content missing" over the placeholder. See FavoritesController.
    [ "/days", "/feed", "/collection",
      day_path(daily_picks(:yesterday).scheduled_on.iso8601),
      artist_path(paintings(:sunflowers).artist_slug),
      painting_path(paintings(:woodcut)) ]
  end

  test "cookieless requests bounce to the corner and leak nothing" do
    gated_paths.each do |path|
      get path

      assert_redirected_to corner_path, "#{path} did not bounce"
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
    assert_redirected_to corner_path
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

  # Story 0017 deleted the landing page's sign-in fragment. What the front door
  # carries now is the corner: a mark in the bar and a word in the coda, both
  # plain links, both identical for every reader — which is what lets them live
  # on a page Thruster caches publicly.
  test "the landing page stays open and carries both doors to the corner" do
    get "/"

    assert_response :success
    assert_select "turbo-frame#signin", count: 0, message: "the sign-in fragment should be gone"
    assert_select "a.masthead__you[href=?]", corner_path
    assert_select ".coda__doors .caps-link[href=?]", corner_path, text: "Your corner"
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

  # A frame WRITE that bounced used to become "Content missing" — the habit
  # mechanic silently swallowed for a reader whose identity died mid-page. The
  # wall answers those in kind (design review D3, code review F5).
  #
  # The READ is story 0017's correction. It used to bounce 303, and the comment
  # here claimed the cached page's default glyph survived that. It did not
  # survive on merit: the bounce landed on `/`, which happens to carry a
  # `keep_<id>` frame for today's painting, so Turbo swapped in that page's
  # identical placeholder. Retarget the bounce to `/you` — which has no such
  # frame — and Turbo writes "Content missing" over the mark instead. So the
  # read now answers directly with the null state, which is the same outline
  # glyph and leaks nothing.
  test "a bounced frame write gets a matching frame with a way in, not a hole" do
    frame = "keep_#{paintings(:sunflowers).id}"

    post favorite_path(paintings(:sunflowers)), headers: { "Turbo-Frame" => frame }

    assert_response :unauthorized
    assert_select "turbo-frame##{frame}", count: 1
    assert_select "a[href=?]", corner_path, text: "Sign in"
  end

  # The other walled frame GET, and the one the keep-frame fix does not cover.
  # `paintings/_page.html.erb:5` is a lazy sentinel that fetches the next page of
  # the gallery, and `PaintingsController` is walled — so a device revoked
  # mid-scroll issues a frame GET that used to redirect to a page carrying no
  # matching frame, and Turbo wrote "Content missing" where the scroll should be.
  # Found by /code-review on 2026-08-17.
  test "a walled frame read gets a way back, not the words Content missing" do
    get feed_path(page: 2), headers: { "Turbo-Frame" => "feed-page-2" }

    assert_response :unauthorized
    assert_select "turbo-frame#feed-page-2", count: 1
    assert_select "a[href=?]", corner_path, text: "Sign in"
  end

  test "an unidentified frame read gets the null keep state, not a bounce" do
    frame = "keep_#{paintings(:sunflowers).id}"

    get favorite_control_path(paintings(:sunflowers)), headers: { "Turbo-Frame" => frame }

    assert_response :success
    assert_select "turbo-frame##{frame} button.rail__act[aria-pressed=false]", count: 1
    assert_includes response.headers["Cache-Control"], "no-store"
  end

  test "error pages answer without identity" do
    with_rescued_exceptions do
      get "/definitely-not-a-page"
      assert_response :not_found
    end
  end
end
