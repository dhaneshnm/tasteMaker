require "test_helper"

# The forcing function for story 0016's two mandatory URLs.
#
# App Store Connect will not accept the record without a privacy policy URL and
# a support URL, and Apple fetches both WITHOUT an account. Story 0015's wall
# bounces every reader-facing endpoint to `/you`, so a legal page that ever
# ends up behind it is a 5.1.1 rejection — and a silent one, because nobody on
# this side of the wall ever sees the bounce.
class PagesTest < ActionDispatch::IntegrationTest
  PAGES = %w[/privacy /support].freeze

  # A real Safari 14 string. NOT an empty or nonsense user agent, and this is the
  # whole point of the test.
  #
  # `allow_browser versions: :modern` only blocks agents Rails can IDENTIFY as
  # old; curl, an empty UA and every bot sail through. Measured against
  # production while planning this story: Safari 14 → 406, curl → 200, empty →
  # 200, AppleBot → 200. So a test written with an empty UA passes whether or not
  # the browser gate applies, which is exactly how the original plan's
  # `skip_before_action :allow_browser` would have shipped green while raising at
  # class definition or silently doing nothing.
  OLD_SAFARI = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) " \
               "AppleWebKit/605.1.15 (KHTML, like Gecko) Version/14.0 Safari/605.1.15".freeze

  test "answer 200 with no session and no device cookie" do
    PAGES.each do |path|
      get path
      assert_response :success, "#{path} must answer anonymously — Apple fetches it with no account"
    end
  end

  test "answer 200 to a browser the rest of the app turns away" do
    PAGES.each do |path|
      get path, headers: { "HTTP_USER_AGENT" => OLD_SAFARI }
      assert_response :success,
        "#{path} answered #{response.status} to Safari 14 — a reader on old hardware gets " \
        "public/406-unsupported-browser.html where the privacy policy should be"
    end
  end

  # The rest of the app SHOULD still turn that browser away. Without this, the
  # test above would keep passing if someone removed `allow_browser` from
  # ApplicationController entirely — proving nothing about these two pages.
  test "the browser gate is still armed everywhere else" do
    get root_path, headers: { "HTTP_USER_AGENT" => OLD_SAFARI }
    assert_response :not_acceptable
  end

  test "render through the real view, so the compass contract is exercised" do
    # `compass_destinations` raises ArgumentError on any key outside
    # COMPASS_KEYS, and these pages are not compass destinations — they pass
    # `here: nil`. A controller-only assertion would pass either way; this fails
    # loudly if someone "helpfully" passes `here: :privacy`.
    PAGES.each do |path|
      get path
      assert_select "nav.compass"
      assert_select "nav.compass [aria-current='page']", count: 0
    end
  end

  test "the privacy page states what it must" do
    get "/privacy"
    assert_select ".doc__stamp", /Last updated/
    assert_select ".doc", /support@dailytondo\.com/
    assert_select ".doc", /Delete account/
    assert_select ".doc", /Delete this device/
  end

  test "the support page carries the contact address" do
    get "/support"
    assert_select ".doc", /support@dailytondo\.com/
  end

  test "each page links to the other" do
    get "/privacy"
    assert_select "a[href=?]", support_path

    get "/support"
    assert_select "a[href=?]", privacy_path
  end
end
