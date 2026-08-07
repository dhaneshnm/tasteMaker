require "test_helper"

# The forcing function for story 0008's safe-area work.
#
# This is the half of story 0008 that changes the *shipped website* rather than
# the shell, which is why it lands as its own revertable commit — and why it
# needs its own check. `viewport-fit=cover` and the `env()` padding are a matched
# pair: the meta tag is what makes every `env(safe-area-inset-*)` in the
# stylesheet resolve to something other than 0, and the padding is what stops the
# page from sliding under the notch once it does.
#
# Delete either one and the other becomes silently wrong. Deleting the meta tag
# is the quieter failure: nothing breaks, every inset just goes back to 0, and
# `.zoom` starts rendering linen bands at the notch again — which is precisely
# the defect design review found, sitting undiscovered because `.zoom__close` had
# been written against an `env()` that had never once resolved to a real value.
#
# No system test can catch this. `test/system/` runs headless Chrome at 375x667,
# where the insets are 0 and always will be.
class SafeAreaTest < ActionDispatch::IntegrationTest
  with_rescued_exceptions!

  PAGES = %w[/ /days /feed /nope].freeze

  test "every page opts into the full screen" do
    PAGES.each do |path|
      get path

      assert_select "meta[name=viewport]" do |tags|
        assert_includes tags.first["content"], "viewport-fit=cover",
          "#{path} does not opt into the unsafe strips, so every env() inset on it is 0"
      end
    end
  end

  def stylesheet
    get "/"
    get css_select("link[rel=stylesheet]").first["href"]
    response.body
  end

  # The page has to actually use the room it just claimed.
  test "the chrome keeps clear of the notch and the home indicator" do
    css = stylesheet

    assert_includes css, "env(safe-area-inset-top)",
      "nothing clears the notch, so the masthead renders under the status bar"
    assert_includes css, "env(safe-area-inset-bottom)",
      "nothing clears the home indicator"
    assert_includes css, "env(safe-area-inset-left)",
      "nothing clears the rounded corner in landscape"
    assert_includes css, "env(safe-area-inset-right)",
      "nothing clears the rounded corner in landscape"
  end

  # `max(0.9rem, env(...))` is the trap, not a style preference: under `cover` the
  # inset is the full height of the unsafe strip, so `max()` resolves to the inset
  # and puts the close button flush against the status bar. The gap has to be
  # added to the inset, not compared against it.
  test "the close button adds its gap to the inset rather than competing with it" do
    assert_no_match(/max\(\s*[\d.]+rem,\s*env\(safe-area-inset/, stylesheet,
      "a safe-area inset is being max()'d against a fixed gap, which cancels the gap")
  end

  # DESIGN.md rule 1: colour comes from the token table. The mount board was the
  # one hardcoded hex in the file, and story 0008 needs the same value in
  # `Assets.xcassets` — two copies of a literal is how they drift.
  test "the mount board is a token, not a literal" do
    css = stylesheet

    assert_includes css, "--mount-bg: #100e0b", "the mount board lost its token"
    assert_equal 1, css.scan("#100e0b").size,
      "#100e0b appears outside the token definition; the full-screen surround should use var(--mount-bg)"
  end
end
