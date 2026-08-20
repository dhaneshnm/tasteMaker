require "test_helper"
require "fugit"

# Proves config/recurring.yml is syntactically wired to a real job — it does
# NOT prove the Solid Queue supervisor actually fires it (story 0023 plan,
# step 4: that is a production-only check, held by the next-morning receipt
# and /queue-health, not by this test).
class RecurringScheduleTest < ActiveSupport::TestCase
  test "the daily fill task resolves to a real ActiveJob and parses as a cron schedule" do
    config = YAML.load(ERB.new(File.read(Rails.root.join("config/recurring.yml"))).result, aliases: true)
    task = config.dig("production", "fill_daily_pick_queue")

    assert task, "config/recurring.yml has no fill_daily_pick_queue task under production"

    job_class = task["class"].constantize
    assert_operator job_class, :<, ActiveJob::Base

    parsed = Fugit.parse(task["schedule"])
    assert_kind_of Fugit::Cron, parsed
    assert_equal "America/New_York", parsed.zone
  end
end
