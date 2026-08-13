require "test_helper"

class DailyPickTest < ActiveSupport::TestCase
  test "the application clock is Eastern" do
    assert_equal "America/New_York", Time.zone.name
  end

  test "current is today's pick" do
    assert_equal daily_picks(:today), DailyPick.current
  end

  test "current falls back to the last published day when today was missed" do
    daily_picks(:today).destroy!

    assert_equal daily_picks(:yesterday), DailyPick.current
  end

  test "current never reaches into the queue" do
    daily_picks(:today).destroy!
    daily_picks(:yesterday).destroy!

    assert_nil DailyPick.current, "tomorrow's pick leaked onto the page"
  end

  test "a queued pick appears the moment the Eastern day turns, not before" do
    DailyPick.delete_all
    pick = DailyPick.create!(
      painting: paintings(:sunflowers),
      scheduled_on: Date.new(2026, 8, 4),
      blurb: "A note."
    )

    # 23:00 Eastern on August 3 is already August 4 in UTC — the pick must wait.
    travel_to Time.utc(2026, 8, 4, 3, 0) do
      assert_equal Date.new(2026, 8, 3), Date.current
      assert_nil DailyPick.current
    end

    travel_to Time.utc(2026, 8, 4, 4, 1) do
      assert_equal Date.new(2026, 8, 4), Date.current
      assert_equal pick, DailyPick.current
    end
  end

  test "a day holds exactly one artwork" do
    duplicate = DailyPick.new(
      painting: paintings(:woodcut),
      scheduled_on: daily_picks(:today).scheduled_on,
      blurb: "A note."
    )

    assert_not duplicate.valid?
    assert_includes duplicate.errors.full_messages.join, "already has an artwork scheduled"
  end

  test "an artwork gets one day, ever" do
    repeat = DailyPick.new(
      painting: daily_picks(:today).painting,
      scheduled_on: 1.week.from_now.to_date,
      blurb: "A note."
    )

    assert_not repeat.valid?
    assert_includes repeat.errors.full_messages.join, "already had its day"
  end

  # The note is optional, but the day still has to say something.
  test "a day with no note borrows the museum's words, and says whose they are" do
    pick = DailyPick.new(painting: paintings(:woodcut), scheduled_on: 1.week.from_now.to_date)

    assert_predicate pick, :valid?
    assert_not_predicate pick, :hand_written?
    assert_equal paintings(:woodcut).description, pick.note
  end

  test "a blank note is stored as nothing at all, not as an empty string" do
    pick = daily_picks(:today)

    pick.update!(blurb: "  \n ")

    assert_nil pick.reload.blurb
    assert_not_predicate pick, :hand_written?
  end

  test "asking an unsaved pick what it says does not blow up" do
    assert_nothing_raised { DailyPick.new.note }
  end

  test "a note the curator wrote is the curator's, and nothing is borrowed" do
    pick = daily_picks(:today)

    assert_predicate pick, :hand_written?
    assert_equal pick.blurb, pick.note
  end

  test "a day with neither a note nor museum text is not a day" do
    wordless = Painting.create!(source: "mia", source_id: 930_001, title: "No Words At All",
      image_url_800: paintings(:woodcut).image_url_800, image_width: 800, image_height: 1000)
    pick = DailyPick.new(painting: wordless, scheduled_on: 1.week.from_now.to_date)

    assert_not pick.valid?
    assert_includes pick.errors[:blurb].join, "no museum text to fall back on"
  end

  test "a painting with no picture cannot be scheduled" do
    pick = DailyPick.new(
      painting: paintings(:imageless),
      scheduled_on: 1.week.from_now.to_date,
      blurb: "A note."
    )

    assert_not pick.valid?
    assert_includes pick.errors[:painting], "has no usable image"
  end

  test "first_open_date skips days already spoken for and never looks backwards" do
    DailyPick.delete_all

    assert_equal Date.current, DailyPick.first_open_date

    DailyPick.create!(painting: paintings(:sunflowers), scheduled_on: Date.current, blurb: "A note.")
    DailyPick.create!(painting: paintings(:harbour), scheduled_on: Date.current + 1, blurb: "A note.")
    # A gap in the past must not be offered.
    DailyPick.create!(painting: paintings(:bronze), scheduled_on: Date.current - 5, blurb: "A note.")

    assert_equal Date.current + 2, DailyPick.first_open_date
  end

  test "published? tracks the Eastern day, not the queue" do
    assert_predicate daily_picks(:today), :published?
    assert_predicate daily_picks(:yesterday), :published?
    assert_not_predicate daily_picks(:tomorrow), :published?
  end

  test "the walk steps over a gap rather than into it" do
    older = DailyPick.create!(painting: paintings(:woodcut), scheduled_on: Date.current - 4,
      blurb: "Four days back, with nothing scheduled in between.")
    yesterday = daily_picks(:yesterday)

    assert_equal older, yesterday.previous_published
    assert_equal daily_picks(:today), yesterday.next_published
  end

  test "the walk stops at the ends and never steps into the queue" do
    oldest = daily_picks(:yesterday)
    newest = daily_picks(:today)

    assert_nil oldest.previous_published
    assert_nil newest.next_published, "tomorrow is queued, so today has nowhere forward to go"
  end

  test "blurb_word_count counts what the curator wrote" do
    pick = DailyPick.new(blurb: "Three  little words")

    assert_equal 3, pick.blurb_word_count
  end
end
