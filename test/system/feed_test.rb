require "application_system_test_case"

# The screen story 0012 was opened about.
#
# `/feed` streams 110 works with infinite scroll. Its masthead is not sticky
# (DESIGN.md rule 5) and its coda renders only on the last page, so two flicks in
# there was nothing on screen to leave by — the only exit was a serif wordmark
# that had scrolled off the top. A reader who followed "Wander the full gallery"
# out of the daily ritual could not get back to it.
#
# The fix is structural, not a state change: the compass rides in a sticky rail
# below the masthead. There is no cross-browser way for CSS to know an element
# has become stuck, so nothing here changes shape — the masthead leaves and the
# rail does not.
class FeedTest < ApplicationSystemTestCase
  # Enough works to push the masthead well off the top of the screen.
  setup do
    (PaintingsController::PER_PAGE * 2).times do |i|
      Painting.create!(mia_id: 920_000 + i, title: "Filler #{i}",
        artist: "A. Painter", image_url_800: "https://example.test/#{i}.jpg")
    end
  end

  def scrolled_to(y)
    page.execute_script("window.scrollTo(0, #{y});")
    # One frame, so the sticky offset settles before anything is measured.
    page.evaluate_script("new Promise(r => requestAnimationFrame(() => r(true)))")
  end

  # The bug, made measurable. `assert_selector` alone would pass on the broken
  # page — the wordmark was always in the DOM. The question was never whether an
  # exit existed, it was whether the reader could see one.
  test "the way home is on screen after scrolling into the gallery" do
    visit feed_path
    assert_selector ".compass--rail"

    scrolled_to 1200

    top = page.evaluate_script(<<~JS)
      Math.round(document.querySelector(".compass--rail").getBoundingClientRect().top)
    JS
    assert_operator top, :>=, 0, "the rail scrolled off the top of the screen"
    assert_operator top, :<=, 2, "the rail is not stuck to the top"

    # By href, not by text: `text-transform: uppercase` means the rendered text
    # is "TODAY" and a text filter would be asserting the stylesheet.
    assert_selector ".compass--rail a[href='#{root_path}']"
  end

  test "tapping Today from deep in the gallery lands on the artwork of the day" do
    visit feed_path
    scrolled_to 1200

    within(".compass--rail") { click_on "Today" }

    assert_selector ".masthead__label", text: "Artwork of the Day"
    assert_text daily_picks(:today).painting.title
  end

  # The rail is the narrowing of rule 5, and the narrowing is spent on
  # navigation only — never on branding. A sticky bar carrying a wordmark and a
  # work count measures 104px, 16% of this screen, parked over the artwork for
  # the whole scroll. This is 58.
  test "the rail is a rail, not a masthead that followed you down the page" do
    visit feed_path
    scrolled_to 1200

    height = page.evaluate_script(<<~JS)
      Math.round(document.querySelector(".compass--rail").getBoundingClientRect().height)
    JS
    assert_operator height, :<=, 70, "the rail grew into a second masthead"

    brand_bottom = page.evaluate_script(<<~JS)
      Math.round(document.querySelector(".masthead__brand").getBoundingClientRect().bottom)
    JS
    assert_operator brand_bottom, :<, 0, "the masthead came along for the ride"
  end

  # `.zoom` is z-index 20 and the rail is 1. Reading a work full screen from the
  # gallery must not leave a navigation bar sitting on top of the picture.
  test "the full-screen view covers the rail" do
    visit feed_path
    scrolled_to 1200

    find(".plate__zoom", match: :first).click
    assert_selector ".zoom", visible: true

    # Whatever is painted where the rail sits belongs to the overlay. Probing the
    # strip the rail occupies rather than the rail's own rect: with the overlay
    # open the page cannot scroll, and the rail may be anywhere behind it.
    covered = page.evaluate_script(<<~JS)
      (() => {
        const el = document.elementFromPoint(window.innerWidth / 2, 20);
        return el !== null && el.closest(".zoom") !== null;
      })()
    JS
    assert covered, "the rail sat on top of the full-screen artwork"
  end

  # Four one-word labels on one row is what keeps this a 58px rail. If the copy
  # or the gap ever grows, this is the first thing that says so.
  test "the rail holds its four doors on one row at 375px" do
    visit feed_path

    tops = page.evaluate_script(<<~JS)
      [...new Set([...document.querySelectorAll(".compass--rail .caps-link")]
        .map(el => Math.round(el.getBoundingClientRect().top)))].length
    JS
    assert_equal 1, tops, "the rail wrapped onto two rows"
  end
end
