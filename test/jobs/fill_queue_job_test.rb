require "test_helper"

class FillQueueJobTest < ActiveSupport::TestCase
  test "performing the job fills the queue the same way calling auto_fill! directly does" do
    DailyPick.delete_all
    Favorite.delete_all
    Painting.where.not(id: paintings(:auto_filler_1).id).delete_all

    FillQueueJob.perform_now

    assert_equal paintings(:auto_filler_1), DailyPick.find_by(scheduled_on: Date.current).painting
  end
end
