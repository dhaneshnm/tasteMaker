require "application_system_test_case"

class DaysSystemTest < ApplicationSystemTestCase
  # The whole point of the story, made measurable: somebody back from three
  # shifts reaches a missed day in two taps.
  test "two taps from the front door reach a past day" do
    visit root_path

    find("time.masthead__aside a").click
    assert_selector "h2.days__month"

    within "ol.days" do
      all("a.days__link").last.click
    end

    assert_selector "h1.label__title", text: paintings(:harbour).title
    assert_selector ".masthead__label", text: "From the archive"
  end

  # Catching up is a walk, not a series of round trips to the list.
  test "three missed days are walkable without returning to the list" do
    DailyPick.create!(painting: paintings(:woodcut), scheduled_on: 2.days.ago.to_date,
      blurb: "Two days back, so the walk has somewhere to start from.")

    visit day_path(2.days.ago.to_date.iso8601)
    assert_selector "h1.label__title", text: paintings(:woodcut).title

    find(".walk__step--next").click
    assert_selector "h1.label__title", text: paintings(:harbour).title

    find(".walk__step--next").click
    assert_selector "h1.label__title", text: paintings(:sunflowers).title
    assert_selector ".coda__line", text: "See you tomorrow."
    assert_equal root_url, page.current_url, "the last step should land on the front door, not a redirect"
  end

  test "zoom works on a past day exactly as it does on the front door" do
    visit day_path(1.day.ago.to_date.iso8601)

    find(".plate__zoom").click

    assert_selector ".zoom", visible: true
    assert_selector "html.zoom-open", visible: :all

    find("body").send_keys(:escape)
    assert_no_selector ".zoom", visible: true
  end

  # Regression: ISSUE-002 — the walk links rendered as 15px-tall touch targets on
  # a phone, while .zoom__close in the same product holds a 44px minimum. The
  # walk is the primary control on a past day.
  # Found by /qa on 2026-08-04.
  # Report: .gstack/qa-reports/qa-report-localhost-2026-08-04.md
  test "the walk's controls are thumb-sized on a phone" do
    DailyPick.create!(painting: paintings(:woodcut), scheduled_on: 2.days.ago.to_date,
      blurb: "Two days back, so the walk has both a previous and a next link to measure.")

    visit day_path(1.day.ago.to_date.iso8601)

    heights = page.evaluate_script(<<~JS)
      [...document.querySelectorAll(".walk__step, .walk__today")]
        .map(el => Math.round(el.getBoundingClientRect().height))
    JS

    assert_equal 3, heights.size, "expected previous, next and today"
    heights.each { |h| assert_operator h, :>=, 44, "walk controls must clear a 44px touch target" }
  end

  test "a thumbnail that dies leaves its row readable and navigable" do
    visit days_path

    page.execute_script(<<~JS)
      document.querySelector("li.days__day .days__thumb img").dispatchEvent(new Event("error"))
    JS

    within "li.days__day:first-child" do
      assert_selector ".days__title", text: paintings(:sunflowers).title
      assert_selector "a.days__link"
    end
  end

  test "the row holds its shape on a phone and a long title is never cut" do
    paintings(:harbour).update!(title: "A Long Museum Title " * 6)

    visit days_path

    measurements = page.evaluate_script(<<~JS)
      (() => {
        const row = document.querySelectorAll("a.days__link")[1];
        const title = row.querySelector(".days__title");
        const thumb = row.querySelector(".days__thumb img");
        const style = getComputedStyle(title);
        return {
          clamp: style.webkitLineClamp,
          overflow: style.overflow,
          titleHeight: title.getBoundingClientRect().height,
          lineHeight: parseFloat(style.lineHeight),
          thumbFit: thumb ? getComputedStyle(thumb).objectFit : null,
          thumbHeight: thumb ? Math.round(thumb.getBoundingClientRect().height) : null
        };
      })()
    JS

    assert_includes [ "none", "" ], measurements["clamp"].to_s
    assert_equal "visible", measurements["overflow"]
    assert_operator measurements["titleHeight"], :>, measurements["lineHeight"] * 2,
      "a 120-character title should wrap to several lines rather than being clipped"
    assert_equal "contain", measurements["thumbFit"]
    assert_operator measurements["thumbHeight"], :<=, 72
  end
end
