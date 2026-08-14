require "application_system_test_case"

# 375×667, the window every system test here runs in: a phone at breakfast.
#
# This file used to open with the opposite sentence — that the keep control sits
# below a 55vh plate plus the whole note, so every test had to scroll to it
# first, through a `reveal_keep_control` helper. Story 0014 deleted that premise:
# the control is in the action rail directly under the plate now, so it is on
# screen at open and the helper it needed is gone rather than updated. If a test
# here ever has to scroll to find it again, the story regressed.
#
# The keep glyph carries no visible words (`decisions/0010`), so every assertion
# below goes through the accessible name — which is also the point: with the
# label gone the name is the whole announcement, and a test that can still find
# the button is a test that a screen reader user can still find it too.
class FavoritesTest < ApplicationSystemTestCase
  behind_the_wall!

  test "keeping today's artwork changes the glyph and nothing else" do
    visit root_path
    assert_button keep_label

    before = page.current_path
    click_on keep_label

    assert_button remove_label
    assert_link "1 kept"
    assert_equal before, page.current_path, "keeping navigated somewhere"

    click_on remove_label

    assert_button keep_label
    assert_no_link "1 kept"
  end

  # The state is the fill now, not the words. Nothing else about the glyph moves:
  # same colour, same box, no second mark — so if `fill` stops tracking `kept`
  # there is no other signal left to notice it by.
  test "the kept state is the filled glyph and the unkept state is the outline" do
    visit root_path

    assert_equal "none", keep_glyph_fill
    click_on keep_label

    assert_button remove_label
    assert_equal "currentColor", keep_glyph_fill
  end

  # The control is on screen the moment the page is, which is the entire story.
  # Position is not enough on its own — see the default-content test below.
  test "the keep control is above the fold without scrolling" do
    visit root_path
    assert_selector ".plate__img"

    assert_equal 0, page.evaluate_script("window.scrollY"), "the test scrolled"
    assert_operator keep_rect["bottom"], :<=, page.evaluate_script("window.innerHeight"),
      "the keep control was below the fold at open"
  end

  # Story 0014's second half, and the one the eng review missed until the outside
  # voice asked for it. The frame is lazy, so proving the control is in the right
  # PLACE says nothing about whether it is there YET — without default content
  # the rail paints an empty 44px hole in the spot a reader is now looking at.
  #
  # What the cached page carries is the MARK and none of the machinery: a span,
  # not the button. `button_to` emits a CSRF token, generating one starts a
  # session, and a session puts a Set-Cookie on a page Thruster caches for
  # everyone. `test/integration/favorites_test.rb` holds both halves of that in
  # one place; this asserts it against the page a real browser is served.
  test "the cached page already carries the keep mark, and none of its machinery" do
    html = Net::HTTP.get(URI.join(page.server_url, root_path))

    assert_includes html, "rail__act--waiting",
      "the rail had no keep mark until the private fragment landed"
    assert_not_includes html, "Keep #{daily_picks(:today).painting.title} in your collection",
      "the real button shipped in the cached page, which mints a token and a cookie"
    assert_not_includes html, "kept</a>", "the per-visitor count leaked into the cached page"
  end

  # The whole reason `autofocus` is on the write responses. Turbo replaces the
  # frame on submit, which destroys the focused button; without it focus falls to
  # <body> and a keyboard reader is silently teleported to the top of the page
  # with no confirmation that anything happened.
  test "pressing the toggle with a keyboard leaves focus on the toggle" do
    visit root_path

    find_button(keep_label).send_keys(:return)

    assert_button remove_label
    assert_equal "rail__act", focused_class_names.grep(/rail__act/).first,
      "focus was thrown away by the frame replacement"
  end

  # The other half: the fragment arriving must not grab focus, which is also why
  # it carries no aria-live. Above the fold this now fires on every open rather
  # than only for readers who scrolled, so it matters more than it used to.
  test "the frame landing does not steal focus" do
    visit root_path
    assert_selector ".plate__img"
    assert_button keep_label

    assert_empty focused_class_names.grep(/rail__act/),
      "the lazy frame took focus from the reader"
  end

  # D8, and the reason Zoom is first in the row. Keep and its count share one
  # frame; a frame is one contiguous flex item; the count only exists after the
  # fetch. With the frame anywhere but last, Zoom slides ~60px sideways a moment
  # after open — under the thumb of the returning reader this story is for.
  #
  # Measured with a positive count on purpose. A reader who has kept nothing
  # renders no count, so this passes vacuously against an empty collection.
  test "zoom does not move when the count arrives" do
    visit root_path
    click_on keep_label
    assert_link "1 kept"

    visit root_path
    assert_selector ".rail__act[data-artwork-target='railZoom']"
    before = zoom_left

    assert_link "1 kept"   # waits for the frame, which is what would shift it

    assert_equal before, zoom_left, "the count shoved the zoom control sideways"
  end

  test "the collection is reachable from the artwork and from the archive" do
    keep_todays_artwork

    click_on "1 kept"

    assert_selector ".masthead__label", text: "Your collection"
    assert_text daily_picks(:today).painting.title

    visit days_path
    within(".compass") { click_on "Kept" }

    assert_selector ".masthead__label", text: "Your collection"
  end

  # Rule 9, both axes. The width half is new with story 0014: the rule states
  # `min-height` and nothing about width because every control it named was a
  # caps-link, and words make those wide for free. A bare glyph has none.
  #
  # This is also the forcing function for `.rail__form { display: contents }`.
  # `button_to` wraps its button in a form; without that rule the FORM is the
  # flex item, and a naive measurement reads 44px off the form while shipping a
  # 23px target — the same assumption that shipped 15px targets in ISSUE-002.
  test "every rail control is a real target on both axes, and the row does not wrap" do
    keep_todays_artwork

    all(".rail__act").each do |control|
      assert_operator control.native.size.height, :>=, 44, "a rail glyph was under 44px tall"
      assert_operator control.native.size.width,  :>=, 44, "a rail glyph was under 44px wide"
    end

    count = find(".rail__count")
    assert_operator count.native.size.height, :>=, 44, "the count was under 44px tall"

    assert_equal 1, page.evaluate_script(<<~JS), "the rail wrapped onto two lines"
      (() => {
        const tops = new Set([...document.querySelectorAll(".rail__act, .rail__count")]
          .map(el => Math.round(el.getBoundingClientRect().top)));
        return tops.size;
      })()
    JS
  end

  # The forcing function for DESIGN.md rule 9, and for the thing dogfooding
  # caught: small-caps links sharing a line with nothing between them read as one
  # long string.
  #
  # This used to measure the archive's coda, which ended with two ways out. Story
  # 0012 moved every way out into the compass, so the coda has no pair left to
  # measure and the same defect now lives four items wide at the top of every
  # screen. The assertion moved with it.
  #
  # It also holds the line that decides whether the compass fits on one row at
  # 375px: four items, one row, is what keeps the fold budget on the front door.
  test "the compass separates its four doors, and every one is a real target" do
    keep_todays_artwork
    click_on "1 kept"

    # assert_selector waits for the navigation; `all` does not, and reading it
    # straight after a click races the page in.
    assert_selector ".compass .caps-link", count: 4
    items = all(".compass .caps-link")

    items.each { |item| assert_operator item.native.size.height, :>=, 44 }

    tops = items.map { |item| item.native.location.y }.uniq
    assert_equal 1, tops.size, "the compass wrapped onto two rows at 375px"

    items.each_cons(2) do |left, right|
      gap = right.native.location.x - (left.native.location.x + left.native.size.width)
      assert_operator gap, :>=, 10, "two doors ran together"
    end
  end

  # The orphan row's Remove is the ONLY control a kept work has once the curator
  # has removed its day — the row is unlinked, so there is no page to open and
  # unkeep it from. It is also the one control in the product that submits from
  # OUTSIDE a turbo-frame, which is exactly why it needs a browser test: an
  # integration DELETE passes while the real thing renders nothing.
  test "letting go of a work whose day is gone updates the page" do
    keep_todays_artwork
    daily_picks(:today).destroy!

    visit collection_path
    assert_selector ".days__link--gone"
    assert_selector ".masthead__aside", text: /1 work/i

    click_on "Remove"

    assert_no_selector ".days__day"
    assert_selector ".masthead__aside", text: /0 works/i
    assert_text "The works you keep will gather here."

    # The stranger's row on the very same painting survives — the delete is
    # scoped to the reader who pressed the button, not to the work.
    assert_equal [ favorites(:strangers_sunflowers) ], Favorite.all.to_a
  end

  # The parity guard: the day page still does everything it did before the rail.
  test "the artwork still opens full screen from the plate and from the rail" do
    visit root_path
    assert_button keep_label

    find(".plate__zoom").click
    assert_selector ".zoom", visible: true
    find(".zoom__close").click
    assert_no_selector ".zoom", visible: true

    find(".rail__act[data-artwork-target='railZoom']").click
    assert_selector ".zoom", visible: true
  end

  private
    # The glyph has no words, so the accessible name is the only handle a test —
    # or a screen reader — has on it. Derived from the fixture rather than
    # hardcoded, so renaming the painting cannot make these silently unfindable.
    def keep_label   = "Keep #{todays_title} in your collection"
    def remove_label = "Remove #{todays_title} from your collection"
    def todays_title = daily_picks(:today).painting.title

    def keep_todays_artwork
      visit root_path
      click_on keep_label
      assert_button remove_label
    end

    def keep_rect
      page.evaluate_script(<<~JS)
        (() => {
          const r = document.querySelector(".rail__slot .rail__act").getBoundingClientRect();
          return { top: r.top, bottom: r.bottom, left: r.left };
        })()
      JS
    end

    def zoom_left
      page.evaluate_script(<<~JS)
        Math.round(document.querySelector(".rail__act[data-artwork-target='railZoom']")
          .getBoundingClientRect().left)
      JS
    end

    def keep_glyph_fill
      page.evaluate_script(%{document.querySelector(".rail__slot .rail__act svg").getAttribute("fill")})
    end

    def focused_class_names
      page.evaluate_script("(document.activeElement.className || '').split(/\\s+/)")
    end
end
