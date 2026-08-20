require "test_helper"

# Story 0022 Release 1 — the filter machinery on /feed, extended by story
# 0024 (tradition). Genre and tradition stay out of fixtures where a test
# doesn't need them: a test that only ever sets one facet proves nothing
# about the byte-identical-except-active-rows claim.
class FeedFilterTest < ActionDispatch::IntegrationTest
  behind_the_wall!

  MIN = Painting::MIN_FACET_WORKS

  def create_paintings(count, source_id_start:, period: nil, genre: nil, tradition: nil, **attrs)
    count.times do |i|
      Painting.create!(
        source: "met", source_id: source_id_start + i, title: "Work #{source_id_start + i}",
        image_url_800: paintings(:woodcut).image_url_800,
        period: period, genre: genre, tradition: tradition, **attrs
      )
    end
  end

  test "an unresolvable slug is unfiltered, not a 500 and not an empty page" do
    get feed_path(period: "not-a-real-century")

    assert_response :success
    assert_select ".facets", count: 0
  end

  test "the non-empty rule: a facet with no displayed values renders no row" do
    get feed_path

    assert_select "nav.facets", count: 0
  end

  test "a facet clearing the floor renders its row, and filtering actually scopes the results" do
    create_paintings(MIN, source_id_start: 8_000, period: "17th century")
    create_paintings(3, source_id_start: 8_100, period: "18th century")

    get feed_path
    assert_select "nav.facets[aria-label='Filter by period']" do
      assert_select "a", text: "17th century"
      assert_select "a", text: "18th century", count: 0
    end

    get feed_path(period: "17th-century")
    assert_response :success
    assert_select ".masthead__aside", text: "#{MIN} works · Mia"
  end

  test "combined genre and period filters AND together" do
    create_paintings(MIN, source_id_start: 8_200, period: "15th century", genre: "Portrait")
    create_paintings(MIN, source_id_start: 8_300, period: "15th century", genre: "Landscape")

    get feed_path(period: "15th-century", genre: "portrait")
    assert_response :success
    assert_select ".masthead__aside", text: "#{MIN} works · Mia"
  end

  test "the empty combined-filter state: a real AND with zero matches renders the empty page, not the coda over nothing" do
    create_paintings(MIN, source_id_start: 8_400, period: "14th century", genre: "Portrait")
    create_paintings(MIN, source_id_start: 8_500, period: "13th century", genre: "Landscape")

    get feed_path(period: "14th-century", genre: "landscape")

    assert_response :success
    assert_select ".page--empty" do
      assert_select "p.coda__line", text: "Nothing here wears both."
      assert_select "a.caps-link", text: "See the full gallery"
    end
    assert_select ".post", count: 0
    assert_select "p.coda__line", text: "You have walked the whole gallery.", count: 0
  end

  test "the coda reads the filtered line under an active filter, and the unfiltered line otherwise" do
    create_paintings(MIN, source_id_start: 8_600, period: "12th century")

    get feed_path(period: "12th-century")
    assert_select "p.coda__line", text: "Every match, end to end."

    # The unfiltered pool already exceeds PER_PAGE (fixtures alone), so page 1
    # never reaches the coda regardless of this story — the last page does.
    last_page = (Painting.count.to_f / PaintingsController::PER_PAGE).ceil
    get feed_path(page: last_page)
    assert_select "p.coda__line", text: "You have walked the whole gallery."
  end

  test "the pagination frame src preserves both active filters" do
    create_paintings(Painting::MIN_FACET_WORKS + PaintingsController::PER_PAGE,
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
    assert_select ".masthead__aside", text: "#{MIN} works · Mia"
  end

  # Story 0024 — the tradition facet.

  test "a tradition facet clearing the floor renders its row and filters" do
    create_paintings(MIN, source_id_start: 8_900, tradition: "Mughal Painting")
    create_paintings(3, source_id_start: 8_950, tradition: "Rajput Painting")

    get feed_path
    assert_select "nav.facets[aria-label='Filter by tradition']" do
      assert_select "a", text: "Mughal Painting"
      assert_select "a", text: "Rajput Painting", count: 0
    end

    get feed_path(tradition: "mughal-painting")
    assert_response :success
    assert_select ".masthead__aside", text: "#{MIN} works · Mia"
  end

  test "unknown tradition slug is unfiltered, not a 500" do
    get feed_path(tradition: "not-a-real-tradition")

    assert_response :success
    assert_select ".facets", count: 0
  end

  test "all three facets combine: tradition AND period AND genre" do
    create_paintings(MIN, source_id_start: 9_000,
      tradition: "Chinese Painting", period: "17th century", genre: "Landscape")
    create_paintings(MIN, source_id_start: 9_050,
      tradition: "Chinese Painting", period: "17th century", genre: "Portrait")

    get feed_path(tradition: "chinese-painting", period: "17th-century", genre: "landscape")
    assert_response :success
    assert_select ".masthead__aside", text: "#{MIN} works · Mia"
  end

  test "the pagination frame src preserves the tradition filter alongside the others" do
    create_paintings(Painting::MIN_FACET_WORKS + PaintingsController::PER_PAGE,
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
  # this pins that the new value rides it end to end: chip when it clears
  # the floor, filtering when tapped, slug round-trip via `facet_slug`.
  test "the Flowers value renders its chip and filters, like any other genre" do
    create_paintings(MIN, source_id_start: 9_300, genre: "Flowers")
    create_paintings(MIN, source_id_start: 9_350, genre: "Portrait")

    get feed_path
    assert_select "nav.facets[aria-label='Filter by genre']" do
      assert_select "a", text: "Flowers"
    end

    get feed_path(genre: "flowers")
    assert_response :success
    assert_select ".masthead__aside", text: "#{MIN} works · Mia"
  end
end
