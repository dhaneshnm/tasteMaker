require "application_system_test_case"

class DailyTest < ApplicationSystemTestCase
  # Better bar 2, made measurable: on the smallest phone we support, the
  # artwork and the first lines of the note have to arrive together.
  test "the artwork and the note share the first screen on a small phone" do
    visit root_path

    assert_selector "h1.label__title", text: paintings(:sunflowers).title
    # The prompt arrives with the impression frame's fetch (DR6) rather than
    # first paint — wait for it before measuring, or this races the frame.
    assert_selector ".sit__prompt", wait: 3

    # Bar 2 wears two faces since story 0032, re-shaped by 0033. Folded: the
    # day's PROMPT is the written line sharing the screen with the art.
    prompt_visible = page.evaluate_script(<<~JS)
      (() => {
        const p = document.querySelector(".sit__prompt");
        if (!p) return false;
        const rect = p.getBoundingClientRect();
        return rect.top + rect.height <= window.innerHeight;
      })()
    JS
    assert prompt_visible, "the prompt was pushed below the fold at 375x667"

    # Opened: the pin's summary stays on screen (it never disappears, story
    # 0033), and the bound keeps art + first words together.
    open_the_note
    assert_selector ".cmt__pin[open]"
    first_line_visible = page.evaluate_script(<<~JS)
      (() => {
        const p = document.querySelector(".cmt__fold") ||
                  document.querySelector(".label__note p");
        if (!p) return false;
        return p.getBoundingClientRect().bottom <= window.innerHeight;
      })()
    JS

    assert first_line_visible, "the opened pin's first written line was pushed below the fold at 375x667"
  end

  test "the whole painting is on screen, never cropped" do
    visit root_path

    measurements = page.evaluate_script(<<~JS)
      (() => {
        const img = document.querySelector(".plate__img");
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

    find(".plate__zoom").click
    assert_selector ".zoom", visible: true
    assert_selector ".zoom__close", visible: true
    assert_selector "html.zoom-open", visible: :all

    find("body").send_keys(:escape)

    assert_no_selector ".zoom", visible: true
    assert_selector ".plate__zoom:focus", visible: :all
    assert_no_selector "html.zoom-open", visible: :all
  end

  # On a phone, tapping the picture is the gesture people reach for first.
  test "tapping anywhere in the full screen view closes it" do
    visit root_path

    find(".plate__zoom").click
    assert_selector ".zoom", visible: true

    find(".zoom__img").click

    assert_no_selector ".zoom", visible: true
    assert_no_selector "html.zoom-open", visible: :all
  end

  test "the page holds together when the picture does not load" do
    visit root_path

    page.execute_script(<<~JS)
      document.querySelector(".plate__img").dispatchEvent(new Event("error"))
    JS

    assert_selector ".plate__resting", text: "This work is resting"
    assert_no_selector ".plate__zoom", visible: true
    # The resting copy says "read the note" — the reader's route to it is
    # the gate, same as any other day (story 0032).
    open_the_note
    assert_selector ".label__note", text: /fortnight/
  end
end
