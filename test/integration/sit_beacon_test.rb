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
end
