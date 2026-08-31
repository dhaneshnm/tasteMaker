require "test_helper"

# The gate's tally (story 0032): one row per date, race-safe upsert, and a
# vocabulary of exactly two events.
class SitCounterTest < ActiveSupport::TestCase
  test "first bump creates today's row" do
    SitCounter.bump!("shown")
    row = SitCounter.find_by!(date: Date.current)
    assert_equal [ 1, 0 ], [ row.shown, row.completed ]
  end

  test "bumps accumulate independently on one row" do
    3.times { SitCounter.bump!("shown") }
    1.times { SitCounter.bump!("completed") }
    row = SitCounter.find_by!(date: Date.current)
    assert_equal [ 3, 1 ], [ row.shown, row.completed ]
    assert_equal 1, SitCounter.count
  end

  test "an unknown event is a silent no-op, never an error" do
    assert_nothing_raised { SitCounter.bump!("clicked") }
    assert_nothing_raised { SitCounter.bump!(nil) }
    assert_equal 0, SitCounter.count
  end
end
