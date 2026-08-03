require "test_helper"

class DailyTest < ActionDispatch::IntegrationTest
  test "the front door is today's artwork and today's note" do
    get root_path

    assert_response :success
    assert_select "h1.daily-title", text: paintings(:sunflowers).title
    assert_select ".daily-artist__name", text: paintings(:sunflowers).artist
    assert_select ".daily-note", /fortnight/
  end

  test "the page says what it is and which day it belongs to" do
    get root_path

    assert_select ".daily-masthead__brand", text: "Tastemaker"
    assert_select ".daily-masthead__label", text: "Artwork of the Day"
    assert_select ".daily-masthead__date[datetime=?]", Date.current.iso8601
  end

  test "the artwork is reachable full screen" do
    get root_path

    assert_select "button.daily-figure__zoom[aria-label=?]",
      "View #{paintings(:sunflowers).title} full screen"
    assert_select ".zoom[role=dialog][aria-modal=true]"
  end

  test "the ritual ends with an ending, and the gallery is a choice" do
    get root_path

    assert_select ".daily-close__line", text: "See you tomorrow."
    assert_select ".daily-close__link[href=?]", feed_path, text: /Wander the full gallery/
  end

  test "a missed day keeps the last artwork up, dated honestly" do
    daily_picks(:today).destroy!

    get root_path

    assert_response :success
    assert_select "h1.daily-title", text: paintings(:harbour).title
    assert_select ".daily-masthead__date[datetime=?]", 1.day.ago.to_date.iso8601
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
    assert_select ".daily-empty", text: "The first artwork arrives soon."
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
    assert_select ".daily-note", /completely different note/
  end

  test "the gallery moved to /feed and still scrolls" do
    get feed_path

    assert_response :success
    assert_select "article.post", count: 5
    assert_select "img[src=?]", paintings(:sunflowers).image_url_800
  end

  test "the root is no longer the gallery" do
    get root_path

    assert_select "article.post", count: 0
    assert_select ".sentinel", count: 0
  end
end
