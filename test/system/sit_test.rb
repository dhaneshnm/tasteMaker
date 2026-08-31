require "application_system_test_case"

# The sit gate, driven like a reader (story 0032). The test env runs a
# sub-second "minute" (config.x.sit_duration_seconds) — every wait below is
# Capybara's own retry window, never a sleep against the real clock.
class SitTest < ApplicationSystemTestCase
  setup do
    # localStorage outlives Capybara's cookie reset (same browser process,
    # same origin), and a leaked reveal mark would open every later test's
    # gate. Land on the page once, then wipe.
    visit root_path
    page.execute_script("try { localStorage.clear() } catch (e) {}")
  end

  test "the note starts folded and the invitation describes the artwork" do
    visit root_path

    assert_selector ".sit__summary", text: /Sit with the painting/
    assert_no_text "standing in for it" # the note's own words stay hidden
    assert_selector ".sit__details .label__credit", visible: :all
    assert_equal "sit-invite", find(".plate__img")["aria-describedby"],
      "folded, the artwork must be described by the invitation, never the note"
  end

  test "the reveal never locks: an early tap opens the note and forecloses the field" do
    visit root_path
    find(".sit__summary").click

    assert_text "standing in for it"
    assert_equal "daily-note", find(".plate__img")["aria-describedby"]

    # The minute expires in the background — no ready residue may appear
    # after the reader already chose, and no field ever (D5/F15a).
    assert_no_selector ".sit--ready", wait: 1.5
    assert_no_selector ".sit__input"
    assert_equal "", find(".sit__status", visible: :all).text
  end

  test "the minute completes into the ready state and counts itself" do
    visit root_path

    assert_selector ".sit--ready", wait: 3
    assert_selector ".sit__summary", text: "The note is ready."
    assert_no_text "standing in for it" # ready ≠ revealed: still the reader's tap

    wait_for("the completed beacon") do
      SitCounter.find_by(date: Date.current)&.completed.to_i >= 1
    end
    assert SitCounter.find_by(date: Date.current).shown >= 1
  end

  test "a signed-out minute-completer gets no field and no Content missing" do
    visit root_path

    assert_selector ".sit--ready", wait: 3
    assert_no_selector ".sit__input", wait: 1
    assert_no_text "Content missing"
  end

  test "a signed-in reader writes the line, keeps sitting, then reveals the juxtaposition" do
    sign_in_as_reader
    visit root_path
    page.execute_script("try { localStorage.clear() } catch (e) {}")
    visit root_path

    assert_selector ".sit--ready", wait: 3
    assert_selector ".sit__input", wait: 2

    fill_in "First impression — one line, before the note", with: "the yellows hum"
    click_button "Set it down"

    # Submitting is not consent to reveal (eng): the line lands, the note waits.
    assert_selector ".sit__impression", text: "the yellows hum"
    assert_no_text "standing in for it"

    find(".sit__summary").click
    assert_text "standing in for it"
    assert page.evaluate_script(<<~JS), "the reader's line must sit above the note"
      !!(document.querySelector(".sit__impression").compareDocumentPosition(
           document.querySelector("#daily-note")) & Node.DOCUMENT_POSITION_FOLLOWING)
    JS
  end

  test "a same-day return finds the note open from the first paint" do
    visit root_path
    find(".sit__summary").click
    assert_text "standing in for it"

    visit root_path

    # The pre-paint script opened it before Stimulus ever connected: no
    # timer, no ready state, note simply present.
    assert_text "standing in for it"
    assert_selector ".sit--revealed"
    assert_no_selector ".sit--ready"
  end

  test "the reveal survives leaving and coming back" do
    sign_in_as_reader
    visit root_path
    find(".sit__summary").click
    assert_text "standing in for it"

    click_link "Wander the full gallery →"
    assert_current_path feed_path
    page.go_back

    assert_text "standing in for it"
    # A restore visit must never re-fold a revealed note.
    assert_no_selector "details.sit__details:not([open])"
  end

  test "revealing removes the summary — the destination is the old page" do
    visit root_path
    find(".sit__summary").click

    assert_text "standing in for it"
    assert_no_selector ".sit__summary", visible: :visible
    # No residue between the reader and tomorrow: one note, one credit,
    # nothing left of the gate but the mark it wrote.
    visit root_path
    assert_text "standing in for it"
    assert_no_selector ".sit__summary", visible: :visible
  end

  test "a museum-fallback day gates too, and More works after the reveal" do
    daily_picks(:today).update!(blurb: "")
    paintings(:sunflowers).update!(description: ("A long museum sentence. " * 40).strip)

    visit root_path
    assert_no_selector ".label__more", visible: :visible

    find(".sit__summary").click
    # The re-measure on toggle (eng OV4): clamped copy overflows only once
    # it has layout, so the button may only appear now.
    assert_selector ".label__more", text: /more/i, wait: 2
    find(".label__more").click
    assert_selector ".label__body.expanded"
    assert_selector ".label__source", text: /from/i
  end

  test "the archive is never gated" do
    sign_in_as_reader
    visit day_path(daily_picks(:yesterday).scheduled_on)

    assert_no_selector ".sit"
    assert_text "mixed in the open air" # yesterday's note, open as always
  end

  test "the summary states the whole tap bar" do
    visit root_path
    height = page.evaluate_script('document.querySelector(".sit__summary").getBoundingClientRect().height')
    assert_operator height, :>=, 44, "rule 9: the reveal control is a tap target"
  end

  private

    def wait_for(what, timeout: 3)
      deadline = Time.now + timeout
      until yield
        flunk "timed out waiting for #{what}" if Time.now > deadline
        sleep 0.05
      end
    end
end
