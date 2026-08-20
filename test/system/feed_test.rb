require "application_system_test_case"

# The screen story 0012 was opened about.
#
# `/feed` streams 110 works with infinite scroll. Its masthead is not sticky
# (DESIGN.md rule 5) and its coda renders only on the last page, so two flicks in
# there was nothing on screen to leave by — the only exit was a serif wordmark
# that had scrolled off the top. A reader who followed "Wander the full gallery"
# out of the daily ritual could not get back to it.
#
# The fix is structural, not a state change: the compass rides in a sticky rail
# below the masthead. There is no cross-browser way for CSS to know an element
# has become stuck, so nothing here changes shape — the masthead leaves and the
# rail does not.
class FeedTest < ApplicationSystemTestCase
  behind_the_wall!

  # Enough works to push the masthead well off the top of the screen.
  setup do
    (PaintingsController::PER_PAGE * 2).times do |i|
      Painting.create!(source: "mia", source_id: 920_000 + i, title: "Filler #{i}",
        artist: "A. Painter", image_url_800: "https://example.test/#{i}.jpg")
    end
  end

  def scrolled_to(y)
    page.execute_script("window.scrollTo(0, #{y});")
    # One frame, so the sticky offset settles before anything is measured.
    page.evaluate_script("new Promise(r => requestAnimationFrame(() => r(true)))")
  end

  # The bug, made measurable. `assert_selector` alone would pass on the broken
  # page — the wordmark was always in the DOM. The question was never whether an
  # exit existed, it was whether the reader could see one.
  test "the way home is on screen after scrolling into the gallery" do
    visit feed_path
    assert_selector ".compass--rail"

    scrolled_to 1200

    top = page.evaluate_script(<<~JS)
      Math.round(document.querySelector(".compass--rail").getBoundingClientRect().top)
    JS
    assert_operator top, :>=, 0, "the rail scrolled off the top of the screen"
    assert_operator top, :<=, 2, "the rail is not stuck to the top"

    # By href, not by text: `text-transform: uppercase` means the rendered text
    # is "TODAY" and a text filter would be asserting the stylesheet.
    assert_selector ".compass--rail a[href='#{root_path}']"
  end

  test "tapping Today from deep in the gallery lands on the artwork of the day" do
    visit feed_path
    scrolled_to 1200

    within(".compass--rail") { click_on "Today" }

    assert_selector ".masthead__label", text: "Artwork of the Day"
    assert_text daily_picks(:today).painting.title
  end

  # The rail is the narrowing of rule 5, and the narrowing is spent on
  # navigation only — never on branding. A sticky bar carrying a wordmark and a
  # work count measures 104px, 16% of this screen, parked over the artwork for
  # the whole scroll. This is 58.
  test "the rail is a rail, not a masthead that followed you down the page" do
    visit feed_path
    scrolled_to 1200

    height = page.evaluate_script(<<~JS)
      Math.round(document.querySelector(".compass--rail").getBoundingClientRect().height)
    JS
    assert_operator height, :<=, 70, "the rail grew into a second masthead"

    brand_bottom = page.evaluate_script(<<~JS)
      Math.round(document.querySelector(".masthead__brand").getBoundingClientRect().bottom)
    JS
    assert_operator brand_bottom, :<, 0, "the masthead came along for the ride"
  end

  # Story 0022 Release 1. Same idiom the "Today" test above already proves for
  # the compass rail: tap a link, land on the narrowed URL, and the tapped
  # value marks itself the way the compass marks the screen you are on.
  test "tapping a period filter narrows the gallery and marks itself active" do
    Painting::MIN_FACET_WORKS.times do |i|
      Painting.create!(source: "mia", source_id: 922_000 + i, title: "Twelfth #{i}",
        artist: "A. Painter", image_url_800: paintings(:woodcut).image_url_800,
        period: "12th century")
    end

    visit feed_path
    within(".facets") { click_on "12th century" }

    # `text-transform: uppercase` renders "12TH CENTURY" — a case-sensitive
    # text filter would be asserting the stylesheet (the same trap
    # handoff_test.rb documents for the compass), so this matches
    # case-insensitively.
    assert_current_path feed_path(period: "12th-century")
    within(".facets") do
      assert_selector "span.facets__here[aria-current='true']", text: /12th century/i
      assert_no_selector "a", text: /12th century/i

      click_on "All"
    end
    assert_current_path feed_path
  end

  # Story 0024. Same idiom as the period facet above, on the tradition column.
  test "tapping a tradition filter narrows the gallery to matching works and marks itself active" do
    Painting::MIN_FACET_WORKS.times do |i|
      Painting.create!(source: "mia", source_id: 923_000 + i, title: "Mughal #{i}",
        artist: "A. Painter", image_url_800: paintings(:woodcut).image_url_800,
        tradition: "Mughal Painting")
    end

    visit feed_path
    within(".facets") { click_on "Mughal Painting" }

    # `text-transform: uppercase` renders "MUGHAL PAINTING" — same
    # case-insensitive trap the period test above documents, for the
    # rendered-text assertions below (click_on itself matches the
    # underlying DOM text, not the CSS-rendered case).
    assert_current_path feed_path(tradition: "mughal-painting")
    within(".facets") do
      assert_selector "span.facets__here[aria-current='true']", text: /mughal painting/i
      assert_no_selector "a", text: /mughal painting/i

      click_on "All"
    end
    assert_current_path feed_path
  end

  # `.zoom` is z-index 20 and the rail is 1. Reading a work full screen from the
  # gallery must not leave a navigation bar sitting on top of the picture.
  test "the full-screen view covers the rail" do
    visit feed_path
    scrolled_to 1200

    find(".plate__zoom", match: :first).click
    assert_selector ".zoom", visible: true

    # Whatever is painted where the rail sits belongs to the overlay. Probing the
    # strip the rail occupies rather than the rail's own rect: with the overlay
    # open the page cannot scroll, and the rail may be anywhere behind it.
    covered = page.evaluate_script(<<~JS)
      (() => {
        const el = document.elementFromPoint(window.innerWidth / 2, 20);
        return el !== null && el.closest(".zoom") !== null;
      })()
    JS
    assert covered, "the rail sat on top of the full-screen artwork"
  end

  # Four one-word labels on one row is what keeps this a 58px rail. If the copy
  # or the gap ever grows, this is the first thing that says so.
  test "the rail holds its four doors on one row at 375px" do
    visit feed_path

    tops = page.evaluate_script(<<~JS)
      [...new Set([...document.querySelectorAll(".compass--rail .caps-link")]
        .map(el => Math.round(el.getBoundingClientRect().top)))].length
    JS
    assert_equal 1, tops, "the rail wrapped onto two rows"
  end

  # Story 0014 scoped the rail's reserve to `.page:has(.rail)` when exactly one
  # screen shape carried a rail. Story 0020 gave the gallery one too — a keep
  # control on every post — and with it a plate-level selector,
  # `.plate:has(+ .rail)`, so the reserve follows each post's own rail rather
  # than blanketing a page that scrolls past 110 of them. This is what says
  # BOTH halves of that landed: the rail exists, and the plate that carries
  # one pays the same reserve `/` does, not the old untouched 363.
  #
  # Measured against the FIRST plate on the page, the same way this test
  # always has (`document.querySelector`, singular) — not averaged across
  # every `.plate__img`. The fillers this file seeds carry unreachable
  # `https://example.test/*.jpg` URLs on purpose (no network in a system
  # test); a broken image reports no intrinsic size at all and collapses to
  # a couple of border pixels regardless of any CSS reserve, which would
  # make an all-images assertion measure "did the image load", not "does the
  # reserve apply". The fixtures at the front of `feed_ordered` carry the
  # real 800×1000 bytes `dynamic_type_test.rb` also measures, and that is
  # what this needs.
  #
  # 363 was the number this test asserted before the gallery had a rail at
  # all; 319 is `/`'s number for the same fixture image, measured in
  # `dynamic_type_test.rb`. If this ever reads 363 again, the CSS scoping
  # regressed — the gallery has a `.rail` in the DOM but the reserve stopped
  # reaching the plate above it.
  test "the first plate in the gallery pays the same rail reserve the daily page does" do
    visit feed_path
    assert_selector ".plate__img"
    assert_selector ".rail", minimum: 1

    height = page.evaluate_script(
      "Math.round(document.querySelector('.plate__img').getBoundingClientRect().height)")
    assert_equal 319, height, "the gallery's first plate did not pay the rail reserve"
  end

  # -------------------------------------------------------- the keep control
  #
  # Story 0020. `/`'s keep control is a fetched frame; `/feed`'s is rendered
  # inline, and the nested-frame risk that design settles by reading Turbo's
  # source rather than testing it (`specs/0020.../plan.md`) is that a keep
  # tap could be swallowed by the outer `feed-page-1` frame's `target: "_top"`
  # and become a full-page navigation. These are the regression guard.
  #
  # `reveal` exists because of `reveal_controller.js`: every `.post` opens at
  # `opacity: 0` and only reaches `opacity: 1` once its own `IntersectionObserver`
  # sees it enter the viewport (`application.css` `.post.reveal-init`), and this
  # driver treats `opacity: 0` as not-visible — the same reason `scrolled_to`
  # exists above for the compass. Fillers 5+ down the page start below the
  # fold at 375×667 and need this before Capybara's visibility-gated finders
  # can see them at all.
  def reveal(aria_label)
    page.execute_script(<<~JS)
      document.querySelector('[aria-label="#{aria_label}"]')
        ?.closest(".post")?.scrollIntoView({ block: "center" })
    JS
  end

  test "keeping a work in the gallery fills its mark without touching the rest of the page" do
    visit feed_path
    reveal "Keep Filler 0 in your collection"
    before_path = page.current_path

    click_on "Keep Filler 0 in your collection"

    assert_button "Remove Filler 0 from your collection"
    assert_equal before_path, page.current_path, "keeping navigated the page"
    # A work elsewhere on the page, untouched — proof the outer frame did not
    # reload and discard everything but the tapped post.
    reveal "Keep Filler 1 in your collection"
    assert_button "Keep Filler 1 in your collection"
  end

  test "unkeeping a work in the gallery empties its mark without touching the rest of the page" do
    visit feed_path
    reveal "Keep Filler 0 in your collection"
    click_on "Keep Filler 0 in your collection"
    assert_button "Remove Filler 0 from your collection"

    click_on "Remove Filler 0 from your collection"

    assert_button "Keep Filler 0 in your collection"
    reveal "Keep Filler 1 in your collection"
    assert_button "Keep Filler 1 in your collection"
  end

  # D1 (`/plan-design-review`): mark-only on `/feed` and `/artists/:slug` —
  # no `"N kept"` link, on purpose, even once something is kept.
  test "the gallery never renders the count link, even once something is kept" do
    visit feed_path
    reveal "Keep Filler 0 in your collection"

    click_on "Keep Filler 0 in your collection"

    assert_button "Remove Filler 0 from your collection"
    assert_no_selector ".rail__count"
  end

  # Rule 9, both axes — the same bar `favorites_test.rb` holds for `/`,
  # measured on the surface that renders this control inline instead of
  # fetched.
  test "the gallery's keep control is a real target on both axes" do
    visit feed_path

    control = find(".rail .rail__act", match: :first)
    assert_operator control.native.size.height, :>=, 44, "the gallery's keep control was under 44px tall"
    assert_operator control.native.size.width, :>=, 44, "the gallery's keep control was under 44px wide"
  end

  # T5 (`/plan-eng-review`). The error state `application_controller.rb`
  # already builds for a bounced frame write — asserted here on the surface
  # that carries TEN of these frames on one page, where "replaces the tapped
  # mark only" is the property that actually matters. The identity dies the
  # way a device revocation or an account deletion would: the row behind the
  # session is gone, but the cookie and the page the reader is looking at are
  # not.
  test "identity dying mid-scroll replaces only the tapped mark" do
    visit feed_path
    reveal "Keep Filler 1 in your collection"
    assert_button "Keep Filler 1 in your collection"

    User.find_by!(provider: "google_oauth2", uid: "test-uid-1").destroy!

    reveal "Keep Filler 0 in your collection"
    click_on "Keep Filler 0 in your collection"

    assert_link "Sign in"
    # A mark the reader never touched must be unchanged when their identity
    # died — Capybara's matchers take an options hash, not a message string,
    # so the "why" lives in this comment rather than in the assertion.
    assert_button "Keep Filler 1 in your collection"
  end

  # T6 (`/plan-eng-review`). Asserted as DOM order, not literal `:tab` key
  # presses: none of these three elements sets `tabindex`, so default tab
  # order is exactly the order they appear in markup, and DOM order is the
  # deterministic, cross-driver way to check it.
  test "each post's tab order is plate zoom, then keep, then the artist link" do
    visit feed_path

    in_order = page.evaluate_script(<<~JS)
      [...document.querySelectorAll(".post")].slice(0, 2).every(post => {
        const els = ["plate__zoom", "rail__act", "label__artist-name"]
          .map(cls => post.querySelector(`.${cls}`))
          .filter(Boolean);
        return els.every((el, i) => i === 0 ||
          !!(els[i - 1].compareDocumentPosition(el) & Node.DOCUMENT_POSITION_FOLLOWING));
      })
    JS

    assert in_order, "a post's zoom, keep, and artist link were not in that source order"
  end
end
