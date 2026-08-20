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

  test "selectable_paintings still excludes exactly the paintings that already have a day" do
    taken_ids = DailyPick.pluck(:painting_id)
    expected_ids = Painting.where.not(id: taken_ids).pluck(:id).sort

    assert_equal expected_ids, DailyPick.selectable_paintings.map(&:id).sort
  end

  # Story 0023 — DailyPick.auto_fill!. Each test isolates the eligible pool
  # to a couple of dedicated `auto_*` fixtures (test/fixtures/paintings.yml)
  # so the ladder's outcome is exact rather than a coin flip against every
  # other painting in the suite.
  test "auto_fill! tops the queue to the horizon and does nothing on a second run the same day" do
    isolate_pool_to(paintings(:auto_filler_1), paintings(:auto_filler_2))

    DailyPick.auto_fill!(horizon: 2)

    assert_equal [ Date.current, Date.current + 1 ], DailyPick.order(:scheduled_on).pluck(:scheduled_on)
    assert DailyPick.all.all? { |pick| pick.auto_tier == 1 }

    assert_no_difference -> { DailyPick.count } do
      DailyPick.auto_fill!(horizon: 2)
    end
  end

  test "auto_fill! never touches an existing hand pick and fills the other open day around it" do
    isolate_pool_to(paintings(:auto_filler_1), paintings(:auto_filler_2))
    hand = DailyPick.create!(painting: paintings(:auto_filler_1), scheduled_on: Date.current + 1,
      blurb: "A hand-written note.")

    DailyPick.auto_fill!(horizon: 2)

    assert_equal hand, DailyPick.find_by(scheduled_on: Date.current + 1)
    assert_nil hand.reload.auto_tier

    today_pick = DailyPick.find_by(scheduled_on: Date.current)
    assert_equal paintings(:auto_filler_2), today_pick.painting
    assert_equal 1, today_pick.auto_tier
  end

  test "auto_fill! skips a candidate with no image and does not force-insert it" do
    isolate_pool_to(paintings(:auto_no_image), paintings(:auto_filler_1))

    DailyPick.auto_fill!(horizon: 1)

    assert_equal paintings(:auto_filler_1), DailyPick.find_by(scheduled_on: Date.current).painting
  end

  test "auto_fill! relaxes the ladder for a repeated artist within the window and stamps the tier" do
    isolate_pool_to(paintings(:auto_repeat_artist_1), paintings(:auto_repeat_artist_2))

    DailyPick.auto_fill!(horizon: 2)

    picks = DailyPick.order(:scheduled_on).to_a
    assert_equal 1, picks.first.auto_tier
    assert_equal 4, picks.second.auto_tier
    assert_equal Set[paintings(:auto_repeat_artist_1), paintings(:auto_repeat_artist_2)],
      picks.map(&:painting).to_set
  end

  test "auto_fill! relaxes past the culture rule when only one culture is left, and stamps tier 2" do
    isolate_pool_to(paintings(:auto_shared_culture_1), paintings(:auto_shared_culture_2))

    DailyPick.auto_fill!(horizon: 2)

    picks = DailyPick.order(:scheduled_on).to_a
    assert_equal 1, picks.first.auto_tier
    assert_equal 2, picks.second.auto_tier
  end

  test "auto_fill! spaces deny-listed placeholder artists by their raw name, not a nil slug" do
    isolate_pool_to(paintings(:auto_placeholder_artist_1), paintings(:auto_placeholder_artist_2))
    assert_nil paintings(:auto_placeholder_artist_1).artist_slug
    assert_nil paintings(:auto_placeholder_artist_2).artist_slug

    DailyPick.auto_fill!(horizon: 2)

    picks = DailyPick.order(:scheduled_on).to_a
    assert_equal 1, picks.first.auto_tier,
      "two placeholder-attributed works should still count as a repeated artist"
    assert_equal 4, picks.second.auto_tier
  end

  test "auto_fill! never excludes or is excluded by a work with no attribution at all" do
    isolate_pool_to(paintings(:auto_blank_artist_1), paintings(:auto_blank_artist_2))

    DailyPick.auto_fill!(horizon: 2)

    assert DailyPick.all.all? { |pick| pick.auto_tier == 1 },
      "blank-attribution works should never force the ladder to relax"
  end

  test "auto_fill! stops and logs when the eligible pool is exhausted, without raising" do
    isolate_pool_to(paintings(:auto_filler_1))

    assert_nothing_raised { DailyPick.auto_fill!(horizon: 3) }

    assert_equal 1, DailyPick.count
    assert_equal Date.current, DailyPick.first.scheduled_on
  end

  # Code review, testing specialist: the ladder tests above only ever
  # exercise tier 1 and tier 4 — a conflict inside a 1-2 day gap never lands
  # in tier 3's 7-day window. This pins tier 3 specifically: a repeat artist
  # 10 days out is still inside tier 1/2's 30-day window (blocked) but
  # outside tier 3's 7-day window (allowed).
  test "auto_fill! relaxes to tier 3 when the only conflict is more than 7 but within 30 days" do
    isolate_pool_to(paintings(:auto_repeat_artist_1), paintings(:auto_repeat_artist_2))
    target = Date.current + 10
    DailyPick.create!(painting: paintings(:auto_repeat_artist_1), scheduled_on: target - 10, blurb: "A note.")

    assert DailyPick.send(:fill_one!, target)

    pick = DailyPick.find_by(scheduled_on: target)
    assert_equal 3, pick.auto_tier
    assert_equal paintings(:auto_repeat_artist_2), pick.painting
  end

  # Code review, testing specialist: every other test passes an explicit
  # horizon, so the literal default (7, the value FillQueueJob actually
  # runs with) is never itself exercised.
  test "auto_fill!'s default horizon fills exactly 7 days" do
    isolate_pool_to(
      paintings(:auto_repeat_artist_1), paintings(:auto_repeat_artist_2),
      paintings(:auto_shared_culture_1), paintings(:auto_shared_culture_2),
      paintings(:auto_placeholder_artist_1), paintings(:auto_placeholder_artist_2),
      paintings(:auto_blank_artist_1), paintings(:auto_blank_artist_2)
    )

    DailyPick.auto_fill!

    assert_equal (Date.current...(Date.current + 7)).to_a, DailyPick.order(:scheduled_on).pluck(:scheduled_on)
  end

  # `fill_one!`'s `RecordNotUnique` rescue (the exists?-check fixed by code
  # review, adversarial finding #2) has no direct test, and that gap is
  # deliberate, not missed: Rails' own uniqueness validation always runs a
  # SELECT before every INSERT, so within one connection a duplicate
  # `scheduled_on` or `painting_id` is caught as `RecordInvalid` before the
  # DB constraint that raises `RecordNotUnique` is ever reached — confirmed
  # by trying to provoke it directly while writing this suite. The real
  # trigger is two Solid Queue runs racing on two different connections at
  # once, which this suite's transactional fixtures (one connection, rolled
  # back per test) cannot construct, and no other test in this codebase
  # attempts cross-connection concurrency either. `test/models/favorite_test.rb`
  # proves the DB-level constraint itself fires (`save(validate: false)`
  # bypasses the validation that would otherwise mask it) — this method's
  # decision logic once that exception arrives is what's unverified.

  test "a machine pick's tier clears when the curator swaps its painting" do
    isolate_pool_to(paintings(:auto_filler_1), paintings(:auto_filler_2))
    DailyPick.auto_fill!(horizon: 1)
    pick = DailyPick.find_by(scheduled_on: Date.current)
    assert_equal 1, pick.auto_tier

    # Random candidate order means the fill could have landed on either
    # fixture — swap to whichever one it did NOT land on, or the update is a
    # no-op and `painting_id_changed?` never fires.
    other = [ paintings(:auto_filler_1), paintings(:auto_filler_2) ] - [ pick.painting ]
    pick.update!(painting: other.first)

    assert_nil pick.reload.auto_tier
  end

  test "a machine pick's tier clears when the curator moves its date" do
    isolate_pool_to(paintings(:auto_filler_1))
    DailyPick.auto_fill!(horizon: 1)
    pick = DailyPick.find_by(scheduled_on: Date.current)

    pick.update!(scheduled_on: Date.current + 5)

    assert_nil pick.reload.auto_tier
  end

  test "a machine pick's tier survives a blurb edit" do
    isolate_pool_to(paintings(:auto_filler_1))
    DailyPick.auto_fill!(horizon: 1)
    pick = DailyPick.find_by(scheduled_on: Date.current)

    pick.update!(blurb: "The curator's own note, added after the fact.")

    assert_equal 1, pick.reload.auto_tier
  end

  test "days_scheduled_ahead and scheduled_through report the buffer's depth" do
    isolate_pool_to(paintings(:auto_filler_1), paintings(:auto_filler_2))

    assert_equal 0, DailyPick.days_scheduled_ahead
    assert_nil DailyPick.scheduled_through

    DailyPick.auto_fill!(horizon: 2)

    assert_equal 2, DailyPick.days_scheduled_ahead
    assert_equal Date.current + 1, DailyPick.scheduled_through
  end

  # Code review, adversarial finding #1: this predicate is the fix — both
  # today being scheduled AND the buffer meeting LOW_BUFFER_DAYS are
  # required, not just one or the other.
  test "queue_healthy? requires both today scheduled and a full buffer" do
    assert DailyPick.queue_healthy?(today_scheduled: true, days_ahead: DailyPick::LOW_BUFFER_DAYS)
    assert_not DailyPick.queue_healthy?(today_scheduled: false, days_ahead: 30)
    assert_not DailyPick.queue_healthy?(today_scheduled: true, days_ahead: DailyPick::LOW_BUFFER_DAYS - 1)
    assert_not DailyPick.queue_healthy?(today_scheduled: false, days_ahead: 0)
  end

  private

  # Clears the board down to exactly the paintings a test wants to reason
  # about, so the ladder's outcome is exact rather than a coin flip against
  # every other eligible painting fixtures load for the whole suite.
  def isolate_pool_to(*keepers)
    DailyPick.delete_all
    Favorite.delete_all
    Painting.where.not(id: keepers.map(&:id)).delete_all
  end
end
