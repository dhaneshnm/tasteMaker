require "test_helper"

# The forcing function for story 0004.
#
# These run with `show_exceptions` on, because the whole subject is what a reader
# sees when a request fails — and the test environment's default is to re-raise
# instead of rendering, which is the opposite of what this page exists for.
class ErrorsTest < ActionDispatch::IntegrationTest
  with_rescued_exceptions!

  test "a date with no artwork says so, and still answers 404" do
    get day_path("2020-01-01")

    assert_response :not_found
    assert_select ".coda__line", text: "There was no artwork on that day."
    assert_select ".page--empty"
  end

  # Passes the route's date regex but is not a real date — the case that used to
  # raise rather than 404 (story 0003).
  test "a well-formed date that is not a real one 404s rather than erroring" do
    get "/days/2026-02-31"

    assert_response :not_found
    assert_select ".coda__line", text: "There was no artwork on that day."
  end

  # The archive's no-leak rule, now running through the new page: a queued day
  # must be indistinguishable from a day that never existed.
  test "a queued future day still 404s" do
    get day_path(daily_picks(:tomorrow).scheduled_on.iso8601)

    assert_response :not_found
  end

  test "an unrouted path 404s with the generic line, not the day one" do
    get "/nope"

    assert_response :not_found
    assert_select ".coda__line", text: "That page does not exist."

    # This page used to offer exactly one way out. A page that does not exist is
    # not one of the four surfaces, so the compass marks nothing and links
    # everything.
    assert_select ".compass a", count: 4
    assert_select ".compass span[aria-current]", count: 0
    assert_select ".compass a[href=?]", root_path, text: "Today"
  end

  # Story 0007's rule reaches this page too: it renders the reader's layout, so
  # it must not write the session either.
  test "the error page sets no cookie" do
    with_forgery_protection do
      get "/nope"

      assert_response :not_found
      assert_nil response.headers["Set-Cookie"], "the 404 page set a cookie"
      assert_select "meta[name=?]", "csrf-token", count: 0
    end
  end
end
