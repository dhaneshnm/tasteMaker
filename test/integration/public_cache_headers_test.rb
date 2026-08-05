require "test_helper"

# The forcing function for story 0007.
#
# `/` and `/days` are `Cache-Control: public`, and production runs behind
# Thruster's HTTP cache (Dockerfile, 64MB, enabled by default with no config
# file). A `public` response that also carries a `Set-Cookie` is a shared cache
# holding one reader's session together with the masked CSRF token baked into
# the same body — replay them together and visitor B is visitor A.
#
# Before this story every public page emitted `_taste_maker_session`, because
# `csrf_meta_tags` writes `session[:_csrf_token]` just by rendering. Nothing else
# on the public path touches the session, so removing that tag is the whole fix.
class PublicCacheHeadersTest < ActionDispatch::IntegrationTest
  PUBLIC_PAGES = %w[/ /days /feed].freeze

  # Forgery protection goes on for the whole file, not per test.
  #
  # The suite disables it, and `csrf_meta_tags` returns nil when it is off
  # without ever calling `form_authenticity_token`. So a test written here
  # without it would pass against the OLD layout too, proving nothing. This
  # file's entire subject is CSRF and session behaviour, so making that
  # impossible to forget beats remembering it once per test.
  with_forgery_protection!

  test "no public page sets a cookie" do
    PUBLIC_PAGES.each do |path|
      get path

      assert_response :success, "#{path} did not render"
      assert_nil response.headers["Set-Cookie"],
        "#{path} set a cookie: #{response.headers["Set-Cookie"]}"
    end

    get day_path(daily_picks(:yesterday).scheduled_on.iso8601)

    assert_response :success
    assert_nil response.headers["Set-Cookie"], "a past day set a cookie"
  end

  test "no public page renders a CSRF meta tag" do
    PUBLIC_PAGES.each do |path|
      get path

      assert_select "meta[name=?]", "csrf-token", count: 0,
        message: "#{path} rendered a CSRF meta tag, which is what writes the session"
    end
  end

  # The general form of the rule, and the one that survives refactoring.
  #
  # A form is the other way a page writes the session: `form_with` and
  # `button_to` both emit `form_authenticity_token`, which writes
  # `session[:_csrf_token]`, which emits `Set-Cookie` — on a response a shared
  # cache is allowed to store and replay.
  #
  # This exists because `days/_row.html.erb` renders a Remove button for any row
  # whose pick is nil. `/days` iterates published picks so it never reaches that
  # branch today, but that is a property of the caller, not of the partial: the
  # moment any publicly cached page renders a pick-less row, the defect is back.
  # A comment cannot catch that. This can.
  test "no public page contains a form at all" do
    PUBLIC_PAGES.each do |path|
      get path

      assert_select "form", count: 0,
        message: "#{path} rendered a form, which writes the session on a cached page"
    end

    get day_path(daily_picks(:yesterday).scheduled_on.iso8601)

    assert_select "form", count: 0, message: "a past day rendered a form"
  end

  # The cookie is the defect; the caching is deliberate and must survive the fix.
  test "the day page and the archive stay publicly cacheable and still revalidate" do
    %w[/ /days].each do |path|
      get path

      assert_equal "public, no-cache", response.headers["Cache-Control"], "#{path} lost its caching"
      etag = response.headers["ETag"]
      assert etag.present?, "#{path} has no ETag to revalidate against"

      get path, headers: { "HTTP_IF_NONE_MATCH" => etag }

      assert_response :not_modified, "#{path} stopped returning 304 on revalidation"
    end
  end
end
