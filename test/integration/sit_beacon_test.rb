require "test_helper"

# The identity-free tally (story 0032, eng OV6). The whole contract: two
# event names, one row per date, and a response that carries nothing —
# no body, no cookie, no cache permission.
class SitBeaconTest < ActionDispatch::IntegrationTest
  test "shown and completed each land on today's row" do
    post sit_beacon_path(event: "shown")
    assert_response :no_content
    post sit_beacon_path(event: "shown")
    post sit_beacon_path(event: "completed")

    row = SitCounter.find_by!(date: Date.current)
    assert_equal [ 2, 1 ], [ row.shown, row.completed ]
  end

  test "the beacon mints no session and allows no caching" do
    post sit_beacon_path(event: "shown")
    assert_nil response.headers["Set-Cookie"]
    assert_includes response.headers["Cache-Control"], "no-store"
  end

  test "an unknown event never reaches the controller — the route constraint eats it" do
    post "/sit/clicked"
    assert_response :not_found
    assert_equal 0, SitCounter.count
  end

  # The suite runs with forgery protection off, which would let a missing
  # `skip_forgery_protection` ship green and then 422 every real beacon —
  # the public page renders no CSRF meta by design (story 0007), so the
  # browser has no token to send. Turn real protection on and prove the
  # skip carries the request (code review C17; the plan's deviation note
  # calls this line load-bearing).
  test "the beacon lands with forgery protection on and no token — as in production" do
    original = ActionController::Base.allow_forgery_protection
    ActionController::Base.allow_forgery_protection = true

    post sit_beacon_path(event: "shown")
    assert_response :no_content
    assert_equal 1, SitCounter.find_by!(date: Date.current).shown
  ensure
    ActionController::Base.allow_forgery_protection = original
  end
end
