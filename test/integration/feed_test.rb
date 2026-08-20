require "test_helper"

# Story 0020 — the walled half of the keep control's two architectures. `/`'s
# half lives in `test/integration/favorites_test.rb`; this is `/feed`'s.
class FeedTest < ActionDispatch::IntegrationTest
  behind_the_wall!

  setup do
    Painting.create!(source: "mia", source_id: 950_000, title: "A Filler Work",
      artist: "A. Painter", image_url_800: paintings(:woodcut).image_url_800)
  end

  # Matches `artists_test.rb`'s own copy — kept local rather than shared, the
  # same call the eng review made about `sql_queries` living wherever the
  # file that needs a query count first needed it.
  def sql_queries
    queries = []
    callback = ->(*args) { queries << args.last[:sql] }
    ActiveSupport::Notifications.subscribed(callback, "sql.active_record") { yield }
    queries.reject { |sql| sql.match?(/\A\s*(BEGIN|COMMIT|ROLLBACK|SAVEPOINT|RELEASE)/i) }
  end

  # The forcing function for story success signal 2 — "zero extra round
  # trips". `/`'s frame carries `src:`; the walled surfaces render the real
  # control inline, so a regression back to a fetching frame shows up here as
  # a `src` attribute on a `/feed` keep frame.
  test "the gallery's keep frames carry no src — the control is inline, not fetched" do
    get feed_path

    assert_response :success
    frames = css_select("turbo-frame[id^=keep_]")
    assert frames.any?, "no keep frames rendered on /feed"
    frames.each { |frame| assert_nil frame["src"], "a /feed keep frame still fetches" }
  end

  # One query, not ten, and not twenty: `kept_ids_for` reads the whole page's
  # favorites in a single indexed range scan, whatever the state of any
  # individual work — not one aggregate per work the way the eager, fetched
  # design on `/` would cost if copied verbatim onto ten posts.
  test "one favorites query serves the whole gallery page, kept or not" do
    empty_page_queries = sql_queries { get feed_path }
    favorites_queries = empty_page_queries.select { |sql| sql.match?(/FROM "favorites"/) }
    assert_equal 1, favorites_queries.size,
      "expected exactly one favorites query on an empty-handed page, got #{favorites_queries.size}"

    post favorite_path(Painting.find_by!(title: "A Filler Work"))
    assert_response :success

    kept_page_queries = sql_queries { get feed_path }
    favorites_queries = kept_page_queries.select { |sql| sql.match?(/FROM "favorites"/) }
    assert_equal 1, favorites_queries.size,
      "the favorites query count grew once something was kept — not the flat cost the design promises"
  end

  # A1 (`/plan-eng-review`) — the direct assertion that the middleware, not
  # this controller, is what makes the page's per-reader body safe to
  # revalidate. `/feed` adds no freshness code of its own (no `no_store`, no
  # manual ETag); `Rack::ETag`'s automatic body digest is what has to be
  # doing the work if this passes.
  test "the gallery is private and never public, and still carries an ETag" do
    get feed_path

    assert_response :success
    assert_match(/private/, response.headers["Cache-Control"])
    assert_no_match(/public/, response.headers["Cache-Control"])
    assert response.headers["ETag"].present?,
      "expected Rack::ETag's automatic body digest — the freshness section depends on it existing"
  end

  # Regression, found live (2026-08-20): the lazy next-page frame's
  # placeholder tag omitted `target: "_top"`, and Turbo never copies a loaded
  # response's own frame attributes onto the element already in the DOM — it
  # only replaces content. So every artist-name link past page 1 silently
  # scoped its click to that frame instead of breaking out to a full visit;
  # `/artists/:slug` carries no `feed-page-N` frame in its response, and
  # Turbo answered by replacing the whole page's worth of cards with the
  # literal words "Content missing". Reproduced by forcing the frame's own
  # `src` to (re)load and clicking an artist link inside it — the same
  # sequence a scroll-then-tap makes for real. Asserting the placeholder
  # attribute directly (not a click) because that IS the bug: the frame
  # never gets a second chance to pick `target` up after this point.
  test "the lazy next-page frame targets _top on its placeholder, before it has ever loaded" do
    11.times do |i|
      Painting.create!(source: "mia", source_id: 951_000 + i, title: "Filler #{i}",
        artist: "A. Painter", image_url_800: paintings(:woodcut).image_url_800)
    end

    get feed_path

    assert_response :success
    next_frame = css_select("turbo-frame[id^='feed-page-'][src]").first
    assert next_frame, "expected a lazy next-page frame once the pool outgrows one page"
    assert_equal "_top", next_frame["target"],
      "the lazy frame's placeholder must carry target=_top itself — a value that only " \
      "arrives with the loaded content is too late, Turbo never copies it onto the " \
      "frame element already in the DOM"
  end
end
