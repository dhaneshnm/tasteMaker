require "test_helper"

# The third conditional-GET hole, and the general case of the other two.
#
# `/` and `/days` are `public, no-cache` with an ETag (story 0007), so every
# visit revalidates and normally gets a cheap 304. That ETag is built from model
# rows, the importmap digest, and the stylesheet digest. None of those move when
# the TEXT of a template changes.
#
# `stale_when_importmap_changes` was added after a JavaScript change shipped
# behind a 304. `stylesheet_etag_test.rb` exists because a CSS change did the
# same thing (commit ae742dc) and left the page unstyled forever. Both are
# special cases of: the page is rendered from templates, and the templates are
# not in the key.
#
# Renaming this product to Tondo changed nothing but template text — six
# mastheads, seven titles, the meta name — on every screen at once. Without the
# revision in the key, every browser holding the old HTML would have kept
# reading "Tastemaker" indefinitely, because each reload revalidates into the
# same 304.
class TemplateEtagTest < ActionDispatch::IntegrationTest
  # Exactly the conditional-GET surface. A page with no ETag cannot have this
  # bug, so the list is the same one `stylesheet_etag_test.rb` uses.
  CACHED_PAGES = %w[/ /days].freeze

  test "a deploy stops the browser being handed a 304" do
    CACHED_PAGES.each do |path|
      get path

      assert_response :success, "#{path} did not render"
      etag = response.headers["ETag"]
      assert etag.present?, "#{path} has no ETag, so this test proves nothing about it"

      with_revision("a-later-deploy") do
        get path, headers: { "HTTP_IF_NONE_MATCH" => etag }
      end

      assert_response :success,
        "#{path} returned 304 after a deploy — every returning reader keeps the " \
        "previous copy of the page, including whatever text just changed"
    end
  end

  # The other half of the rule: what comes back must carry the new text. A 200
  # with stale markup would fail just as badly as the 304.
  test "the re-rendered page carries the current brand" do
    with_revision("a-later-deploy") do
      get "/"

      assert_select ".masthead__brand", text: "Tondo"
    end
  end

  # Copied deliberately from `stylesheet_etag_test.rb`, which carries the same
  # case: the first version of that fix used Rails' `request.format.html?`
  # guard, and a client sending `Accept: */*` has a format of `*/*`, not html.
  # The guard skipped exactly that client and handed it the stale-forever 304
  # while the browser beside it recovered.
  test "a client sending Accept: */* is covered too" do
    get "/", headers: { "HTTP_ACCEPT" => "*/*" }

    assert_response :success
    etag = response.headers["ETag"]

    with_revision("a-later-deploy") do
      get "/", headers: { "HTTP_ACCEPT" => "*/*", "HTTP_IF_NONE_MATCH" => etag }
    end

    assert_response :success, "an Accept: */* client still got a 304 after a deploy"
  end

  # Guards against the fix overshooting into "never 304 again", which would
  # throw away story 0007's caching to fix a cache-invalidation bug. Between
  # deploys the revision is constant and revalidation must still be cheap.
  test "an unchanged deploy still revalidates into a 304" do
    CACHED_PAGES.each do |path|
      get path
      etag = response.headers["ETag"]

      get path, headers: { "HTTP_IF_NONE_MATCH" => etag }

      assert_response :not_modified, "#{path} stopped returning 304 when nothing changed"
    end
  end

  # A blank REVISION file in development must not be able to blank the input —
  # an ETag component that is silently empty is the bug wearing a fix.
  test "the revision is never blank" do
    assert Rails.application.config.x.revision.present?,
      "config.x.revision is blank, so it contributes nothing to the ETag"
  end

  private
    # Stands in for "somebody deployed". The value comes from the REVISION file
    # the Dockerfile writes per image build; swapping it is the smallest way to
    # simulate the next deploy without rebuilding anything.
    def with_revision(value)
      original = Rails.application.config.x.revision
      Rails.application.config.x.revision = value
      yield
    ensure
      Rails.application.config.x.revision = original
    end
end
