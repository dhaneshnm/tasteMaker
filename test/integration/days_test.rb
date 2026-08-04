require "test_helper"

class DaysTest < ActionDispatch::IntegrationTest
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

  test "more than one day, and the closing line is just the way back" do
    get days_path

    assert_select ".coda__line", count: 0
    assert_select ".coda .caps-link[href=?]", root_path, text: /Today/
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

  test "the walk always offers the way back to today" do
    get day_path(@yesterday.scheduled_on.iso8601)

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

  test "the front door's date is not a link while there is only one day" do
    @yesterday.destroy!

    get root_path

    assert_select "time.masthead__aside a", count: 0
  end

  test "the front door's date opens the archive once there is more than one day" do
    get root_path

    assert_select "time.masthead__aside a[href=?]", days_path
  end

  # Backfilling a past day leaves `current` untouched, so an ETag keyed on the
  # pick alone would keep serving a page with no way into the archive.
  test "backfilling a past day makes the archive link appear to a returning visitor" do
    @yesterday.destroy!

    get root_path
    etag = response.headers["ETag"]
    assert_select "time.masthead__aside a", count: 0

    DailyPick.create!(painting: paintings(:woodcut), scheduled_on: 4.days.ago.to_date,
      blurb: "Backfilled after the fact, which must not leave the front door stale.")

    get root_path, headers: { "HTTP_IF_NONE_MATCH" => etag }
    assert_response :success
    assert_select "time.masthead__aside a[href=?]", days_path
  end

  # ---------- the curator's preview ----------

  test "a preview shows the reader's page without a live archive link" do
    get preview_admin_daily_pick_path(@tomorrow), headers: curator_headers

    assert_response :success
    assert_select ".masthead__label", text: "Artwork of the Day"
    assert_select "time.masthead__aside a", count: 0
    assert_select ".coda__line", text: "See you tomorrow."
  end
end
