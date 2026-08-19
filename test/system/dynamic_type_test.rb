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
  # This file measures `/` AND `/days/:date`, and until story 0017 it only ever
  # measured `/`. The archive route has been behind the wall since story 0015,
  # so an unauthenticated `visit day_path(...)` bounced to the landing page —
  # which satisfies every selector below, because it renders the same partial.
  # The assertions passed against the wrong page and nothing said so.
  #
  # Story 0017 retargeted that bounce to `/you`, which renders no plate and no
  # rail, and the loop went red on its second route. The bug it exposed is
  # older than the change that exposed it.
  behind_the_wall!

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

  # Where the bottom of the keep control lands, and the fold it has to clear.
  # Story 0014 moved it out of the wall label into the rail under the plate, and
  # this is the number that says so. `with_viewport` comes from the base class.
  def keep_bottom
    page.evaluate_script(
      %{Math.round(document.querySelector(".rail__slot .rail__act").getBoundingClientRect().bottom)})
  end

  # Story 0014's whole success signal, and the forcing function it owes (R1).
  #
  # The control used to sit at the foot of the wall label, which put it 40-60pt
  # below the fold on a fallback day and several hundred below on a hand-written
  # one — rule 8 shows that note whole, so the page a curator writes is the
  # TALLER page and the good case was the day nobody wrote. Position next to the
  # artwork is what makes it independent of note length; this asserts it stayed
  # that way.
  #
  # Both viewports, both routes, every text size. `/days/:date` renders the same
  # partial but different chrome, and "same partial" is not a test.
  test "the keep control is on screen at open, on every phone and every text size" do
    long_note = "A hand-written note at the ceiling. " * 30   # ~180 words, rule 8's cap
    DailyPick.find_by(scheduled_on: Date.current).update!(blurb: long_note)

    [ [ 375, 667 ], [ 402, 874 ] ].each do |width, height|
      with_viewport(width, height) do
        [ root_path, day_path(Date.current) ].each do |route|
          [ DEFAULT_ROOT, LARGEST_STANDARD_ROOT, CAPPED_ACCESSIBILITY_ROOT ].each do |root|
            visit route
            assert_selector ".rail__slot .rail__act"

            scale_to root

            assert_operator keep_bottom, :<=, height,
              "the keep control was below the fold at #{width}x#{height}, " \
              "root #{root}px, on #{route}"
          end
        end
      end
    end
  end

  # The accepted cost, asserted rather than remembered — and asserted on both
  # phones, because the whole argument for accepting it was that it is paid on
  # one of them and not the other.
  #
  # The fixture plate is 800x1000. The arithmetic, at a 16px root:
  #
  #   402x874  content width 361.8 -> natural height 452
  #            caps: 55vh 481, 100dvh-19rem-44px 526    -> neither binds, 452
  #   375x667  content width 337.5 -> natural height 422
  #            caps: 55vh 367, 100dvh-19rem-44px 319    -> the reserve binds, 319
  #
  # So on the large phone the picture is width-constrained and the rail is free;
  # on the small one the reserve term wins and the picture pays 44px of its 363.
  # If the 402 number ever drops below 452 the reserve grew too greedy to be free
  # anywhere, which is the direction a bigger rail walks in.
  test "the rail is free on the large phone and costs the small one 44px" do
    with_viewport(402, 874) do
      visit root_path
      assert_selector ".plate__img"
      assert_equal 452, fold["plateHeight"].round,
        "the rail took height from the artwork at 402x874, where nothing should bind"
    end

    visit root_path
    assert_selector ".plate__img"
    assert_equal 319, fold["plateHeight"].round,
      "the reserve term is no longer what bounds the plate at 375x667"
  end

  # Story 0020, T4 (`/plan-design-review`) — the same −44px trade extended to
  # `/feed`, and to the size that matters most: the accessibility cap.
  # `fold()` reads `.label__note p, .label__text`, and no feed post carries
  # either the daily note markup or a guaranteed matching description, so
  # this measures `.plate__img` directly the same way
  # `feed_test.rb`'s CSS-reserve test does — just at both root sizes instead
  # of only the default.
  #
  # `19rem` scales with the root font size and the reserve does not (rule 9:
  # a finger does not get bigger), so the plate is not free to stay at 319
  # here — measured, not assumed: 243 at the cap, smaller than 319 but never
  # collapsed to nothing.
  test "the gallery's plate shrinks, but never collapses, at the accessibility text cap" do
    visit feed_path
    assert_selector ".plate__img"

    scale_to DEFAULT_ROOT
    default_height = page.evaluate_script(
      "Math.round(document.querySelector('.plate__img').getBoundingClientRect().height)")
    assert_equal 319, default_height, "the default-root reserve regressed"

    scale_to CAPPED_ACCESSIBILITY_ROOT
    capped_height = page.evaluate_script(
      "Math.round(document.querySelector('.plate__img').getBoundingClientRect().height)")
    assert_equal 243, capped_height,
      "the gallery's plate did not shrink the way the daily page's does at the accessibility cap"
    assert_operator capped_height, :>, 0, "the plate collapsed rather than shrinking"
  end

  # The other half of the accepted cost: a WIDE painting pays nothing anywhere,
  # because a landscape plate runs out of width long before any height cap can
  # reach it. Only works tall enough to be height-capped ever move, which is what
  # makes the 44px a narrow trade rather than a tax on the whole collection.
  #
  # `wide_harbour` carries real 1000x800 pixels rather than DEFAULTS plus edited
  # width/height attributes. Those attributes only set an aspect ratio and never
  # override the intrinsic size — the note at the top of `paintings.yml` records
  # the time that cost this suite every fold assertion it had. A landscape test
  # against portrait bytes passes while measuring the wrong thing.
  test "a landscape work is width-constrained, so the rail costs it nothing" do
    DailyPick.destroy_all
    DailyPick.create!(painting: paintings(:wide_harbour), scheduled_on: Date.current,
      blurb: "A note for the day.")

    [ [ 375, 667, 270 ], [ 402, 874, 290 ] ].each do |width, height, expected|
      with_viewport(width, height) do
        visit root_path
        assert_selector ".plate__img"

        assert page.evaluate_script("(() => { const i = document.querySelector('.plate__img'); return i.naturalWidth > i.naturalHeight; })()"),
          "the landscape fixture is not actually landscape — check its pixels, not its attributes"

        assert_equal expected, fold["plateHeight"].round,
          "a landscape plate changed height at #{width}x#{height}; it should be width-bound"
      end
    end
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

  # Story 0017's forcing function for the corner. Two things, both measured
  # rather than argued:
  #
  #   1. the mark is a real touch target at every text size, in BOTH directions
  #      — rule 9 gets width for free from words and this has none;
  #   2. adding it did not push the compass onto a second row, which is the
  #      44px the whole placement argument was avoiding.
  #
  # Measured 2026-08-17 at 375px: the masthead is 105.78 / 109.14 / 112.00 at
  # roots 16 / 19.2 / 20, and the compass stays one row at all three.
  test "the corner is a real target and costs the compass nothing" do
    with_viewport(375, 667) do
      [ DEFAULT_ROOT, LARGEST_STANDARD_ROOT, CAPPED_ACCESSIBILITY_ROOT ].each do |root|
        visit root_path
        scale_to root

        box = page.evaluate_script(<<~JS)
          (() => {
            const you = document.querySelector('.masthead__you').getBoundingClientRect();
            const rows = new Set([...document.querySelectorAll('.compass .caps-link')]
              .map(el => Math.round(el.getBoundingClientRect().top)));
            return { w: you.width, h: you.height, rows: rows.size };
          })()
        JS

        assert_operator box["w"], :>=, 44, "the corner was #{box["w"]}px wide at root #{root}"
        assert_operator box["h"], :>=, 44, "the corner was #{box["h"]}px tall at root #{root}"
        assert_equal 1, box["rows"],
          "the compass wrapped to #{box["rows"]} rows at root #{root} — the corner cost 44px"
      end
    end
  end

  # Story 0018, eng review D10/X10. `.label__artist-name` is 22.85px against
  # the 44px bar — the same ISSUE-002 mistake rule 9 exists to prevent, now on
  # an inline link. Padding on an INLINE element (not `inline-block`) was
  # chosen specifically because it does not add to the line box, so this
  # measures both halves of that claim: the target reaches 44px in height, and
  # the note's fold position is unchanged from before the link existed.
  test "the artist link meets the tap target without moving the fold" do
    yesterday = daily_picks(:yesterday)

    with_viewport(375, 667) do
      visit day_path(yesterday.scheduled_on.iso8601)
      scale_to DEFAULT_ROOT

      box = page.evaluate_script(<<~JS)
        (() => {
          const link = document.querySelector('a.label__artist-name');
          const rect = link.getBoundingClientRect();
          return { height: rect.height, width: rect.width };
        })()
      JS

      assert_operator box["height"], :>=, 44,
        "the artist link was #{box["height"]}px tall — inline padding did not reach --tap"
      # Width is not asserted at the --tap floor: rule 9's own carve-out is
      # that a control with words (unlike a bare glyph) gets width for free
      # from its text, which "Berthe Morisot" already clears by a wide margin.
      assert_operator box["width"], :>=, 44

      f = fold
      assert_operator f["plateBottom"], :<, f["viewport"],
        "the artwork moved below the fold once the artist name became a link"
      assert_operator f["noteTop"] + f["lineHeight"], :<=, f["viewport"],
        "the note's first line moved below the fold once the artist name became a link"
    end
  end

  # Story 0022 Release 1, design review pass 5. `.caps-link` sets size and
  # tracking, never height — assuming otherwise is ISSUE-002 (commit
  # 866bbc2), and the facet row states the bar itself with `min-height:
  # var(--tap)`. Asserted at the accessibility cap, where the type is
  # largest and a control built the wrong way is most likely to fall short.
  test "the facet row's items clear the tap bar at the accessibility cap" do
    Painting::MIN_FACET_WORKS.times do |i|
      Painting.create!(source: "mia", source_id: 923_000 + i, title: "Nineteenth #{i}",
        artist: "A. Painter", image_url_800: paintings(:woodcut).image_url_800,
        period: "19th century")
    end

    with_viewport(375, 667) do
      visit feed_path
      scale_to CAPPED_ACCESSIBILITY_ROOT

      heights = page.evaluate_script(<<~JS)
        [...document.querySelectorAll(".facets .caps-link")]
          .map(el => Math.round(el.getBoundingClientRect().height))
      JS

      assert heights.any?, "expected at least one facet control to measure"
      heights.each_with_index do |height, i|
        assert_operator height, :>=, 44, "facet item #{i} was #{height}px tall at the accessibility cap"
      end
    end
  end
end
