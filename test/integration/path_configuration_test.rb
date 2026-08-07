require "test_helper"

# The forcing function for story 0008's path configuration.
#
# The file exists twice on purpose. The bundled copy loads synchronously on a
# cold launch with no network; the served copy is fetched afterwards and lets
# navigation rules change without an App Store review. Hotwire Native merges them
# in that order, so the served copy wins — which is the whole point, and also the
# whole risk: the two can drift, and nothing on either side would say so.
#
# What drift actually costs here is the back button. `decisions/0006` hides the
# native navigation bar, and the thing paying for that is the `clear_all` rule on
# `^/$` — without it, tapping the brand pushes a fourth screen instead of
# unwinding to the root, the stack grows without bound, and swipe-back walks
# backwards through duplicate front doors.
class PathConfigurationTest < ActionDispatch::IntegrationTest
  BUNDLED = Rails.root.join("ios/Tastemaker/path-configuration.json")
  SERVED  = "/configurations/ios_v1.json".freeze

  test "the served configuration is there and is JSON" do
    get SERVED

    assert_response :success
    assert_nothing_raised { JSON.parse(response.body) }
  end

  test "the bundled and served configurations are byte-identical" do
    get SERVED

    assert_equal BUNDLED.read, response.body,
      "the bundled path configuration has drifted from the one this app serves"
  end

  # Patterns are unanchored regexes: `PathRule.match` runs
  # `NSRegularExpression.numberOfMatches` with no anchoring, so a pattern of "/"
  # would match every path in the product. Every pattern is anchored on purpose
  # and this is the only place that fact can be enforced from.
  test "every pattern is anchored" do
    rules(BUNDLED).each do |rule|
      rule["patterns"].each do |pattern|
        assert pattern.start_with?("^"),
          "#{pattern.inspect} is unanchored, so it matches every path that merely contains it"
      end
    end
  end

  test "the front door unwinds the stack instead of growing it" do
    root = rules(BUNDLED).find { |r| r["patterns"].include?("^/$") }

    assert root, "no rule for the front door"
    assert_equal "clear_all", root["properties"]["presentation"],
      "the brand link pushes a duplicate front door; with no native back button the stack is one-way"
  end

  # `/admin` is HTTP Basic behind a browser auth dialog WKWebView handles badly,
  # and `/feed` is infinite scroll, where pull-to-refresh fights the scroll
  # gesture at the top of the list.
  test "the two screens that must not behave like the others keep their rules" do
    feed = rules(BUNDLED).find { |r| r["patterns"].include?("^/feed$") }
    admin = rules(BUNDLED).find { |r| r["patterns"].include?("^/admin") }

    assert_equal false, feed["properties"]["pull_to_refresh_enabled"]
    assert_equal "none", admin["properties"]["presentation"]
  end

  private
    def rules(path)
      JSON.parse(path.read).fetch("rules")
    end
end
