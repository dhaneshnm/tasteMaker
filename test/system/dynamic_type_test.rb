require "application_system_test_case"

# The forcing function for story 0008's Dynamic Type support (T10).
#
# The shell scales the page by setting a root font size from
# `UIApplication.preferredContentSizeCategory` — see `ios/Tondo/DynamicType.swift`.
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

  # The fixture above is the friendliest page this product publishes: a short
  # hand-written note under a two-line title. Everything else that reaches the
  # front door sits higher up the screen — museum copy renders through
  # `.label__body` with its own source line, and a long title steps the type
  # down but still runs to more lines.
  #
  # Story 0012 is why this exists. The compass left 9px of margin in a static
  # harness and turned out to be 1px over on the real page, and the difference
  # was the fixture. One page shape is a coincidence; three is a bound.
  test "the bar holds on the pages that sit highest up the screen" do
    [
      [ "museum copy, no hand-written note", paintings(:woodcut), nil ],
      [ "a long title over a two-line artist line", paintings(:sunflowers),
        # The longest title in the shipping dataset, verbatim — exactly 100
        # characters, and 274 of the 2,000 run over 60.
        #
        # Story 0013 grew the pool from 110 Minneapolis works to 2,000 across
        # four museums and found this bar by breaking it: an untrimmed pool put
        # a 297-character manuscript catalogue entry on the front door and
        # pushed this very assertion 193px below the fold. `Pool::MAX_TITLE`
        # exists because of that, and it is set to the length measured here —
        # at 95 characters the note clears by a full line, at 105 by 2px.
        "Khurshid reunited with her husband Utarid, from a Tuti-nama " \
        "(Tales of a Parrot): Thirty-second Night" ]
    ].each do |what, painting, retitle|
      DailyPick.destroy_all
      painting.update!(title: retitle) if retitle
      DailyPick.create!(painting: painting, scheduled_on: Date.current,
        blurb: painting.description.present? ? nil : "A note for the day.")

      visit root_path
      assert_selector ".plate__img"

      scale_to CAPPED_ACCESSIBILITY_ROOT
      f = fold

      assert_operator f["plateBottom"], :<, f["viewport"],
        "the artwork is below the fold at the accessibility cap on #{what}"
      assert_operator f["noteTop"] + f["lineHeight"], :<=, f["viewport"],
        "the first written line is below the fold at the accessibility cap on #{what}"
    end
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

  # The plate must never GROW with the root size. If it did, scaling text would
  # eat the picture from both ends at once and there would be no way out.
  #
  # It is allowed to shrink, and story 0012 made it. The cap gained a third term
  # — `calc(100dvh - 19rem)` — so that the compass row and scaled type can both
  # be paid for out of the picture rather than out of the note. That is the cap
  # doing the job its comment always claimed: keeping the opening of the note
  # above the fold. The assertions above are what bound how far it goes.
  test "the plate never grows with the text, and yields when the text needs room" do
    visit root_path
    assert_selector ".plate__img"

    scale_to DEFAULT_ROOT
    before = fold["plateHeight"]

    scale_to CAPPED_ACCESSIBILITY_ROOT
    after = fold["plateHeight"]

    assert_operator after, :<=, before + 1.0,
      "the artwork grew with the text; scaling type is eating the picture from both ends"

    # Not unbounded either. The picture giving up a quarter of its height to make
    # room for words would be the wrong trade in the other direction, and it is
    # the direction a bigger `19rem` walks in.
    assert_operator after, :>=, before * 0.75,
      "the artwork gave up more than a quarter of its height; 19rem is too greedy"
  end
end
