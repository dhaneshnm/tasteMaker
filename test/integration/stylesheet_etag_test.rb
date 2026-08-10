require "test_helper"
require "delegate"

# The forcing function for the conditional-GET half of the asset pipeline.
#
# `/` and `/days` are `public, no-cache` with an ETag (story 0007), so every
# visit revalidates and normally gets a cheap 304. Those ETags were keyed on
# model data alone — the pick, the painting, the published count. A CSS change
# moves the asset digest without touching any of those, so a returning browser
# revalidated, got a 304, and kept HTML linking `/assets/application-<old>.css`.
# That URL is gone the moment the digest moves, so the page rendered completely
# unstyled — and stayed that way, because every reload revalidated into the same
# 304. This is what shipping story 0009 did to an already-open browser.
#
# Rails ships `stale_when_importmap_changes` for the JavaScript half and nothing
# for CSS. `ApplicationController`'s `etag` block is the CSS half; these tests
# are what stops it being deleted as redundant.
class StylesheetEtagTest < ActionDispatch::IntegrationTest
  # Pages that revalidate rather than re-render. If a page has no ETag it cannot
  # have this bug, so the list is exactly the conditional-GET surface.
  CACHED_PAGES = %w[/ /days].freeze

  # Stands in for "somebody shipped a CSS change". Answers `application.css`
  # with a different digest and passes every other asset straight through, which
  # is what a real edit to the stylesheet does to the resolver.
  class ShippedStylesheetChange < SimpleDelegator
    BUMPED = "0badcafe".freeze

    def resolve(logical_path)
      resolved = __getobj__.resolve(logical_path)
      return resolved unless logical_path.to_s.end_with?(".css")

      resolved&.sub(/-\h+(\.css)\z/, "-#{BUMPED}\\1")
    end
  end

  test "a stylesheet change stops the browser being handed a 304" do
    CACHED_PAGES.each do |path|
      get path

      assert_response :success, "#{path} did not render"
      etag = response.headers["ETag"]
      assert etag.present?, "#{path} has no ETag, so this test proves nothing about it"

      with_shipped_stylesheet_change do
        get path, headers: { "HTTP_IF_NONE_MATCH" => etag }
      end

      assert_response :success,
        "#{path} returned 304 after the stylesheet digest moved — the browser keeps HTML " \
        "pointing at a stylesheet URL that no longer resolves and renders unstyled"
    end
  end

  # The other half of the same rule: what the browser gets back must actually
  # link the new sheet. A 200 carrying the old markup would fail just as badly.
  test "the re-rendered page links the new stylesheet" do
    with_shipped_stylesheet_change do
      get "/"

      assert_select "link[rel=stylesheet][href*=?]", ShippedStylesheetChange::BUMPED,
        message: "the page did not link the changed stylesheet"
    end
  end

  # The first version of the fix carried Rails' `request.format.html?` guard,
  # copied from `stale_when_importmap_changes`. A client sending `Accept: */*`
  # has a format of `*/*`, not html, so the guard skipped it and handed exactly
  # that client the stale-forever 304 — while the browser next to it recovered.
  # Same URL, same body, ETag decided by a request header.
  test "a client sending Accept: */* is covered too" do
    get "/", headers: { "HTTP_ACCEPT" => "*/*" }

    assert_response :success
    etag = response.headers["ETag"]

    with_shipped_stylesheet_change do
      get "/", headers: { "HTTP_ACCEPT" => "*/*", "HTTP_IF_NONE_MATCH" => etag }
    end

    assert_response :success, "an Accept: */* client still got a 304 after the stylesheet changed"
  end

  # Guards against the fix overshooting into "never 304 again", which would throw
  # away story 0007's caching to fix a cache-invalidation bug.
  test "an unchanged stylesheet still revalidates into a 304" do
    CACHED_PAGES.each do |path|
      get path
      etag = response.headers["ETag"]

      get path, headers: { "HTTP_IF_NONE_MATCH" => etag }

      assert_response :not_modified, "#{path} stopped returning 304 when nothing changed"
    end
  end

  private
    # Swapping the resolver is the smallest way to move a digest: the real
    # alternative is writing to `app/assets/stylesheets` mid-test and hoping the
    # cache sweeper agrees about when it happened.
    def with_shipped_stylesheet_change
      assembly = Rails.application.assets
      original = assembly.resolver
      assembly.instance_variable_set(:@resolver, ShippedStylesheetChange.new(original))
      yield
    ensure
      assembly.instance_variable_set(:@resolver, original)
    end
end
