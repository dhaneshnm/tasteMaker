require "application_system_test_case"

class FeedZoomTest < ApplicationSystemTestCase
  behind_the_wall!

  test "tapping a work in the archive opens that work, not the first one" do
    visit feed_path
    tap_work(paintings(:harbour))

    assert_selector ".zoom", visible: true
    assert_equal paintings(:harbour).alt_text, find(".zoom__img")[:alt]
    assert_equal "#{paintings(:harbour).title}, full screen", find(".zoom")[:"aria-label"]
  end

  test "Escape closes it and focus goes back to the work that was tapped" do
    visit feed_path
    tap_work(paintings(:harbour))
    assert_selector ".zoom", visible: true

    find("body").send_keys(:escape)

    assert_no_selector ".zoom", visible: true
    assert_no_selector "html.zoom-open", visible: :all
    assert_selector "#{work(paintings(:harbour))} .plate__zoom:focus", visible: :all
  end

  test "the next work swaps the overlay rather than stacking a second one" do
    visit feed_path

    tap_work(paintings(:harbour))
    find(".zoom__img").click
    tap_work(paintings(:sunflowers))

    assert_equal paintings(:sunflowers).alt_text, find(".zoom__img")[:alt]
    assert_selector ".zoom", count: 1, visible: :all
  end

  # The lazy Turbo frames append after the controller connects. Declarative
  # actions bind themselves; this is the test that says so.
  test "works that arrive with infinite scroll are tappable too" do
    (PaintingsController::PER_PAGE + 1).times do |i|
      Painting.create!(source: "mia", source_id: 910_000 + i, title: "Filler #{i}",
        image_url_800: paintings(:sunflowers).image_url_800,
        image_width: 800, image_height: 1000, feed_order: 100 + i)
    end
    arrival = Painting.find_by!(source_id: 910_010)

    visit feed_path
    page.execute_script("window.scrollTo(0, document.body.scrollHeight)")
    assert_selector work(arrival), visible: :all

    tap_work(arrival)

    assert_selector ".zoom", visible: true
    assert_equal arrival.alt_text, find(".zoom__img")[:alt]
    assert_selector ".zoom", count: 1, visible: :all
  end

  test "a work whose picture dies is no longer tappable" do
    visit feed_path

    page.execute_script(<<~JS)
      document.querySelector("#{work(paintings(:harbour))} .plate__img")
        .dispatchEvent(new Event("error"))
    JS

    assert_selector "#{work(paintings(:harbour))} .plate__zoom[hidden]", visible: :all
    assert_selector "#{work(paintings(:harbour))} .plate__resting", text: "This work is resting"
    # Its neighbours are untouched.
    assert_no_selector "#{work(paintings(:sunflowers))} .plate__zoom[hidden]", visible: :all
  end

  # `rest()` reaches for the rail's zoom button too (story 0014), and `/feed`
  # renders no rail at all. Ten plates, one controller scope, no `railZoom`
  # target: an unguarded `this.railZoomTarget` throws here and takes every other
  # zoom on the page down with it. This is the test for that guard, and it is on
  # the feed on purpose — the guard is invisible on the screens that have a rail.
  test "a dying picture on the gallery does not break the rest of the page" do
    visit feed_path

    page.execute_script(<<~JS)
      document.querySelector("#{work(paintings(:harbour))} .plate__img")
        .dispatchEvent(new Event("error"))
    JS

    assert_selector "#{work(paintings(:harbour))} .plate__resting"

    # The proof the handler did not throw partway: a neighbour still zooms.
    tap_work(paintings(:sunflowers))
    assert_selector ".zoom", visible: true
  end

  # The daily page's rail zoom opens the same overlay the plate does, and hands
  # focus back to whichever control was tapped. Two triggers, one overlay — the
  # rail's button does not wrap the image, so `plateFor` is what makes it work.
  test "the rail's zoom opens the artwork and returns focus to itself" do
    visit root_path

    find(".rail__act[data-artwork-target='railZoom']").click
    assert_selector ".zoom", visible: true
    assert_selector ".zoom__img[src]"

    find(".zoom__close").click
    assert_no_selector ".zoom", visible: true
    assert_equal "railZoom",
      page.evaluate_script("document.activeElement.dataset.artworkTarget"),
      "focus did not come back to the rail control that opened the overlay"
  end

  private
    def work(painting)
      "#painting_#{painting.dom_key}"
    end

    # Posts below the fold sit at opacity 0 until they are scrolled to, so
    # tapping one means arriving at it the way a reader does.
    def tap_work(painting)
      page.execute_script("document.querySelector('#{work(painting)}').scrollIntoView({block: 'center'})")
      find("#{work(painting)} .plate__zoom").click
    end
end
