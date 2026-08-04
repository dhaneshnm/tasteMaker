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
    assert_selector "body"
    reveal_keep_control

    assert_button "Keep this"
    assert_empty focused_class_names.grep(/keep__toggle/),
      "the lazy frame took focus from the reader mid-scroll"
  end

  test "the collection is reachable from the artwork and from the archive" do
    visit root_path
    reveal_keep_control
    click_on "Keep this"
    assert_button "Kept · Remove"

    click_on "1 kept →"

    assert_selector ".masthead__label", text: "Your collection"
    assert_text daily_picks(:today).painting.title

    visit days_path
    click_on "Your collection →"

    assert_selector ".masthead__label", text: "Your collection"
  end

  test "the control is a real target on a phone, and its row does not wrap" do
    visit root_path
    reveal_keep_control
    click_on "Keep this"
    assert_button "Kept · Remove"

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
  # caught: a coda used to end with one way out, and two small-caps links sharing
  # a line with nothing between them read as one long string.
  test "a coda with two ways out separates them, and both are real targets" do
    visit root_path
    reveal_keep_control
    click_on "Keep this"
    assert_button "Kept · Remove"
    click_on "1 kept →"

    links = all(".coda .caps-link")
    assert_equal 2, links.size

    links.each { |link| assert_operator link.native.size.height, :>=, 44 }
    assert_operator links.last.native.location.x - (links.first.native.location.x +
      links.first.native.size.width), :>=, 16, "the two ways out ran together"
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
    def reveal_keep_control
      page.execute_script("window.scrollTo(0, document.body.scrollHeight)")
      assert_selector ".keep__toggle"
    end

    def focused_class_names
      page.evaluate_script("(document.activeElement.className || '').split(/\\s+/)")
    end
end
