require "application_system_test_case"

# The forcing function for story 0008's Dynamic Type support (T10).
#
# The shell scales the page by setting a root font size from
# `UIApplication.preferredContentSizeCategory` — see `ios/Tastemaker/DynamicType.swift`.
# Every `rem` in `application.css` follows, which is the point and also the risk:
# bigger text pushes the note down against the 55vh cap on `.plate__img`, and
# "art and text visible together" is the Better-bucket bar the category leader
# fails. Buying accessibility by breaking that bar is not a trade this product
# gets to make quietly.
#
# Capybara cannot set an iOS content size category. It does not need to — the
# shell's entire mechanism is one line of JavaScript setting a root font size, so
# applying the same root size here tests the same consequence on the same
# stylesheet. If these numbers and `DynamicType.swift` ever disagree, the
# constant below is the one that is wrong.
class DynamicTypeTest < ApplicationSystemTestCase
  # `DynamicType.baseFontSize` * the scale for each category.
  DEFAULT_ROOT = 16.0                 # .large, the system default
  LARGEST_STANDARD_ROOT = 19.2        # .extraExtraExtraLarge — 16 * 1.20
  CAPPED_ACCESSIBILITY_ROOT = 20.0    # the 1.25 cap — 16 * 1.25

  def scale_to(root_px)
    page.execute_script("document.documentElement.style.fontSize = '#{root_px}px';")
  end

  def fold
    page.evaluate_script(<<~JS)
      (() => {
        const img = document.querySelector(".plate__img");
        const p = document.querySelector(".label__note p, .label__text");
        if (!img || !p) return null;
        const imgRect = img.getBoundingClientRect();
        const pRect = p.getBoundingClientRect();
        return {
          plateBottom: imgRect.bottom,
          plateHeight: imgRect.height,
          noteTop: pRect.top,
          lineHeight: parseFloat(getComputedStyle(p).lineHeight),
          viewport: window.innerHeight
        };
      })()
    JS
  end

  # The bar, at the largest size a reader can pick without turning on the
  # accessibility sizes. This is the one that has to hold.
  test "the artwork and the note's first line still share the screen at the largest standard text size" do
    visit root_path
    assert_selector ".plate__img"

    scale_to LARGEST_STANDARD_ROOT
    f = fold

    assert_operator f["plateBottom"], :<, f["viewport"],
      "the artwork itself is below the fold at the largest standard text size"
    assert_operator f["noteTop"] + f["lineHeight"], :<=, f["viewport"],
      "the note's first line was pushed below the fold at the largest standard text size"
  end

  # The cap exists so accessibility sizes degrade rather than break. If someone
  # raises `DynamicType.maximumScale`, this is what should stop them.
  #
  # The note is what this has to measure, not the plate. `.plate__img` is capped
  # in `vh`, so it does not move when the root font size changes — asserting it
  # stays on screen passes at any text size at all and proves nothing. The first
  # written line is the thing scaling text actually pushes off the bottom, and
  # it is also the half of "art and text visible together" that can be lost.
  test "the cap keeps the note's first line on screen at the largest size the shell allows" do
    visit root_path
    assert_selector ".plate__img"

    scale_to CAPPED_ACCESSIBILITY_ROOT
    f = fold

    assert_operator f["plateBottom"], :<, f["viewport"],
      "the artwork is off-screen at the capped accessibility size; the cap is too high"
    assert_operator f["noteTop"] + f["lineHeight"], :<=, f["viewport"],
      "the note's first line is below the fold at the capped accessibility size; the cap is too high"
  end

  # The plate is capped in `vh`, so it must not grow with the root size at all.
  # If it ever does, scaling text would start eating the picture from both ends.
  test "the plate does not grow with the text" do
    visit root_path
    assert_selector ".plate__img"

    scale_to DEFAULT_ROOT
    before = fold["plateHeight"]

    scale_to CAPPED_ACCESSIBILITY_ROOT
    after = fold["plateHeight"]

    assert_in_delta before, after, 1.0,
      "the artwork resized with the text; the 55vh cap is no longer holding it"
  end
end
