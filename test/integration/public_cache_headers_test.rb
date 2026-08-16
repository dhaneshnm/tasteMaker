require "test_helper"

# The forcing function for story 0007, narrowed by story 0015.
#
# `/` is `Cache-Control: public`, and production runs behind Thruster's HTTP
# cache (Dockerfile, 64MB, enabled by default with no config file). A `public`
# response that also carries a `Set-Cookie` is a shared cache holding one
# reader's session together with the masked CSRF token baked into the same body
# — replay them together and visitor B is visitor A.
#
# Story 0015 put `/days` and `/feed` behind the wall and made them `private`
# (wall_test holds that side), which left the front door as the only public page
# — and made it matter more, not less: it is the one page every visitor state
# shares, byte-identical, with all the personal machinery behind its two private
# fragments (keep, sign-in).
#
# Story 0016 added two more, and this comment used to say the front door was the
# ONLY one. `/privacy` and `/support` are public by requirement rather than by
# choice: App Store Connect will not accept the record without them and Apple
# fetches both with no account, so they cannot go behind the wall and cannot be
# `private`. That puts them under exactly the rule this file exists to hold —
# and their `PagesController` deliberately inherits `ActionController::Base`
# rather than `ApplicationController`, so it does NOT get `no_store` and the
# other shared guards for free. Which is precisely why they are listed here.
class PublicCacheHeadersTest < ActionDispatch::IntegrationTest
  PUBLIC_PAGES = %w[/ /privacy /support].freeze

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
  # Story 0015 raises the stakes: the sign-in fragment's buttons are exactly
  # such forms, and they must arrive ONLY through the private `signin` frame —
  # the cached page carries the empty frame and none of the machinery, the
  # same split the keep control made in story 0014.
  test "no public page contains a form at all" do
    PUBLIC_PAGES.each do |path|
      get path

      assert_select "form", count: 0,
        message: "#{path} rendered a form, which writes the session on a cached page"
    end
  end

  # The cookie is the defect; the caching is deliberate and must survive the fix.
  test "the front door stays publicly cacheable and still revalidates" do
    get "/"

    assert_equal "public, no-cache", response.headers["Cache-Control"], "/ lost its caching"
    etag = response.headers["ETag"]
    assert etag.present?, "/ has no ETag to revalidate against"

    get "/", headers: { "HTTP_IF_NONE_MATCH" => etag }

    assert_response :not_modified, "/ stopped returning 304 on revalidation"
  end
end
