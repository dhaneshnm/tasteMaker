require "test_helper"

class DailyTest < ActionDispatch::IntegrationTest
  behind_the_wall!

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
  # Story 0033: the museum's name moved from a separate `.label__source`
  # sentence into the pin's own "Pinned · <voice>" summary — one attribution,
  # not two.
  test "a day with no note runs the museum's text, marked as theirs and clamped" do
    daily_picks(:today).update!(blurb: nil)

    get root_path

    assert_response :success
    assert_select ".label__note", count: 0
    assert_select ".cmt__fold", text: /Pinned.*Minneapolis Institute of Art/
    assert_select ".label__body#daily-note[data-controller=expand]" do
      assert_select "p.label__text", /catalogue text/
      assert_select "button.label__more"
    end
  end

  # Story 0023 — the one reader-visible surface auto-fill could break.
  # `daily/show` has no branch on `auto_tier` at all; this pins that an
  # auto-picked day renders exactly like a hand-picked one.
  test "an auto-picked day with no note runs the museum's text exactly like a hand-picked one" do
    daily_picks(:today).update!(blurb: nil, auto_tier: 2)

    get root_path

    assert_response :success
    assert_select ".label__note", count: 0
    assert_select ".cmt__fold", text: /Pinned.*Minneapolis Institute of Art/
    assert_select ".label__body#daily-note[data-controller=expand]" do
      assert_select "p.label__text", /catalogue text/
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
    # Derived, not hardcoded: this counts "every fixture painting up to one
    # page", so a story that adds fixtures for its own reasons (story 0023's
    # auto_* pool) does not fail a test about the feed just by growing past
    # a single page.
    assert_select "article.post", count: [ Painting.count, PaintingsController::PER_PAGE ].min
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

      # Links to the SAME destination are exempt, and only links — never
      # buttons. Story 0017 puts two doors to `/you` on this page: the corner
      # mark in the bar and the word in the coda, deliberately, because a ring
      # and a dot teach nobody what they open. A logo and a footer link both
      # reading "Home" is the web's oldest pattern and confuses no one; two
      # buttons firing the same action with nothing to tell them apart is what
      # ISSUE-001 actually was. The rule keeps its teeth for that case and for
      # links that share a name while going somewhere else.
      controls = css_select("a[href], button").filter_map do |el|
        name = el["aria-label"].presence || el.text.squish.presence
        # Pair each name with where it goes, then de-duplicate on the PAIR. Two
        # links to one destination collapse to a single entry and stop being a
        # duplicate name; two links to different places, or any two buttons,
        # survive and still fail.
        #
        # `el.path` — the node's own XPath — is the destination for anything
        # that cannot prove one: a button, which has no href at all, and a link
        # whose href is blank, which proves nothing about where it goes. Both
        # are then unique per element and can never be their own twin.
        destination = el["href"].presence if el.name == "a"
        [ name, destination || el.path ] if name
      end

      duplicates = controls.uniq.map(&:first).tally.select { |_, count| count > 1 }.keys

      assert_empty duplicates,
        "#{route} has controls sharing an accessible name: #{duplicates.inspect}"
    end
  end

  test "the root is no longer the gallery" do
    get root_path

    assert_select "article.post", count: 0
    assert_select ".sentinel", count: 0
  end

  # Story 0018, eng review X3/X11. `/` is public while `/artists/:slug` is
  # walled — a link on the front door would bounce every anonymous
  # first-time reader. The SAME template at `/days/:date` links, because that
  # route is already behind the wall.
  test "the artist name is dim and unlinked on the front door" do
    get root_path

    assert_select ".label__artist a.label__artist-name", count: 0
    assert_select ".label__artist .label__artist-name--dim",
      text: paintings(:sunflowers).artist
  end

  test "the same partial links the artist name on an archived day" do
    yesterday = daily_picks(:yesterday)

    get day_path(yesterday.scheduled_on.iso8601)

    assert_select ".label__artist a.label__artist-name[href=?]",
      artist_path(paintings(:harbour).artist_slug), text: paintings(:harbour).artist
  end

  # Design review D11. A blank artist falls back to `culture` (or "Unknown
  # artist") and must never look tappable — the unlinkable fallback is the
  # defect D11 exists to prevent.
  test "a work with only a culture never renders as a link" do
    yesterday = daily_picks(:yesterday)
    # bronze is already claimed by :tomorrow's fixture (painting_id is
    # unique), and :today would redirect back to root_path (DaysController#
    # show) — :yesterday is the one date that both frees the painting and
    # renders through the :archive chrome, where non-blank artists DO link.
    daily_picks(:tomorrow).destroy!
    yesterday.update!(painting: paintings(:bronze))

    get day_path(yesterday.scheduled_on.iso8601)

    assert_select ".label__artist a.label__artist-name", count: 0
    assert_select ".label__artist .label__artist-name--dim", text: paintings(:bronze).artist_display
  end
end
