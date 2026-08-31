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
    assert_includes impression.errors[:body], "can't be blank"
  end

  test "281 characters is one too many" do
    assert_not @user.impressions.build(painting: @painting, body: "a" * 281).valid?
    assert @user.impressions.build(painting: @painting, body: "a" * 280).valid?
  end

  test "write-once per painting per reader — ink, not pencil" do
    @user.impressions.create!(painting: @painting, body: "first")
    second = @user.impressions.build(painting: @painting, body: "second thoughts")
    assert_not second.valid?
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
