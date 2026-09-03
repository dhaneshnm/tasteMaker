require "application_system_test_case"

# `corners_test.rb` (the integration suite) proves `.corner` lands in the
# markup on every `/you` render. It cannot prove the CSS scoped to that class
# actually applies — `assert_select` reads the DOM, not the cascade, so a
# typo'd selector (`.corner.page--empty` -> `.corner .page--empty`) or a
# deleted rule leaves the class in place and the assertion green while the
# page silently falls back to the shared `.page--empty`/`.ornament` rules
# `decisions/0025` reversed it away from. Found by /code-review, cross-session
# pass, 2026-09-03: the integration test's own comment claimed to be "the
# forcing function" against exactly that regression, which only a computed-
# style check can actually be.
class CornersSystemTest < ApplicationSystemTestCase
  test "the corner's scoped spacing and ornament actually apply, not just the class name" do
    visit corner_path

    metrics = page.evaluate_script(<<~JS)
      (() => {
        const main = document.querySelector("main.corner");
        const ornament = document.querySelector(".ornament");
        return {
          paddingTop: parseFloat(getComputedStyle(main).paddingTop),
          ornamentBefore: getComputedStyle(ornament, "::before").content
        };
      })()
    JS

    # The shared `.page--empty` clamp floors at 4rem (64px); `.corner`'s
    # override caps at 2.5rem (40px). Any value under 64px could only have
    # come from the scoped rule actually winning the cascade.
    assert metrics["paddingTop"] < 64,
      "expected .corner's tight top padding, got the shared .page--empty clamp's floor or wider (#{metrics["paddingTop"]}px)"
    assert_equal "none", metrics["ornamentBefore"],
      "expected no flanking dash before the ornament mark"
  end
end
