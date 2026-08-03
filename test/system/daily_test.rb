require "application_system_test_case"

class DailyTest < ApplicationSystemTestCase
  # Better bar 2, made measurable: on the smallest phone we support, the
  # artwork and the first lines of the note have to arrive together.
  test "the artwork and the note share the first screen on a small phone" do
    visit root_path

    assert_selector "h1.daily-title", text: paintings(:sunflowers).title

    two_lines_visible = page.evaluate_script(<<~JS)
      (() => {
        const p = document.querySelector(".daily-note p");
        if (!p) return false;
        const rect = p.getBoundingClientRect();
        const lineHeight = parseFloat(getComputedStyle(p).lineHeight);
        return rect.top + (2 * lineHeight) <= window.innerHeight;
      })()
    JS

    assert two_lines_visible, "the note's opening was pushed below the fold at 375x667"
  end

  test "the whole painting is on screen, never cropped" do
    visit root_path

    measurements = page.evaluate_script(<<~JS)
      (() => {
        const img = document.querySelector(".daily-figure__img");
        const rect = img.getBoundingClientRect();
        return {
          fit: getComputedStyle(img).objectFit,
          height: rect.height,
          viewport: window.innerHeight
        };
      })()
    JS

    assert_equal "contain", measurements["fit"]
    assert_operator measurements["height"], :<=, measurements["viewport"] * 0.56
  end

  test "tapping the artwork opens it full screen and Escape closes it" do
    visit root_path

    assert_no_selector ".zoom", visible: true

    find(".daily-figure__zoom").click
    assert_selector ".zoom", visible: true
    assert_selector ".zoom__close", visible: true
    assert_selector "html.zoom-open", visible: :all

    find("body").send_keys(:escape)

    assert_no_selector ".zoom", visible: true
    assert_selector ".daily-figure__zoom:focus", visible: :all
    assert_no_selector "html.zoom-open", visible: :all
  end

  # On a phone, tapping the picture is the gesture people reach for first.
  test "tapping anywhere in the full screen view closes it" do
    visit root_path

    find(".daily-figure__zoom").click
    assert_selector ".zoom", visible: true

    find(".zoom__img").click

    assert_no_selector ".zoom", visible: true
    assert_no_selector "html.zoom-open", visible: :all
  end

  test "the page holds together when the picture does not load" do
    visit root_path

    page.execute_script(<<~JS)
      document.querySelector(".daily-figure__img").dispatchEvent(new Event("error"))
    JS

    assert_selector ".daily-figure__resting", text: "This work is resting"
    assert_no_selector ".daily-figure__zoom", visible: true
    assert_selector ".daily-note", text: /fortnight/
  end
end
