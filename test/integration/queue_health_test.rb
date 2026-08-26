require "test_helper"

# The dead man's switch (story 0023) — the one detector for a scheduler that
# stopped running silently. Public and unwalled: an uptime monitor has no
# reader identity and is not a modern browser, so this controller inherits
# ActionController::Base directly, the same pattern PagesController set.
class QueueHealthTest < ActionDispatch::IntegrationTest
  # Every test in this file is otherwise wall-clock-independent, but story
  # 0010's grace window (push_ok?) genuinely depends on what time it is —
  # a suite run after 12:15pm ET would otherwise see every unrelated test
  # below fail on "the noon knock never fired", which is true but not what
  # any of them are testing. Pinned once for the whole file (/simplify,
  # simplification finding — five identical per-test travel_to wraps
  # collapsed to one); tests that specifically need noon override it with
  # their own nested travel_to.
  def eastern_clock(hour, minute)
    Time.zone.local(Date.current.year, Date.current.month, Date.current.day, hour, minute)
  end

  setup { travel_to eastern_clock(6, 0) }
  teardown { travel_back }

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

  # Code review, adversarial finding #1: a depth-only check would read
  # "healthy" here — the buffer has plenty of days — even though TODAY
  # itself has no pick and the front door is serving yesterday's painting.
  # `DailyPick.queue_healthy?` requires both; this pins that both are still
  # required after the admin page's own check was found to only ask one.
  test "reports unhealthy when today is missing even with a full buffer of future days" do
    daily_picks(:today).destroy!
    publish_day(Date.current + 2)
    publish_day(Date.current + 3)

    get queue_health_path

    assert_response :service_unavailable
    assert_match(/today NOT scheduled/, response.body)
  end

  test "is reachable with no reader identity at all — no wall, no basic auth" do
    get queue_health_path

    assert_response :success
  end

  # Story 0010, eng review outside voice #4: a Kamal deploy replacing the
  # container across the noon tick skips the recurring schedule with no
  # catch-up and no Sentry event — before this, nothing watched for it.
  test "before the grace window, an unnotified today still reads healthy" do
    travel_to eastern_clock(12, 0) do
      get queue_health_path

      assert_response :success
    end
  end

  test "after the grace window, an unnotified today reads unhealthy" do
    travel_to eastern_clock(12, 16) do
      get queue_health_path

      assert_response :service_unavailable
      assert_match(/noon knock never fired/, response.body)
    end
  end

  test "after the grace window, a notified today reads healthy" do
    daily_picks(:today).update_column(:notified_at, Time.current)

    travel_to eastern_clock(12, 16) do
      get queue_health_path

      assert_response :success
    end
  end

  # A day with zero opted-in devices legitimately stamps push_sent_count 0 —
  # that must not read as unhealthy. push_ok? deliberately checks only
  # notified_at, never push_sent_count.
  test "a notified today with zero devices sent to still reads healthy" do
    daily_picks(:today).update!(notified_at: Time.current, push_sent_count: 0)

    travel_to eastern_clock(12, 16) do
      get queue_health_path

      assert_response :success
    end
  end

  test "the grace window never fires when today has no pick at all" do
    daily_picks(:today).destroy!

    travel_to eastern_clock(12, 16) do
      get queue_health_path

      assert_response :service_unavailable
      assert_match(/today NOT scheduled/, response.body,
        "the ordinary 'today missing' message must win — not the push one")
    end
  end
end
