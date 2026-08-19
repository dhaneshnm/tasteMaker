require "test_helper"

class ArtistsTest < ActionDispatch::IntegrationTest
  behind_the_wall!

  # The 404 tests below need `show_exceptions` on — see errors_test.rb, whose
  # comment explains why the test environment's default (re-raise instead of
  # rendering) is the opposite of what these assert.
  with_rescued_exceptions!

  # A count-of-database-queries assertion the suite otherwise has no need for
  # — see the T17/E-A2/E-A3 tests below, which need to prove a query count
  # rather than a specific value.
  def sql_queries
    queries = []
    callback = ->(*args) { queries << args.last[:sql] }
    ActiveSupport::Notifications.subscribed(callback, "sql.active_record") { yield }
    queries.reject { |sql| sql.match?(/\A\s*(BEGIN|COMMIT|ROLLBACK|SAVEPOINT|RELEASE)/i) }
  end

  test "a known slug renders that artist's works and nothing else" do
    get artist_path("berthe-morisot")

    assert_response :success
    assert_select "article.post", count: 2
    assert_select "h1.label__title", text: "Berthe Morisot"
    assert_no_match paintings(:sunflowers).title, response.body
  end

  test "an unknown slug 404s, and does not say it was about a day" do
    get artist_path("pablo-picasso")

    assert_response :not_found
    assert_no_match(/on that day/, response.body)
    assert_match(/No artist by that name here/, response.body)
  end

  # E2. The deny-list's forcing function — a request that maps to a real
  # fixture row, not a slug nobody holds.
  test "a deny-listed culture string 404s the same way an unknown slug does" do
    get artist_path("china")

    assert_response :not_found
    assert_match(/No artist by that name here/, response.body)
  end

  # X5. A one-work artist is a real, reachable page — not a 404. The link
  # rule (link only when `artist_slug` is present) is the only gate.
  test "a one-work artist is a real page, not a 404" do
    get artist_path("vincent-van-gogh")

    assert_response :success
    assert_select "article.post", count: 1
    assert_select "h1.label__title", text: "Vincent van Gogh"
  end

  # E4. "Most frequent" alone would title this page "Paul Cezanne" — the
  # fixtures are 1-1, so only the accent-preferring rule settles it.
  test "the heading prefers the accented spelling" do
    get artist_path("paul-cezanne")

    assert_response :success
    assert_select "h1.label__title", text: "Paul Cézanne"
    assert_select "article.post", count: 2
  end

  # D2. The name is the h1's job; the wall label under each work must not
  # repeat it. (The name legitimately appears elsewhere too — `<title>`, the
  # description meta tag, each work's `alt` text — none of that is the
  # visible repetition D2 exists to prevent.)
  test "the artist's name is not repeated in the wall label under each work" do
    get artist_path("berthe-morisot")

    assert_select "article.post .label__artist", count: 0
  end

  # The uniform life_date shows once, under the heading; both Morisot
  # fixtures carry the same string.
  test "a uniform life date renders once, under the heading" do
    get artist_path("berthe-morisot")

    assert_select ".artist-page__dates", text: "1841–1895"
  end

  # D14. The Hotwire Native shell reads this for its pushed-screen heading.
  test "the tab title carries the artist name" do
    get artist_path("vincent-van-gogh")

    assert_select "title", "Vincent van Gogh — Tondo"
  end

  # D5. `artwork_controller.js` is a page-level singleton — without its own
  # data-controller and overlay, every `.plate__zoom` on this page is dead.
  test "the page mounts its own zoom overlay" do
    get artist_path("berthe-morisot")

    assert_select "main.page[data-controller=artwork]"
    assert_select ".zoom[role=dialog][aria-modal=true]", count: 1
    assert_select "button.plate__zoom", count: 2
  end

  test "the page ends with the ornament and nothing else" do
    get artist_path("berthe-morisot")

    assert_select ".coda .ornament"
    assert_select ".coda .coda__line", count: 0
  end

  test "the page revalidates instead of going stale" do
    get artist_path("berthe-morisot")

    assert_response :success
    assert_match "no-cache", response.headers["Cache-Control"]
    assert_match "private", response.headers["Cache-Control"]
    assert response.headers["ETag"].present?, "expected an ETag to revalidate against"
  end

  test "an unchanged artist page costs a 304" do
    get artist_path("berthe-morisot")
    etag = response.headers["ETag"]

    get artist_path("berthe-morisot"), headers: { "HTTP_IF_NONE_MATCH" => etag }
    assert_response :not_modified
  end

  # E-A2. `with_attached_image` must be present, or attachment queries scale
  # with the number of works on the page — compared against a 1-work page.
  test "attachment queries do not grow with the number of works on the page" do
    # Warms two one-time costs that would otherwise look like an N+1 paid by
    # whichever request runs first: the device's debounced `note_seen`
    # write, and Active Storage's schema introspection (PRAGMA table_xinfo),
    # cached after its first query in the process.
    get artist_path("vincent-van-gogh")

    one_work_queries = sql_queries { get artist_path("vincent-van-gogh") }
    two_work_queries = sql_queries { get artist_path("berthe-morisot") }

    assert_equal one_work_queries.size, two_work_queries.size,
      "query count grew with the number of works — with_attached_image may be missing " \
      "(1 work: #{one_work_queries.size}, 2 works: #{two_work_queries.size})"
  end

  # E-A3. Aggregates-first means a 304 never touches Active Storage.
  test "revalidating a 304 runs no Active Storage query" do
    get artist_path("berthe-morisot")
    etag = response.headers["ETag"]

    queries = sql_queries { get artist_path("berthe-morisot"), headers: { "HTTP_IF_NONE_MATCH" => etag } }

    assert_response :not_modified
    storage_queries = queries.select { |sql| sql.match?(/active_storage/i) }
    assert_empty storage_queries, "a 304 ran an Active Storage query: #{storage_queries}"
  end
end
