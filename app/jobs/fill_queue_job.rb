# Thin shell — all logic stays on DailyPick where the console and tests can
# reach it without queue plumbing. Runs daily via config/recurring.yml.
class FillQueueJob < ApplicationJob
  queue_as :default

  def perform
    DailyPick.auto_fill!
  end
end
