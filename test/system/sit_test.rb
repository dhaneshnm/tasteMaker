require "application_system_test_case"

# The sit gate, prompt form (story 0032, redesigned 2026-09-01), driven like
# a reader: one looking prompt, an autosaving line to answer on, and READ
# THE NOTE always one tap away.
class SitTest < ApplicationSystemTestCase
  setup do
    # localStorage outlives Capybara's cookie reset (same browser process,
    # same origin), and a leaked reveal mark would open every later test's
    # gate. Land on the page once, then wipe.
    visit root_path
    page.execute_script("try { localStorage.clear() } catch (e) {}")
  end

  test "the day greets the reader with its prompt and a folded note" do
    visit root_path

    assert_selector ".sit__prompt", text: daily_picks(:today).sit_prompt
    assert_no_text "standing in for it" # the note's own words stay hidden
    assert_selector ".sit__summary", text: /read the note/i
    assert_selector ".sit__details .label__credit", visible: :all
    assert_equal "sit-prompt", find(".plate__img")["aria-describedby"],
      "folded, the artwork must be described by the prompt, never the note"
  end

  test "a stranger gets the prompt as pure looking scaffold, and the quiet hint" do
    visit root_path

    assert_selector ".sit__hint", text: "Sign in to keep your answer."
    assert_no_selector ".sit__input"
    assert_no_selector ".sit__hint a", visible: :all
    assert_no_text "Content missing"

    wait_for("the shown beacon") do
      SitCounter.find_by(date: Date.current)&.shown.to_i >= 1
    end
  end

  test "the skip is first-class: one tap and the note is open, hint gone" do
    visit root_path
    assert_selector ".sit__hint" # frame answered before the skip
    find(".sit__summary").click

    assert_text "standing in for it"
    assert_equal "daily-note", find(".plate__img")["aria-describedby"]
    assert_no_selector ".sit__hint", wait: 2 # after the reveal, silence — not a nag
    wait_for("the revealed beacon") do
      SitCounter.find_by(date: Date.current)&.completed.to_i >= 1
    end
  end

  test "a signed-in reader answers under the prompt, autosaved, then reads" do
    sign_in_as_reader
    visit root_path
    page.execute_script("try { localStorage.clear() } catch (e) {}")
    visit root_path

    assert_selector ".sit__input", wait: 3 # the field arrives with the page, no stages
    find(".sit__input").fill_in(with: "the butterflies arrive before the eye does")
    find(".sit__input").send_keys(:enter)

    assert_selector ".sit__saved", text: /saved/i, wait: 3
    assert_no_text "standing in for it" # saving is not consent to reveal

    impression = Impression.last
    assert_equal "the butterflies arrive before the eye does", impression.body
    assert_equal daily_picks(:today).sit_prompt, impression.prompt,
      "the prompt the reader answered under must ride the row"

    find(".sit__summary").click
    assert_text "standing in for it"
    assert_selector ".sit__impression", text: "the butterflies arrive", wait: 3
    assert page.evaluate_script(<<~JS), "the answer must sit above the note"
      !!(document.querySelector(".sit__impression").compareDocumentPosition(
           document.querySelector("#daily-note")) & Node.DOCUMENT_POSITION_FOLLOWING)
    JS
  end

  test "the draft keeps following the reader until the reveal makes it ink" do
    sign_in_as_reader
    visit root_path
    page.execute_script("try { localStorage.clear() } catch (e) {}")
    visit root_path

    assert_selector ".sit__input", wait: 3
    find(".sit__input").fill_in(with: "first thought")
    find(".sit__input").send_keys(:enter)
    assert_selector ".sit__saved", text: /saved/i, wait: 3

    visit root_path # pre-reveal return: still a draft, still editable
    assert_selector ".sit__input", wait: 3
    assert_equal "first thought", find(".sit__input").value
    find(".sit__input").fill_in(with: "second thought, better")
    find(".sit__input").send_keys(:enter)
    assert_selector ".sit__saved", text: /saved/i, wait: 3

    assert_equal 1, Impression.count
    assert_equal "second thought, better", Impression.last.body
  end

  test "a same-day return finds the note open and the answer standing" do
    sign_in_as_reader
    visit root_path
    page.execute_script("try { localStorage.clear() } catch (e) {}")
    visit root_path

    assert_selector ".sit__input", wait: 3
    find(".sit__input").fill_in(with: "kept for the return")
    find(".sit__input").send_keys(:enter)
    assert_selector ".sit__saved", text: /saved/i, wait: 3
    find(".sit__summary").click
    assert_text "standing in for it"

    visit root_path

    assert_text "standing in for it" # pre-paint open, no fold flash
    assert_no_selector ".sit--ready"
    assert_selector ".sit__impression", text: "kept for the return", wait: 3
    # The writing moment does not come back after the reveal.
    assert_no_selector ".sit__input"
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

  test "revealing removes the control — the destination is the old page" do
    visit root_path
    find(".sit__summary").click

    assert_text "standing in for it"
    assert_no_selector ".sit__summary", visible: :visible
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

  test "a wordless day neither gates nor prompts" do
    daily_picks(:today).update!(blurb: "")
    paintings(:sunflowers).update!(description: nil)

    visit root_path

    assert_no_selector ".sit"
    assert_no_selector ".label__body"
    assert_no_text "From" # no dangling museum attribution
    assert_selector ".label__credit" # picture + credit, the quiet floor
    assert_nil find(".plate__img")["aria-describedby"].presence,
      "nothing to describe the artwork by — the reference must not dangle"
  end

  test "the archive is never gated" do
    sign_in_as_reader
    visit day_path(daily_picks(:yesterday).scheduled_on)

    assert_no_selector ".sit"
    assert_text "mixed in the open air" # yesterday's note, open as always
  end

  test "the skip control states the whole tap bar" do
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
