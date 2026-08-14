require "test_helper"

class DailyTest < ActionDispatch::IntegrationTest
  # Story 0015 put the reader-facing pages behind the wall; these tests read
  # them the way the app does — as a registered device.
  setup { register_device }

  test "the front door is today's artwork and today's note" do
    get root_path

    assert_response :success
    assert_select "h1.label__title", text: paintings(:sunflowers).title
    assert_select ".label__artist .label__artist-name", text: paintings(:sunflowers).artist
    assert_select ".label__note", /fortnight/
    # The curator's own words are shown whole and wear nobody else's name.
    assert_select ".label__source", count: 0
    assert_select ".label__more", count: 0
  end

  # The moat is the hand-written voice, so borrowed words never wear it. A day
  # the curator did not write runs the museum's text under the museum's name,
  # and clamped — museum copy runs to 324 words in the real pool against a
  # 60-180 target, so shown whole it would push the artwork off a phone.
  test "a day with no note runs the museum's text, marked as theirs and clamped" do
    daily_picks(:today).update!(blurb: nil)

    get root_path

    assert_response :success
    assert_select ".label__note", count: 0
    assert_select ".label__body#daily-note[data-controller=expand]" do
      assert_select "p.label__text", /catalogue text/
      assert_select "button.label__more"
      assert_select "p.label__source", text: "From the Minneapolis Institute of Art"
    end
  end

  test "an emptied note is stored as nothing, so museum days stay countable" do
    pick = daily_picks(:today)
    pick.update!(blurb: "   ")

    assert_nil pick.reload.blurb
    assert_equal 1, DailyPick.published.where(blurb: nil).count
  end

  test "the page says what it is and which day it belongs to" do
    get root_path

    assert_select ".masthead__brand", text: "Tondo"
    assert_select ".masthead__label", text: "Artwork of the Day"
    assert_select "time.masthead__aside[datetime=?]", Date.current.iso8601
  end

  test "the artwork is reachable full screen" do
    get root_path

    assert_select "button.plate__zoom[aria-label=?]",
      "View #{paintings(:sunflowers).title} full screen"
    assert_select ".zoom[role=dialog][aria-modal=true]"
  end

  test "the ritual ends with an ending, and the gallery is a choice" do
    get root_path

    assert_select ".coda__line", text: "See you tomorrow."
    assert_select ".coda .caps-link[href=?]", feed_path, text: /Wander the full gallery/
  end

  test "a missed day keeps the last artwork up, dated honestly" do
    daily_picks(:today).destroy!

    get root_path

    assert_response :success
    assert_select "h1.label__title", text: paintings(:harbour).title
    assert_select "time.masthead__aside[datetime=?]", 1.day.ago.to_date.iso8601
  end

  test "tomorrow's artwork never leaks" do
    get root_path

    assert_response :success
    assert_no_match paintings(:bronze).title, response.body
  end

  test "an unstarted site says so instead of erroring" do
    DailyPick.delete_all

    get root_path

    assert_response :success
    assert_select ".coda__line", text: "The first artwork arrives soon."
  end

  test "the page revalidates instead of going stale" do
    get root_path

    assert_response :success
    assert_match "no-cache", response.headers["Cache-Control"]
    assert_match "public", response.headers["Cache-Control"]
    assert response.headers["ETag"].present?, "expected an ETag to revalidate against"
  end

  test "an unchanged day costs a 304, an edited note does not" do
    get root_path
    etag = response.headers["ETag"]

    get root_path, headers: { "HTTP_IF_NONE_MATCH" => etag }
    assert_response :not_modified

    daily_picks(:today).update!(blurb: "A completely different note about this painting.")

    get root_path, headers: { "HTTP_IF_NONE_MATCH" => etag }
    assert_response :success
    assert_select ".label__note", /completely different note/
  end

  test "the gallery moved to /feed and still scrolls" do
    get feed_path

    assert_response :success
    # Derived, not hardcoded: this counts "every fixture painting", and a story
    # that adds one for its own reasons should not fail a test about the feed.
    assert_select "article.post", count: Painting.count
    assert_select "img[src=?]", paintings(:sunflowers).image_url_800
  end

  # The lazy frame used to point at the root. After the root swap that URL
  # fetches the daily page, which has no frame to swap in, and the infinite
  # scroll dies silently. It only renders when there is a second page, so the
  # test has to fill one.
  test "the gallery's next page still comes from /feed, not the front door" do
    (PaintingsController::PER_PAGE + 1).times do |i|
      Painting.create!(source: "mia", source_id: 910_000 + i, title: "Filler #{i}", image_url_800: "https://example.test/#{i}.jpg")
    end

    get feed_path

    assert_select "turbo-frame[src=?]", feed_path(page: 2)

    get feed_path(page: 2)

    assert_response :success
    assert_select "article.post", minimum: 1
  end

  # Regression: ISSUE-001 — the rail's zoom button and the plate's zoom button
  # both read "View {title} full screen", and they are consecutive tab stops, so
  # a screen reader user tabbing off the artwork heard the identical name twice
  # before reaching Keep.
  # Found by /qa on 2026-08-14
  # Report: .gstack/qa-reports/qa-report-localhost-2026-08-14.md
  #
  # Asserted as a general rule rather than against the new string. The specific
  # wording is not the point — two controls on one screen that announce
  # themselves identically is, and story 0014 made that easy to reintroduce by
  # giving the daily page a second control for something the plate already does.
  test "no two controls on the daily page announce themselves the same way" do
    yesterday = daily_picks(:yesterday)

    [ root_path, day_path(yesterday.scheduled_on.iso8601) ].each do |route|
      get route
      assert_response :success

      names = css_select("a[href], button").filter_map do |el|
        name = el["aria-label"].presence || el.text.squish.presence
        name unless name.nil?
      end

      duplicates = names.tally.select { |_, count| count > 1 }.keys
      assert_empty duplicates,
        "#{route} has controls sharing an accessible name: #{duplicates.inspect}"
    end
  end

  test "the root is no longer the gallery" do
    get root_path

    assert_select "article.post", count: 0
    assert_select ".sentinel", count: 0
  end
end
