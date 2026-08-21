require "test_helper"

# Story 0022 Release 1 — the filter machinery on /feed, extended by story
# 0024 (tradition), 0025 (Flowers), and rebuilt by story 0027: the three
# in-flow facet rows are gone, replaced by a rail door to `/feed/index`.
# Genre and tradition stay out of fixtures where a test doesn't need them: a
# test that only ever sets one facet proves nothing about the
# byte-identical-except-active-rows claim.
class FeedFilterTest < ActionDispatch::IntegrationTest
  behind_the_wall!

  MIN = Painting::MIN_FACET_WORKS

  # `create_paintings` lives in `test_helper.rb` now — shared with
  # `painting_test.rb` (`/simplify`).

  # -------------------------------------------------------------- /feed

  test "an unresolvable slug is unfiltered, not a 500 and not an empty page" do
    get feed_path(period: "not-a-real-century")

    assert_response :success
    assert_select ".masthead__label", text: "The full gallery"
    assert_select "a.compass__door[aria-label='Gallery index']"
  end

  test "a facet clearing the floor actually scopes the results and speaks in the editorial voice" do
    create_paintings(MIN, source_id_start: 8_000, period: "17th century")
    create_paintings(3, source_id_start: 8_100, period: "18th century")

    get feed_path(period: "17th-century")
    assert_response :success
    assert_select ".masthead__label", text: /seventeenth century/i
    assert_select ".masthead__aside", text: "#{MIN} works"
    assert_select "a.compass__door[aria-label='Gallery index — The seventeenth century']"
  end

  test "combined genre and period filters AND together" do
    create_paintings(MIN, source_id_start: 8_200, period: "15th century", genre: "Portrait")
    create_paintings(MIN, source_id_start: 8_300, period: "15th century", genre: "Landscape")

    get feed_path(period: "15th-century", genre: "portrait")
    assert_response :success
    assert_select ".masthead__aside", text: "#{MIN} works"
  end

  test "the empty combined-filter state: a real AND with zero matches renders the empty page, with two ways out" do
    create_paintings(MIN, source_id_start: 8_400, period: "14th century", genre: "Portrait")
    create_paintings(MIN, source_id_start: 8_500, period: "13th century", genre: "Landscape")

    get feed_path(period: "14th-century", genre: "landscape")

    assert_response :success
    assert_select ".page--empty" do
      assert_select "p.coda__line", text: "Nothing here wears both."
      assert_select "a.caps-link", text: "See the full gallery"
      assert_select "a.caps-link", text: "Open the index"
    end
    assert_select ".post", count: 0
    assert_select "p.coda__line", text: "You have walked the whole gallery.", count: 0
  end

  test "the coda reads the filtered line under an active filter, and offers another wing" do
    create_paintings(MIN, source_id_start: 8_600, period: "12th century")

    # MIN (16) exceeds PER_PAGE (10) — the coda is on the LAST filtered
    # page, not the first (the regression the outside voice caught: a
    # floor above PER_PAGE means the filtered set never fits on page 1).
    last_filtered_page = (MIN.to_f / PaintingsController::PER_PAGE).ceil
    get feed_path(period: "12th-century", page: last_filtered_page)
    assert_select "p.coda__line", text: "Every match, end to end."
    assert_select "a.caps-link", text: "Another wing"

    last_page = (Painting.count.to_f / PaintingsController::PER_PAGE).ceil
    get feed_path(page: last_page)
    assert_select "p.coda__line", text: "You have walked the whole gallery."
    assert_select "a.caps-link", text: "Another wing", count: 0
  end

  test "the pagination frame src preserves both active filters" do
    create_paintings(MIN + PaintingsController::PER_PAGE,
      source_id_start: 8_700, period: "11th century", genre: "Still life")

    get feed_path(period: "11th-century", genre: "still-life")

    assert_response :success
    frame = css_select("turbo-frame[src]").first
    assert frame, "expected a lazy-load frame for the next page"
    assert_match "period=11th-century", frame["src"]
    assert_match "genre=still-life", frame["src"]
  end

  test "a filtered view is URL-addressable — a cold GET with no prior state works" do
    create_paintings(MIN, source_id_start: 8_800, period: "17th century")

    reset!
    register_device
    get feed_path(period: "17th-century")

    assert_response :success
    assert_select ".masthead__aside", text: "#{MIN} works"
  end

  test "a tradition facet clearing the floor scopes the results" do
    create_paintings(MIN, source_id_start: 8_900, tradition: "Mughal Painting")
    create_paintings(3, source_id_start: 8_950, tradition: "Rajput Painting")

    get feed_path(tradition: "mughal-painting")
    assert_response :success
    assert_select ".masthead__label", text: "Mughal painting"
    assert_select ".masthead__aside", text: "#{MIN} works"
  end

  test "unknown tradition slug is unfiltered, not a 500" do
    get feed_path(tradition: "not-a-real-tradition")

    assert_response :success
    assert_select ".masthead__label", text: "The full gallery"
  end

  test "all three facets combine: tradition AND period AND genre" do
    create_paintings(MIN, source_id_start: 9_000,
      tradition: "Chinese Painting", period: "17th century", genre: "Landscape")
    create_paintings(MIN, source_id_start: 9_050,
      tradition: "Chinese Painting", period: "17th century", genre: "Portrait")

    get feed_path(tradition: "chinese-painting", period: "17th-century", genre: "landscape")
    assert_response :success
    assert_select ".masthead__aside", text: "#{MIN} works"
    assert_select ".masthead__label", text: "Chinese painting, landscapes, the seventeenth century"
  end

  test "the pagination frame src preserves the tradition filter alongside the others" do
    create_paintings(MIN + PaintingsController::PER_PAGE,
      source_id_start: 9_100, tradition: "Japanese Painting", period: "18th century")

    get feed_path(tradition: "japanese-painting", period: "18th-century")

    assert_response :success
    frame = css_select("turbo-frame[src]").first
    assert frame, "expected a lazy-load frame for the next page"
    assert_match "tradition=japanese-painting", frame["src"]
    assert_match "period=18th-century", frame["src"]
  end

  test "AND-to-zero including tradition renders the empty state, not a silent drop" do
    create_paintings(MIN, source_id_start: 9_200, tradition: "Korean Painting", genre: "Portrait")
    create_paintings(MIN, source_id_start: 9_250, tradition: "Chinese Painting", genre: "Landscape")

    get feed_path(tradition: "korean-painting", genre: "landscape")

    assert_response :success
    assert_select ".page--empty" do
      assert_select "p.coda__line", text: "Nothing here wears both."
    end
    assert_select ".post", count: 0
  end

  # Story 0025's one vocabulary addition. The machinery is value-agnostic —
  # this pins that the new value rides it end to end: slug round-trip via
  # `facet_slug`, filtering when tapped.
  test "the Flowers value filters like any other genre" do
    create_paintings(MIN, source_id_start: 9_300, genre: "Flowers")
    create_paintings(MIN, source_id_start: 9_350, genre: "Portrait")

    get feed_path(genre: "flowers")
    assert_response :success
    assert_select ".masthead__aside", text: "#{MIN} works"
    assert_select ".masthead__label", text: "Flowers"
  end

  test "the feed makes no facet GROUP BY queries when unfiltered (story 0027 perf win)" do
    assert_no_queries_match(/GROUP BY/) { get feed_path }
    assert_response :success
  end

  # -------------------------------------------------------------- /feed/index (wings)

  test "the index is walled like the feed" do
    reset!
    get feed_index_path

    assert_response :see_other
  end

  test "the index lists every value that clears the floor, under a heading per facet" do
    create_paintings(MIN, source_id_start: 9_400, tradition: "Mughal Painting")
    create_paintings(MIN, source_id_start: 9_420, genre: "Landscape")
    create_paintings(MIN, source_id_start: 9_440, period: "16th century")

    get feed_index_path
    assert_response :success

    assert_select "h2", text: "Tradition"
    assert_select "h2", text: "Subject"
    assert_select "h2", text: "Century"
    assert_select ".plates__name", text: "Mughal"
    assert_select ".plates__name", text: "Landscape"
    assert_select ".caps-link .count", text: "16"
  end

  test "filtering by tradition marks itself current and scopes the OTHER facets to what co-occurs" do
    create_paintings(MIN, source_id_start: 9_500, tradition: "Mughal Painting", period: "18th century")
    create_paintings(MIN, source_id_start: 9_520, tradition: "Rajput Painting", period: "17th century")

    get feed_index_path(tradition: "mughal-painting")
    assert_response :success

    assert_select ".plates__cell--here[aria-current='true'] .plates__name", text: "Mughal"
    assert_select ".wings__row a", text: /18th/i
    assert_select ".wings__row a", text: /17th/i, count: 0,
      message: "Rajput's 17th century has no Mughal works — it should not be offered inside the Mughal wing"
  end

  test "a facet with nothing to offer renders no section and one dim line" do
    create_paintings(MIN, source_id_start: 9_600, tradition: "Mughal Painting")
    # No genre, no period on any of these — those two facets have nothing.

    get feed_index_path
    assert_response :success

    assert_select "section", text: /Subject/, count: 0
    assert_select "p.wings__note", text: "No subject has #{MIN} works here yet."
  end

  test "Every X unsets only that facet, and only renders when it is active" do
    create_paintings(MIN, source_id_start: 9_700, tradition: "Mughal Painting", genre: "Portrait")

    get feed_index_path(tradition: "mughal-painting", genre: "portrait")
    assert_response :success

    every_tradition = css_select("h2").find { |h2| h2.text =~ /Tradition/ }.css("a").first
    assert_equal "Every tradition", every_tradition.text
    assert_match "genre=portrait", every_tradition["href"]
    assert_no_match(/tradition=/, every_tradition["href"])

    get feed_index_path
    assert_select "h2", text: /Tradition/ do
      assert_select "a", text: "Every tradition", count: 0
    end
  end

  test "Done returns to the filtered feed, not the unfiltered one" do
    create_paintings(MIN, source_id_start: 9_800, tradition: "Mughal Painting")

    get feed_index_path(tradition: "mughal-painting")
    done = css_select("a").find { |a| a.text.strip == "Done" }

    assert_match "tradition=mughal-painting", done["href"]
  end

  test "Show everything only appears when filtered, and clears every facet" do
    get feed_index_path
    assert_select "a", text: "Show everything", count: 0

    create_paintings(MIN, source_id_start: 9_900, tradition: "Mughal Painting")
    get feed_index_path(tradition: "mughal-painting")

    show_everything = css_select("a").find { |a| a.text.strip == "Show everything" }
    assert_equal feed_path, show_everything["href"]
  end

  test "the summary sentence and count read Mughal painting, N works" do
    create_paintings(MIN, source_id_start: 10_000, tradition: "Mughal Painting")

    get feed_index_path(tradition: "mughal-painting")
    assert_select "p.coda__line", text: "Mughal painting · #{MIN} works"
  end

  test "the coverage line names the INACTIVE facet, counted inside the current scope, and suppresses at 100%" do
    create_paintings(MIN, source_id_start: 10_100, tradition: "Mughal Painting", genre: "Portrait")
    create_paintings(3, source_id_start: 10_150, tradition: "Mughal Painting")

    get feed_index_path(tradition: "mughal-painting")
    assert_select "p.wings__note", text: "Subject is known for #{MIN} of #{MIN + 3} works."
    assert_select "p.wings__note", text: /Tradition is known/, count: 0,
      message: "tradition is the active facet — its own coverage is 100% by construction and says nothing"
  end

  test "a value with no stored picture still renders as a tappable wing" do
    # `create_paintings` always attaches the woodcut fixture's URL — this
    # test needs the OTHER case, so it bypasses the helper.
    Painting::MIN_FACET_WORKS.times do |i|
      Painting.create!(source: "met", source_id: 10_200 + i, title: "No picture #{i}",
        tradition: "Mughal Painting")
    end

    get feed_index_path
    assert_response :success
    assert_select ".plates__img--none"
    assert_select ".plates a", text: /Mughal/
  end

  # Story 0027 success signal 2: every link the index offers, followed,
  # never lands on the empty state.
  test "zero reachable empty states — every offered link lands on a real page" do
    create_paintings(MIN, source_id_start: 10_300, tradition: "Mughal Painting", period: "18th century")
    create_paintings(MIN, source_id_start: 10_320, tradition: "Rajput Painting", period: "17th century")

    get feed_index_path
    assert_response :success

    hrefs = css_select(".plates a, .wings__row a").map { |a| a["href"] }
    assert hrefs.any?, "expected at least one offered link"

    hrefs.each do |href|
      get href
      assert_response :success
      assert_select ".page--empty", count: 0, message: "#{href} reached the empty state"
    end
  end

  # `assert_queries_count` wants an exact number, which would make this test
  # fail on any incidental, harmless query shape change — an upper bound is
  # the actual claim (plan step 6 / eng review 4.2: three `GROUP BY`s + up to
  # sixteen plate lookups, all indexed, no per-plate transform in the
  # request).
  test "the wings action stays within a bounded number of queries" do
    create_paintings(MIN, source_id_start: 10_400, tradition: "Mughal Painting", genre: "Portrait", period: "18th century")

    queries = []
    subscriber = ->(*, payload) { queries << payload[:sql] unless payload[:cached] || payload[:name] == "SCHEMA" }
    ActiveSupport::Notifications.subscribed(subscriber, "sql.active_record") { get feed_index_path }

    assert_response :success
    assert_operator queries.size, :<=, 30,
      "the index made #{queries.size} queries — investigate before raising this bound:\n#{queries.join("\n")}"
  end
end
