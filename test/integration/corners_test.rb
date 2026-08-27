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
  # The sign-in doors, and the version gate that decides whether they exist
  # (story 0017 Release 2).
  #
  # Rails deploys in seconds; binaries update on the reader's schedule. The
  # version and the auth bridge ship in the SAME binary, so a shell that sends
  # no version is one built before the transport existed — and a door there
  # navigates the web view to Google, which answers an embedded view with 403.
  # Presence of the version is the whole test.
  OLD_SHELL = "#{ApplicationController::NATIVE_UA_TOKEN}; Mozilla/5.0".freeze
  NEW_SHELL = "#{ApplicationController::NATIVE_UA_TOKEN}/1.1; Mozilla/5.0".freeze

  test "a device on a shell with no version gets no doors" do
    register_device

    get corner_path, headers: { "User-Agent" => OLD_SHELL }

    assert_select ".signin__door", count: 0,
      message: "an older binary has no bridge behind the button"
    assert_select "form[action=?]", device_path
  end

  test "a device on a versioned shell gets doors, as links the shell can intercept" do
    register_device

    get corner_path, headers: { "User-Agent" => NEW_SHELL }

    assert_select "a.signin__door[href=?]", auth_start_path("google_oauth2")
    assert_select "a.signin__door[href=?]", auth_start_path("apple")
    # Links, not forms: the shell's route decision handler matches a navigation
    # and cannot match a form submit.
    assert_select "form.signin__door", count: 0
  end

  test "the web reader keeps forms, because OmniAuth's request phase is POST-only" do
    get corner_path

    assert_select "form[action=?][method=post]", "/auth/google_oauth2"
    assert_select "a.signin__door", count: 0
  end

  # An unregistered shell has no row to claim into and registration retries on
  # the next foreground. "Not ready" is truer than a door.
  test "an unregistered shell gets no doors even on a versioned binary" do
    get corner_path, headers: { "User-Agent" => NEW_SHELL }

    assert_select ".signin__door", count: 0
    assert_select ".coda__line--ask", text: "This phone is still settling in."
  end

  test "a versioned shell holding works is told what signing in costs" do
    token = register_device
    Favorite.create!(painting: paintings(:sunflowers), collector_digest: Device.digest(token))

    get corner_path, headers: { "User-Agent" => NEW_SHELL }

    assert_select ".coda__note", /stop belonging to this\s+phone/
  end

  # ---- the daily knock (story 0010) ----------------------------------------
  #
  # A shell WITH a version but below the push threshold — literally the 1.0
  # binary sitting in App Store review, no push code inside it at all
  # (eng review finding 5). `NEW_SHELL` above is already exactly 1.1, so it
  # doubles as the push-capable fixture for the tests below.
  PRE_PUSH_SHELL = "#{ApplicationController::NATIVE_UA_TOKEN}/1.0; Mozilla/5.0".freeze

  test "a push-capable shell with no token gets the invitation" do
    register_device

    get corner_path, headers: { "User-Agent" => NEW_SHELL }

    assert_select "a.push__enable[href=?]", push_enable_path
    assert_select "form[action=?]", push_registration_path, count: 0
  end

  test "a push-capable shell that already opted in gets the off switch" do
    register_device
    register_push(mode: "enroll", apns_token: "a" * 64)

    get corner_path, headers: { "User-Agent" => NEW_SHELL }

    assert_select "form[action=?][method=post]", push_registration_path do
      assert_select "input[name=_method][value=delete]"
    end
    assert_select "a.push__enable", count: 0
  end

  test "the 1.0 binary in App Store review sees no push section at all" do
    register_device

    get corner_path, headers: { "User-Agent" => PRE_PUSH_SHELL }

    assert_select "a.push__enable", count: 0
    assert_select "form[action=?]", push_registration_path, count: 0
  end

  test "a browser gets no push section regardless of state" do
    get corner_path

    assert_select "a.push__enable", count: 0
  end

  test "an unregistered shell gets no push section — there is no row to hold a token" do
    get corner_path, headers: { "User-Agent" => NEW_SHELL }

    assert_select "a.push__enable", count: 0
    assert_select "form[action=?]", push_registration_path, count: 0
  end

  # Device-scoped, not identity-scoped (CornersController's own comment):
  # a signed-in reader on this same phone still owns whatever the Device
  # row's apns_token says.
  test "a signed-in reader on a push-capable phone still sees the toggle" do
    register_device
    register_push(mode: "enroll", apns_token: "a" * 64)
    sign_in

    get corner_path, headers: { "User-Agent" => NEW_SHELL }

    assert_select "form[action=?]", push_registration_path
  end
end
