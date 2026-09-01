require "test_helper"

# The reader's one line (story 0032): ink, stripped, bounded, write-once.
class ImpressionTest < ActiveSupport::TestCase
  setup do
    @user = User.create!(provider: "google_oauth2", uid: "impression-uid",
                         email: "reader@example.com")
    @painting = paintings(:sunflowers)
  end

  test "a stripped, bounded line saves" do
    impression = @user.impressions.create!(painting: @painting,
                                           body: "  the yellows hum  \n")
    assert_equal "the yellows hum", impression.body
  end

  test "whitespace alone cannot dodge the presence check" do
    impression = @user.impressions.build(painting: @painting, body: "   \n ")
    assert_not impression.valid?
    assert_includes impression.errors[:body], "Write something first."
  end

  test "281 characters is one too many" do
    assert_not @user.impressions.build(painting: @painting, body: "a" * 281).valid?
    assert @user.impressions.build(painting: @painting, body: "a" * 280).valid?
  end

  test "one row per painting per reader — the index is identity, not immutability" do
    @user.impressions.create!(painting: @painting, body: "first")
    # The draft moves by UPDATING that row (autosave, 2026-09-01 amendment);
    # a second row for the same painting stays invalid.
    second = @user.impressions.build(painting: @painting, body: "second thoughts")
    assert_not second.valid?
  end

  test "the day's prompt rotates deterministically and covers the whole set" do
    prompts = (0...DailyPick::SIT_PROMPTS.size).map do |offset|
      DailyPick.new(scheduled_on: Date.new(2026, 9, 1) + offset).sit_prompt
    end
    assert_equal DailyPick::SIT_PROMPTS.sort, prompts.sort,
      "consecutive days must cycle through every prompt exactly once"
    assert_equal DailyPick.new(scheduled_on: Date.new(2026, 9, 1)).sit_prompt,
                 DailyPick.new(scheduled_on: Date.new(2026, 9, 1)).sit_prompt
  end

  test "two readers may each keep a line on the same painting" do
    @user.impressions.create!(painting: @painting, body: "mine")
    other = User.create!(provider: "google_oauth2", uid: "other-uid",
                         email: "other@example.com")
    assert other.impressions.create!(painting: @painting, body: "theirs").persisted?
  end

  test "deleting the account takes the lines with it" do
    @user.impressions.create!(painting: @painting, body: "gone with me")
    assert_difference("Impression.count", -1) { @user.destroy }
  end
end
