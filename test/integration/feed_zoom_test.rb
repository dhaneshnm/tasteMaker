require "test_helper"

class FeedZoomTest < ActionDispatch::IntegrationTest
  test "every work in the archive that has a picture is tappable" do
    get feed_path

    assert_select "article.post", count: 5
    assert_select "button.plate__zoom", count: 4
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
end
