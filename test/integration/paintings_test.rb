require "test_helper"

# The permanent address (story 0030). The anonymous case (signed-out reader
# walled off) is covered generically by `WallTest#gated_paths`, the same way
# `artist_path` already is — no bespoke copy of that check lives here.
class PaintingsTest < ActionDispatch::IntegrationTest
  # The 404 tests below need `show_exceptions` on — see `errors_test.rb` and
  # `artists_test.rb`, whose comments explain why the test environment's
  # default (re-raise instead of rendering) is the opposite of what these assert.
  with_rescued_exceptions!

  test "a registered device can open a work's own page" do
    register_device
    get painting_path(paintings(:woodcut))

    assert_response :success
    assert_select "h1.label__title", text: paintings(:woodcut).title
  end

  # E1/C1. Junk at the routing layer, not the controller — the constraint
  # 404s before `PaintingsController::NotFound` is ever raised.
  test "a non-numeric id 404s at routing, with the generic message" do
    register_device
    get "/paintings/wp-login.php"

    assert_response :not_found
    assert_no_match(/on that day/, response.body)
    assert_no_match(/No such work here/, response.body)
  end

  # C1. A bare `RecordNotFound` would answer with the day-archive message —
  # this is the assertion that would have caught it.
  test "an unknown but well-formed id 404s, and does not say it was about a day" do
    register_device
    get painting_path(Painting.maximum(:id) + 1)

    assert_response :not_found
    assert_no_match(/on that day/, response.body)
    assert_match(/No such work here/, response.body)
  end

  # The route is universal by design (plan's "Universal or fallback-only?"
  # decision) — only the /collection row link is fallback-only. Nothing else
  # asserts that a picked work also answers here.
  test "a painting that also has a published Daily Pick still answers here" do
    register_device
    get painting_path(paintings(:harbour))

    assert_response :success
    assert_select "h1.label__title", text: paintings(:harbour).title
  end

  test "a resting work with no image still renders, not raises" do
    register_device
    get painting_path(paintings(:imageless))

    assert_response :success
    assert_select ".plate__resting"
  end

  # C2. The masthead label is a <p>; without `heading_tag: :h1` threaded
  # through the reused partial this page has no primary heading at all.
  test "the page has a real h1, unlike the masthead label above it" do
    register_device
    get painting_path(paintings(:woodcut))

    assert_select ".masthead__label", text: "Painting"
    assert_select "h1.label__title", text: paintings(:woodcut).title
    assert_select "h2.label__title", count: 0
  end

  test "the page mounts its own zoom overlay" do
    register_device
    get painting_path(paintings(:woodcut))

    assert_select "main.page[data-controller=artwork]"
    assert_select ".zoom[role=dialog][aria-modal=true]", count: 1
    assert_select "button.plate__zoom", count: 1
  end

  test "the tab title carries the work's name" do
    register_device
    get painting_path(paintings(:woodcut))

    assert_select "title", "#{paintings(:woodcut).title} — Tondo"
  end

  # Walled-page contract, same as `/artists/:slug` — currently only asserted
  # from the public side (`test/integration/public_cache_headers_test.rb`).
  test "the page revalidates instead of going stale, and is never public" do
    register_device
    get painting_path(paintings(:woodcut))

    assert_response :success
    assert_match "no-cache", response.headers["Cache-Control"]
    assert_match "private", response.headers["Cache-Control"]
    assert_no_match(/\bpublic\b/, response.headers["Cache-Control"])
    assert response.headers["ETag"].present?, "expected an ETag to revalidate against"
  end

  test "an unchanged page costs a 304" do
    register_device
    get painting_path(paintings(:woodcut))
    etag = response.headers["ETag"]

    get painting_path(paintings(:woodcut)), headers: { "HTTP_IF_NONE_MATCH" => etag }
    assert_response :not_modified
  end

  # Same regression rule as `ArtistsController` (story 0018/0020): the
  # automatic `Rack::ETag` body digest is what keeps a kept mark from coming
  # back stale, since this controller runs no manual `stale?`.
  test "a kept mark never comes back stale on revalidation" do
    register_device
    get painting_path(paintings(:woodcut))
    etag = response.headers["ETag"]

    post favorite_path(paintings(:woodcut))
    assert_response :success

    get painting_path(paintings(:woodcut)), headers: { "HTTP_IF_NONE_MATCH" => etag }

    assert_response :success, "the kept mark should invalidate the prior ETag, not 304 over it"
    assert_select "turbo-frame#keep_#{paintings(:woodcut).id} button[aria-pressed=?]", "true"
  end
end
