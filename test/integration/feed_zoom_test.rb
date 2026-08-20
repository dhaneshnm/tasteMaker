require "test_helper"

class FeedZoomTest < ActionDispatch::IntegrationTest
  behind_the_wall!

  test "every work in the archive that has a picture is tappable" do
    get feed_path

    # Scoped to one page, same order the controller queries in — a fixture
    # count that outgrows a single page (story 0021's auto_* pool did) must
    # not make this assert a stale number either way.
    page_paintings = Painting.feed_ordered.limit(PaintingsController::PER_PAGE)
    assert_select "article.post", count: page_paintings.count
    # "every work that HAS a picture" — derived from the same predicate the
    # template branches on, so a fixture with or without an image cannot make
    # this assert a stale number.
    assert_select "button.plate__zoom", count: page_paintings.count(&:display_image?)
    assert_select "button.plate__zoom[aria-label=?]",
      "View #{paintings(:sunflowers).title} full screen"
  end

  # The reason the overlay is a singleton: one per work would ship 110 hidden
  # <img src>es and the browser would fetch the whole collection twice.
  test "the archive carries exactly one overlay, and it prefetches nothing" do
    get feed_path

    assert_select ".zoom[role=dialog][aria-modal=true]", count: 1
    assert_select ".zoom__img", count: 1
    assert_select ".zoom__img[src]", count: 0
  end

  test "a work with no picture is not tappable and rests instead" do
    get feed_path

    assert_select "#painting_#{paintings(:imageless).dom_key}" do
      assert_select ".plate__zoom", count: 0
      assert_select ".plate__resting[hidden]", count: 0
      assert_select ".plate__resting", text: /resting/
    end
  end

  test "the daily page and the archive open the same overlay" do
    get root_path
    daily = css_select(".zoom").first.to_html

    get feed_path
    assert_equal daily, css_select(".zoom").first.to_html
  end

  # Story 0018. `/feed` is walled, so an artist with a usable slug links
  # regardless of how many works it has — the ">= 2 works" rule was drafted
  # and then reversed once a one-work page was settled as a real page, not a
  # dead end (eng review E3, reversed by outside voice X5/X6).
  test "an artist with a usable slug links, even with only one work in the pool" do
    get feed_path

    assert_select "#painting_#{paintings(:sunflowers).dom_key}" do
      assert_select "a.label__artist-name[href=?]",
        artist_path(paintings(:sunflowers).artist_slug), text: paintings(:sunflowers).artist
    end
  end

  # Design review D11. A culture string denied artist status by the model
  # never renders as a link, on the one screen where every other name does.
  test "a deny-listed culture string never renders as a link" do
    get feed_path

    assert_select "#painting_#{paintings(:culture_as_artist).dom_key}" do
      assert_select "a.label__artist-name", count: 0
      assert_select ".label__artist-name--dim", text: "China"
    end
  end

  # Design review D15. The link sits inside a wall label under a titled work
  # — WCAG 2.4.4's context — so it carries no `aria-label` of its own. An
  # override would break voice control (which says what it sees) and double
  # every announcement across 110 works in the gallery.
  test "the artist link's accessible name is the plain artist string" do
    get feed_path

    css_select("a.label__artist-name").each do |link|
      assert_nil link["aria-label"],
        "#{link['href']} should rely on its visible text for an accessible name"
    end
  end
end
