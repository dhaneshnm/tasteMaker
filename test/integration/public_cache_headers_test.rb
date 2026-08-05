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
  # impossible to forget beats remembering it eight times.
  setup do
    @forgery_protection_was = ActionController::Base.allow_forgery_protection
    ActionController::Base.allow_forgery_protection = true
  end

  teardown do
    ActionController::Base.allow_forgery_protection = @forgery_protection_was
  end

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
