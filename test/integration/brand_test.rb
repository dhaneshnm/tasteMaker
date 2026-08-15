require "test_helper"

# The forcing function for `decisions/0007-the-name-is-tondo.md`.
#
# A rename is a one-time sweep unless something keeps it swept. Fifteen places
# typed the old brand and six views carried their own copy of the masthead;
# story 0011 reduced both to one partial and one string, and these tests are
# what stops the next copy-paste quietly undoing it.
#
# The masthead partial has one variance that is easy to flatten by accident and
# that nothing else in the suite covers — see the empty-state test below.
class BrandTest < ActionDispatch::IntegrationTest
  behind_the_wall!

  # The 404 carries a masthead too, and the test environment re-raises instead
  # of rendering it by default. Same reason `errors_test.rb` does this.
  with_rescued_exceptions!

  BRAND = "Tondo".freeze
  MANIFEST = Rails.root.join("app/views/pwa/manifest.json.erb")

  # Every reader-facing screen, and what its brand element is.
  #
  #   linked ── the brand is a door back to today
  #   span   ── the empty state, where there is nowhere yet to go
  LINKED_PAGES = {
    "the daily page" => -> { root_path },
    "the archive index" => -> { days_path },
    "a past day" => -> { day_path(date: 1.day.ago.to_date.iso8601) },
    "the collection" => -> { collection_path },
    "the gallery" => -> { feed_path }
  }.freeze

  LINKED_PAGES.each do |name, path|
    test "#{name} wears the brand as a link home" do
      get instance_exec(&path)

      assert_response :success
      assert_select "a.masthead__brand[href=?]", root_path, text: BRAND
    end
  end

  test "the 404 wears the brand as a link home" do
    get "/no-such-page"

    assert_response :not_found
    assert_select "a.masthead__brand[href=?]", root_path, text: BRAND
  end

  # REGRESSION. `daily/empty.html.erb` rendered `<span class="masthead__brand">`
  # long before the partial existed: with no published pick there is no archive,
  # so the brand is not a door and must not look like one. Extracting six
  # near-identical mastheads into one partial is exactly the change that turns
  # this into an `<a>` pointing at the page you are already on, and no test
  # covered it before this one.
  test "the empty state's brand is a span, not a link" do
    DailyPick.delete_all

    get root_path

    assert_response :success
    assert_select "span.masthead__brand", text: BRAND
    assert_select "a.masthead__brand", count: 0
  end

  test "the aside is rendered where a page has one, and omitted where it does not" do
    get days_path
    assert_select ".masthead__aside", text: /day/

    get "/no-such-page"
    assert_select ".masthead__aside", count: 0
  end

  test "the head says the brand" do
    get root_path

    assert_select "meta[name=application-name][content=?]", BRAND
    assert_select "title", text: /#{BRAND}/
  end

  # Read from disk, not over HTTP, because **nothing serves this file**.
  # `config/routes.rb` has no PWA route and no layout carries a
  # `<link rel="manifest">`, so `app/views/pwa/` is Rails 8 scaffolding that has
  # never been reachable. These assertions keep it correct for whenever it is
  # wired up; they do not claim it is live. The file has zero ERB tags, so
  # parsing it as JSON is exact rather than approximate.
  test "the manifest says the brand" do
    manifest = JSON.parse(MANIFEST.read)

    assert_equal BRAND, manifest["name"]
    assert_equal BRAND, manifest["short_name"]
  end

  # The classic PWA mistake is one file declared for both purposes: a maskable
  # icon is padded for the crop, so used as `any` it looks small, and an `any`
  # icon used as maskable loses its edges. They are different images here.
  test "the manifest's any and maskable icons are different files" do
    icons = JSON.parse(MANIFEST.read)["icons"]
    any = icons.find { |i| i["purpose"] == "any" }
    maskable = icons.find { |i| i["purpose"] == "maskable" }

    assert any, "no icon declared with purpose: any"
    assert maskable, "no icon declared with purpose: maskable"
    refute_equal any["src"], maskable["src"],
      "the same file is declared for both purposes — one of the two is always wrong"
  end

  # The guard. Scoped to text files so it cannot trip on `credentials.yml.enc`
  # or anything else binary, and to `app/` and `config/` because history keeps
  # the old name on purpose (SHIPLOG, decisions/0001-0006, shipped specs).
  test "the old brand does not come back under app/ or config/" do
    offenders = %w[app config].flat_map { |dir|
      Dir.glob(Rails.root.join(dir, "**", "*")).select { |path|
        next false unless File.file?(path)
        next false if File.binread(path, 8000).to_s.include?("\x00")

        File.read(path).match?(/tastemaker/i)
      }
    }

    assert_empty offenders,
      "the old brand reappeared in:\n  #{offenders.join("\n  ")}\n" \
      "See decisions/0007-the-name-is-tondo.md."
  end
end
