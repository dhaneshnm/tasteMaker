require "test_helper"

# The reader's own corner (story 0017). Four states, one page, and the four
# tests that used to live in `sessions_test.rb` against the fragment this
# replaced.
#
# The load-bearing one is the UNREGISTERED SHELL. `SessionsController#control`
# checked `native_shell? || current_device` and rendered an empty frame, and the
# user-agent half existed because a shell whose registration failed or is still
# in flight has no device cookie — so a cookie-only check would drop it into the
# signed-out branch and paint Google buttons inside the app. Google answers an
# embedded web view with `403 disallowed_useragent`, so those buttons are not
# merely wrong, they are dead. That trap survives the move to a whole page and
# is why `:shell` is a state of its own rather than a hole in `:device`.
class CornersTest < ActionDispatch::IntegrationTest
  test "the corner is unwalled, because it is where the wall sends people" do
    get corner_path

    assert_response :success
    assert_select ".signin__door", count: 2
  end

  test "the corner is private and never stored" do
    get corner_path

    assert_includes response.headers["Cache-Control"], "no-store"
    assert_includes response.headers["Cache-Control"], "private"
    assert_equal "Cookie", response.headers["Vary"]
  end

  # Three of the four destinations are behind the wall that just bounced this
  # visitor here. Shown and unlinked they read as gated; shown and linked they
  # read as broken, because every tap lands back on this page.
  test "a signed-out visitor sees which doors are shut" do
    get corner_path

    assert_select ".compass .caps-link", count: 4
    assert_select ".compass a.caps-link[href=?]", root_path, text: "Today"
    assert_select ".compass a.caps-link", count: 1, message: "only Today should still be a link"
    assert_select "span.compass__here", count: 3
    # `aria-current` says "you are standing here", which is false for all three.
    assert_select "span.compass__here[aria-current]", count: 0
  end

  test "a signed-in reader gets their account and both of its controls" do
    user = sign_in

    get corner_path

    assert_select ".coda__line", text: "Kept with your account."
    assert_match user.email, response.body
    assert_select "form[action=?]", session_path
    assert_select "form[action=?]", account_path
    assert_select ".signin__door", count: 0
    # The compass is whole for a reader who can open all of it.
    assert_select ".compass a.caps-link", count: 4
  end

  test "a registered device gets its own room and no sign-in doors" do
    register_device

    get corner_path

    assert_select ".signin__door", count: 0,
      message: "Google answers an embedded web view with 403; these buttons cannot work in the shell"
    assert_select "form[action=?]", device_path
    assert_select "form[action=?]", account_path, count: 0
  end

  test "a device with nothing kept is invited, not warned" do
    register_device

    get corner_path

    assert_select ".coda__line--ask", text: "Nothing is kept on this phone yet."
  end

  test "a device that has kept works is told what that means" do
    token = register_device
    Favorite.create!(painting: paintings(:sunflowers),
      collector_digest: Device.digest(token))

    get corner_path

    assert_select ".coda__line--ask", /1 work is kept on this phone/
    assert_select "form[action=?]", device_path
  end

  # The state that has no cookie and no row. It must not claim to hold works it
  # does not have, and it must not offer a delete button — `DevicesController`
  # answers that with a silent redirect when `current_device` is nil.
  test "an UNREGISTERED shell is told it is still setting up, and offered nothing" do
    get corner_path,
      headers: { "User-Agent" => "#{ApplicationController::NATIVE_UA_TOKEN}; Mozilla/5.0" }

    assert_response :success
    assert_select ".signin__door", count: 0
    assert_select "form[action=?]", device_path, count: 0
    assert_select "form[action=?]", account_path, count: 0
    assert_select ".coda__line--ask", text: "This phone is still settling in."
  end

  # Regression: the unregistered shell got four live compass links that all
  # bounced back here. `locked:` was derived from the view's own state enum
  # (`@state == :signed_out`) rather than from the wall's predicate, so the one
  # state this story added a whole branch for rendered exactly the dead-control
  # loop `locked:` exists to prevent. Measured before the fix: 4 links, 0 locked.
  #
  # The signed-out web reader is covered above; this is the state that was
  # broken. `locked:` now comes from `identified?`, so the two answer alike.
  # Found by /simplify on 2026-08-17.
  test "the UNREGISTERED shell sees the shut doors too" do
    get corner_path,
      headers: { "User-Agent" => "#{ApplicationController::NATIVE_UA_TOKEN}; Mozilla/5.0" }

    assert_select ".compass a.caps-link", count: 1,
      message: "only Today should be a link for a shell with no device row"
    assert_select "span.compass__here", count: 3,
      message: "Days, Kept and Gallery must read as gated, not broken"
  end

  # The mark rides the bar on every screen that has one, and on the corner
  # itself it loses its link the way the compass marks the page you are on.
  test "the corner mark is a link everywhere but here" do
    get root_path
    assert_select "a.masthead__you[href=?]", corner_path

    get corner_path
    assert_select "a.masthead__you", count: 0
    assert_select "span.masthead__you--here[aria-current=page]", count: 1
  end

  # `PagesController` inherits ActionController::Base, so `current_user`,
  # `current_device` and `native_shell?` are all undefined there. The mark must
  # be pure view logic or these two pages 500 — and they are the two App Review
  # fetches anonymously.
  test "the mark renders on the pages that have no application helpers" do
    [ privacy_path, support_path ].each do |path|
      get path

      assert_response :success, "#{path} broke"
      assert_select "a.masthead__you[href=?]", corner_path
    end
  end
end
