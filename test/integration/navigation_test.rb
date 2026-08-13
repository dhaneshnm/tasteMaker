require "test_helper"

# The forcing function for story 0012.
#
# The product has four reader surfaces and, before this story, the links between
# them were a one-way funnel: `/feed` had no exit anybody could see, `/collection`
# was reachable from one line in one footer, and the archive's door on the front
# page was an unlabelled date that only appeared once a second day existed. Each
# of those was fixed once, on one screen, the day somebody noticed it — ISSUE-001
# is that same bug, patched one page at a time.
#
# This file is what stops it coming back. Every reader surface reaches every
# other one, asserted as a matrix rather than as anecdotes.
#
# Every assertion is scoped to `.compass`. The word "Today" also appears in
# `days/_walk` at the foot of an archived day, so an unscoped assertion would
# happily prove the wrong element.
class NavigationTest < ActionDispatch::IntegrationTest
  # The 404 is one of the six screens in the matrix, and reaching it means
  # letting the app render the failure instead of re-raising it (story 0004).
  with_rescued_exceptions!

  # Fixtures: today (sunflowers), yesterday (harbour), tomorrow (bronze, queued).
  SURFACES = {
    today: "Today",
    days: "Days",
    collection: "Kept",
    gallery: "Gallery"
  }.freeze

  setup do
    @today = daily_picks(:today)
    @yesterday = daily_picks(:yesterday)
    @tomorrow = daily_picks(:tomorrow)
  end

  def path_for(key)
    { today: root_path, days: days_path, collection: collection_path, gallery: feed_path }.fetch(key)
  end

  # Every door on the screen, and the one you are standing on marked rather than
  # linked. `here` of nil means the screen is not one of the four.
  def assert_compass(here)
    assert_select ".compass", count: 1

    SURFACES.each do |key, label|
      if key == here
        assert_select ".compass span[aria-current=?]", "page", text: label
        assert_select ".compass a", text: label, count: 0
      else
        assert_select ".compass a[href=?]", path_for(key), text: label
      end
    end

    assert_select ".compass span[aria-current]", count: here.nil? ? 0 : 1
  end

  # ---------- the matrix ----------

  test "the front door reaches the other three" do
    get root_path
    assert_response :success
    assert_compass :today
  end

  test "the archive reaches the other three" do
    get days_path
    assert_response :success
    assert_compass :days
  end

  test "the collection reaches the other three" do
    get collection_path
    assert_response :success
    assert_compass :collection
  end

  test "the gallery reaches the other three" do
    get feed_path
    assert_response :success
    assert_compass :gallery
  end

  # An archived day is a *member* of the archive, not the archive. Marking `Days`
  # here would unlink the only route from one old day back to the list — the walk
  # offers previous, next and today, and nothing else.
  test "an archived day marks nothing and links everything" do
    get day_path(@yesterday.scheduled_on.iso8601)
    assert_response :success
    assert_compass nil
  end

  test "the 404 marks nothing and links everything" do
    get "/nope"
    assert_response :not_found
    assert_compass nil
  end

  # ---------- the states where the doors used to disappear ----------

  test "the archive door is there on the very first published day" do
    @yesterday.destroy!

    get root_path

    assert_compass :today
  end

  test "the doors are there before anything is published at all" do
    DailyPick.destroy_all

    get root_path

    assert_response :success
    assert_select ".coda__line", text: "The first artwork arrives soon."
    assert_compass :today
    # Story 0011's rule survives: with no archive to go back to, the brand is
    # not a door. The compass is, which is the point.
    assert_select "span.masthead__brand"
    assert_select "a.masthead__brand", count: 0
  end

  test "the collection door is there with nothing kept" do
    get collection_path

    assert_select ".coda__line", text: "The works you keep will gather here."
    assert_compass :collection
  end

  test "the curator's preview carries the reader's compass" do
    get preview_admin_daily_pick_path(@tomorrow), headers: curator_headers

    assert_response :success
    assert_compass :today
  end

  # ---------- the gallery's rail ----------

  # /feed is the one screen whose compass is not in the masthead: its footer is
  # 110 works down an infinite scroll and its masthead is not sticky, so the
  # compass rides in a sticky rail of its own. Exactly one of them, though —
  # two <nav>s both labelled "Sections" is a defect, not a redundancy.
  test "the gallery has one compass, in the rail, and none in the masthead" do
    get feed_path

    assert_select "nav[aria-label=?]", "Sections", count: 1
    assert_select "nav.compass--rail", count: 1
    assert_select ".masthead .compass", count: 0
  end

  test "every other screen keeps its compass in the masthead" do
    [ root_path, days_path, collection_path,
      day_path(@yesterday.scheduled_on.iso8601) ].each do |path|
      get path

      assert_select ".masthead .compass", count: 1, message: "#{path} lost its compass"
      assert_select ".compass--rail", count: 0, message: "#{path} grew a rail"
    end
  end

  # ---------- the contract ----------

  # `ApplicationController.helpers` is a bare view context with no routes bound
  # to it, and resolving a route helper is half of what this method does — so the
  # contract is exercised through a real controller's view context.
  def view
    ApplicationController.new.tap { |c| c.request = ActionDispatch::TestRequest.create }.view_context
  end

  test "an unknown here: raises rather than quietly linking everything" do
    error = assert_raises(ArgumentError) { view.compass_destinations(:archive) }

    assert_match(/unknown compass key/, error.message)
  end

  test "nil is a valid here: and links all four" do
    destinations = view.compass_destinations(nil)

    assert_equal 4, destinations.size
    assert_empty destinations.select { |d| d[:current] }
    assert_equal [ root_path, days_path, collection_path, feed_path ],
      destinations.map { |d| d[:path] }
  end

  # ---------- the promise story 0007 made ----------

  # The compass renders inside the publicly cached HTML of `/` and `/days`, so it
  # has to be the same bytes for every visitor: no counts, no kept state, no
  # cookie. This is the guard that adding it did not undo story 0007.
  test "the compass leaves the public pages impersonal" do
    [ root_path, days_path ].each do |path|
      get path

      assert_select ".compass"
      assert_nil response.headers["Set-Cookie"], "#{path} started setting a cookie"
      assert_includes response.headers["Cache-Control"], "public", "#{path} stopped being public"
    end
  end
end
