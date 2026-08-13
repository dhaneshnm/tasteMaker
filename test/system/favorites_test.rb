require "application_system_test_case"

# 375×667, the window every system test here runs in: a phone at breakfast.
# The keep control sits below a 55vh plate plus the whole note, so on this screen
# it is under the fold and its frame is lazy — every test has to get there first.
class FavoritesTest < ApplicationSystemTestCase
  test "keeping today's artwork changes the words and nothing else" do
    visit root_path
    reveal_keep_control

    assert_button "Keep this"
    before = page.current_path

    click_on "Keep this"

    assert_button "Kept · Remove"
    assert_link "1 kept →"
    assert_equal before, page.current_path, "keeping navigated somewhere"

    click_on "Kept · Remove"

    assert_button "Keep this"
    assert_no_link "1 kept →"
  end

  # The whole reason `autofocus` is on the write responses. Turbo replaces the
  # frame on submit, which destroys the focused button; without it focus falls to
  # <body> and a keyboard reader is silently teleported to the top of the page
  # with no confirmation that anything happened.
  test "pressing the toggle with a keyboard leaves focus on the toggle" do
    visit root_path
    reveal_keep_control

    find(".keep__toggle").send_keys(:return)

    assert_button "Kept · Remove"
    assert_equal "keep__toggle", focused_class_names.grep(/keep__toggle/).first,
      "focus was thrown away by the frame replacement"
  end

  # The other half: the fragment arriving mid-scroll must not grab focus, which is
  # also why it carries no aria-live.
  test "the frame landing on scroll does not steal focus" do
    visit root_path
    # This test's subject is `document.activeElement`, which is the kind of
    # negative assertion that passes for free if it runs before the page is
    # really there. Wait on the artwork — a real element this page renders — so
    # the scroll below happens against a settled document.
    assert_selector ".plate__img"
    reveal_keep_control

    assert_button "Keep this"
    assert_empty focused_class_names.grep(/keep__toggle/),
      "the lazy frame took focus from the reader mid-scroll"
  end

  test "the collection is reachable from the artwork and from the archive" do
    keep_todays_artwork

    click_on "1 kept →"

    assert_selector ".masthead__label", text: "Your collection"
    assert_text daily_picks(:today).painting.title

    visit days_path
    within(".compass") { click_on "Kept" }

    assert_selector ".masthead__label", text: "Your collection"
  end

  test "the control is a real target on a phone, and its row does not wrap" do
    keep_todays_artwork

    assert_operator find(".keep__toggle").native.size.height, :>=, 44
    assert_operator find(".keep__link").native.size.height, :>=, 44
    assert_equal 1, page.evaluate_script(<<~JS), "the kept row wrapped onto two lines"
      (() => {
        const row = document.querySelector(".keep");
        const tops = new Set([...row.querySelectorAll(".keep__toggle, .keep__link")]
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
    click_on "1 kept →"

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

  # The parity guard: the day page still does everything it did before the frame.
  test "the artwork still opens full screen with the control on the page" do
    visit root_path
    reveal_keep_control

    assert_button "Keep this"
    find(".plate__zoom").click

    assert_selector ".zoom", visible: true
  end

  private
    def keep_todays_artwork
      visit root_path
      reveal_keep_control
      click_on "Keep this"
      assert_button "Kept · Remove"
    end

    def reveal_keep_control
      page.execute_script("window.scrollTo(0, document.body.scrollHeight)")
      assert_selector ".keep__toggle"
    end

    def focused_class_names
      page.evaluate_script("(document.activeElement.className || '').split(/\\s+/)")
    end
end
