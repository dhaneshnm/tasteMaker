require "test_helper"

class DaysTest < ActionDispatch::IntegrationTest
  # Story 0015 put the reader-facing pages behind the wall; these tests read
  # them the way the app does — as a registered device.
  setup { register_device }

  # Fixtures: today (sunflowers), yesterday (harbour), tomorrow (bronze, queued).
  setup do
    @today = daily_picks(:today)
    @yesterday = daily_picks(:yesterday)
    @tomorrow = daily_picks(:tomorrow)
  end

  # ---------- the list ----------

  test "the list holds the published days, newest first" do
    get days_path

    assert_response :success
    assert_select "li.days__day", count: 2
    titles = css_select("li.days__day .days__title").map(&:text)
    assert_equal [ paintings(:sunflowers).title, paintings(:harbour).title ], titles
  end

  test "the row for the day on the front door links to the front door" do
    get days_path

    assert_select "li.days__day:first-child .days__link[href=?]", root_path
    assert_select "li.days__day:first-child .days__date", text: /Today/
  end

  test "a queued day is absent from the list and its URL does not resolve" do
    get days_path
    assert_no_match paintings(:bronze).title, response.body

    get day_path(@tomorrow.scheduled_on.iso8601)
    assert_response :not_found
  end

  test "a day nobody ever published is a 404, not an error" do
    get day_path(3.days.ago.to_date.iso8601)
    assert_response :not_found
  end

  # Passes the route constraint, is not a real date. Must 404 rather than raise.
  test "a well-formed date that is not a real day is a 404" do
    get "/days/2026-02-31"
    assert_response :not_found
  end

  test "the list says so when nothing is published" do
    DailyPick.delete_all

    get days_path

    assert_response :success
    assert_select ".coda__line", text: "The days will collect here."
    assert_select "li.days__day", count: 0
  end

  test "one published day gets its own closing line" do
    @yesterday.destroy!

    get days_path

    assert_select "li.days__day", count: 1
    assert_select ".coda__line", text: /One day so far/
  end

  # The coda used to end with the ways out. Story 0012 moved those into the
  # compass, so past the first day this footer is an ornament and nothing else —
  # the way back is in the bar at the top, on this screen and every other one.
  test "more than one day, and the closing line has nothing left to say" do
    get days_path

    assert_select ".coda__line", count: 0
    assert_select ".coda .caps-link", count: 0
    assert_select ".compass a[href=?]", root_path, text: "Today"
  end

  test "months are headings, and they are there from the first row" do
    get days_path
    assert_select "h2.days__month", count: 1

    DailyPick.create!(painting: paintings(:woodcut), scheduled_on: 45.days.ago.to_date,
      blurb: "A month or so back, which puts this row under its own heading.")

    get days_path
    assert_select "h2.days__month", count: 2
  end

  # The year lives on the month heading, once, rather than on every row.
  test "a day from an earlier year is filed under a heading that says which year" do
    @yesterday.update!(scheduled_on: Date.current.beginning_of_year - 40)

    get days_path

    assert_select "h2.days__month", text: /#{Date.current.year - 1}/
  end

  test "rows are an ordered list and each link names the day, the work and the artist" do
    get days_path

    assert_select "ol.days > li.days__day"
    assert_select "a.days__link[aria-label=?]",
      "#{@yesterday.scheduled_on.to_fs(:daily_long)}: #{paintings(:harbour).title}, #{paintings(:harbour).artist}"
    assert_select ".days__thumb img[alt=?]", ""
  end

  test "a long title steps down instead of being cut" do
    paintings(:harbour).update!(title: "A" * 104)

    get days_path

    assert_select ".days__title.days__title--long", text: "A" * 104
  end

  # ---------- one day, one URL ----------

  test "the day the front door is showing redirects there" do
    get day_path(@today.scheduled_on.iso8601)
    assert_redirected_to root_path
  end

  # The model holds the previous pick over on a gap day, so the redirect follows
  # the pick on the front door, not the calendar.
  test "on a gap day the redirect follows the held-over pick, not today" do
    @today.destroy!
    assert_equal @yesterday, DailyPick.current

    get day_path(@yesterday.scheduled_on.iso8601)
    assert_redirected_to root_path

    # And the gap itself is simply not a page.
    get day_path(Date.current.iso8601)
    assert_response :not_found
  end

  test "a past day renders its own artwork, note and date" do
    get day_path(@yesterday.scheduled_on.iso8601)

    assert_response :success
    assert_select "h1.label__title", text: paintings(:harbour).title
    assert_select ".label__note", /open air/
    assert_select "time.masthead__aside[datetime=?]", @yesterday.scheduled_on.iso8601
    assert_select ".masthead__label", text: "From the archive"
    assert_select ".coda__line", count: 0
  end

  # ---------- the walk ----------

  test "a past day offers the neighbours it has, and none it does not" do
    get day_path(@yesterday.scheduled_on.iso8601)

    assert_select ".walk .caps-link", count: 1
    assert_select ".walk__step--next"
    assert_select ".walk .caps-link", text: /Previous day/, count: 0
  end

  test "the next day link skips the redirect and points at the front door" do
    get day_path(@yesterday.scheduled_on.iso8601)

    assert_select ".walk__step--next[href=?]", root_path
  end

  test "a day in the middle walks both ways, and the older neighbour is a real day page" do
    older = DailyPick.create!(painting: paintings(:woodcut), scheduled_on: 2.days.ago.to_date,
      blurb: "Two days back, so yesterday has something to step backwards to.")

    get day_path(@yesterday.scheduled_on.iso8601)

    assert_select ".walk .caps-link[href=?]", day_path(older.scheduled_on.iso8601), text: /Previous day/
    assert_select ".walk__step--next[href=?]", root_path
  end

  # The way home is offered once, not twice: on the day before the current pick,
  # "Next day →" already points at the front door, so a "Today →" beneath it
  # would be a second link to the same page one line down.
  test "the way back to today is offered once" do
    get day_path(@yesterday.scheduled_on.iso8601)

    assert_select ".walk__step--next[href=?]", root_path
    assert_select ".walk__today", count: 0
  end

  test "a day further back offers the way home separately" do
    older = DailyPick.create!(painting: paintings(:woodcut), scheduled_on: 2.days.ago.to_date,
      blurb: "Two days back, so the next day is not the front door and Today earns its link.")

    get day_path(older.scheduled_on.iso8601)

    assert_select ".walk__step--next[href=?]", day_path(@yesterday.scheduled_on.iso8601)
    assert_select ".walk__today[href=?]", root_path, text: /Today/
  end

  # ---------- caching ----------

  test "an unchanged list costs a 304, an edited blurb does not" do
    get days_path
    etag = response.headers["ETag"]
    assert_match "no-cache", response.headers["Cache-Control"]

    get days_path, headers: { "HTTP_IF_NONE_MATCH" => etag }
    assert_response :not_modified

    @yesterday.update!(blurb: "A completely different note, long enough to be a real one.")

    get days_path, headers: { "HTTP_IF_NONE_MATCH" => etag }
    assert_response :success
  end

  # The 304 path renders nothing, so an explicit `render` after it would be a
  # second response. Guarded with `stale?`; this is the test that says so.
  test "an unchanged past day costs a 304 and does not double-render" do
    get day_path(@yesterday.scheduled_on.iso8601)
    etag = response.headers["ETag"]
    assert_response :success

    get day_path(@yesterday.scheduled_on.iso8601), headers: { "HTTP_IF_NONE_MATCH" => etag }
    assert_response :not_modified

    @yesterday.update!(blurb: "An edited note, which must reach the reader immediately.")

    get day_path(@yesterday.scheduled_on.iso8601), headers: { "HTTP_IF_NONE_MATCH" => etag }
    assert_response :success
  end

  # The rows render painting title, artist and image — a different table with its
  # own timestamps. Keying on the picks alone would serve the old title forever.
  test "an edited painting busts the list's cache too" do
    get days_path
    etag = response.headers["ETag"]

    paintings(:harbour).update!(title: "Harbour at Dawn, retitled")

    get days_path, headers: { "HTTP_IF_NONE_MATCH" => etag }
    assert_response :success
    assert_select ".days__title", text: "Harbour at Dawn, retitled"
  end

  # ---------- the entry point ----------

  # The date used to be the door — a link, and only once a second day existed.
  # Story 0012 gave the archive a door with the word `Days` on it, present on
  # every screen from the first day, so the date went back to being a date.
  test "the front door's date is a date, not a door" do
    get root_path

    assert_select "time.masthead__aside a", count: 0
    assert_select "time.masthead__aside[datetime=?]", Date.current.iso8601
  end

  test "the archive door is on the front door from the very first day" do
    @yesterday.destroy!

    get root_path

    assert_select ".compass a[href=?]", days_path, text: "Days"
  end

  # This used to assert the opposite: the front door's ETag carried
  # `DailyPick.published.count`, because backfilling a past day left `current`
  # untouched while changing whether the date was a link, and a returning
  # visitor would otherwise have kept a 304 with no way into the archive.
  #
  # The compass took that condition away. Nothing on this page depends on how
  # many days exist any more, so the count came out of the key and a backfill is
  # exactly what it looks like: a change to a page this reader is not looking at.
  test "backfilling a past day leaves the front door alone, door and all" do
    @yesterday.destroy!

    get root_path
    etag = response.headers["ETag"]
    assert_select ".compass a[href=?]", days_path

    DailyPick.create!(painting: paintings(:woodcut), scheduled_on: 4.days.ago.to_date,
      blurb: "Backfilled after the fact, which no longer changes the front door.")

    get root_path, headers: { "HTTP_IF_NONE_MATCH" => etag }
    assert_response :not_modified
  end

  # ---------- the curator's preview ----------

  # The preview is the reader's page, compass and all — that is what makes it a
  # preview. It marks `Today` for the same reason the front door does. What it
  # does not get is the keep control, because the day is not published and a
  # curator keeping unpublished works would pollute the only usage signal that
  # feature has.
  test "a preview shows the reader's page, compass and all" do
    get preview_admin_daily_pick_path(@tomorrow), headers: curator_headers

    assert_response :success
    assert_select ".masthead__label", text: "Artwork of the Day"
    assert_select "time.masthead__aside a", count: 0
    assert_select ".compass span[aria-current=?]", "page", text: "Today"
    assert_select ".compass a[href=?]", days_path, text: "Days"
    assert_select ".coda__line", text: "See you tomorrow."
  end
end
