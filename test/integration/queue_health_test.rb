require "test_helper"

# The dead man's switch (story 0021) — the one detector for a scheduler that
# stopped running silently. Public and unwalled: an uptime monitor has no
# reader identity and is not a modern browser, so this controller inherits
# ActionController::Base directly, the same pattern PagesController set.
class QueueHealthTest < ActionDispatch::IntegrationTest
  test "reports healthy when today is scheduled and the buffer holds at least two more days" do
    get queue_health_path

    assert_response :success
    assert_match(/^ok — scheduled through #{Regexp.escape(daily_picks(:tomorrow).scheduled_on.to_s)}/, response.body)
    assert_equal "no-store", response.headers["Cache-Control"]
  end

  test "reports unhealthy when today has not been scheduled" do
    daily_picks(:today).destroy!

    get queue_health_path

    assert_response :service_unavailable
    assert_match(/today NOT scheduled/, response.body)
  end

  test "reports unhealthy when fewer than two future days are buffered" do
    daily_picks(:tomorrow).destroy!

    get queue_health_path

    assert_response :service_unavailable
    assert_match(/today scheduled, 1 day\(s\) ahead/, response.body)
  end

  test "is reachable with no reader identity at all — no wall, no basic auth" do
    get queue_health_path

    assert_response :success
  end
end
