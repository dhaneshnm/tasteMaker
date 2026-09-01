require "application_system_test_case"

# The conversation thread (story 0033, replacing the sit gate): a bubble
# toggles the whole thing, the museum/curator note is a pinned comment
# folded by default, and the reader's own line is a comment beside it —
# prompt until answered.
class SitTest < ApplicationSystemTestCase
  setup do
    # localStorage outlives Capybara's cookie reset (same browser process,
    # same origin), and a leaked key would change every later test's
    # default state. Land on the page once, then wipe.
    visit root_path
    page.execute_script("try { localStorage.clear() } catch (e) {}")
  end

  test "the thread is open by default, the pin folded, the composer waiting" do
    visit root_path

    assert_selector ".rail__act[aria-expanded='true']"
    assert_no_selector ".cmt__pin[open]"
    assert_selector ".cmt__fold", text: /pinned/i
    assert_no_text "standing in for it" # the note's own words stay hidden
    assert_selector ".sit__prompt", text: daily_picks(:today).sit_prompt
    assert_equal "sit-prompt", find(".plate__img")["aria-describedby"],
      "folded, the artwork must be described by the prompt, never the note"
  end

  test "the bubble hides and shows the whole thread, remembered for the day" do
    visit root_path
    assert_selector ".conv", visible: :visible
    assert_equal "currentColor", bubble_fill

    find(".rail__act[aria-expanded]").click
    assert_no_selector ".conv", visible: :visible
    assert_selector ".rail__act[aria-expanded='false']"
    assert_equal "none", bubble_fill

    visit root_path
    assert_no_selector ".conv", visible: :visible, wait: 2

    page.execute_script("try { localStorage.removeItem('conv') } catch (e) {}")
    visit root_path
    assert_selector ".conv", visible: :visible
  end

  test "closing the thread never hides the coda" do
    visit root_path
    find(".rail__act[aria-expanded]").click

    assert_no_selector ".conv", visible: :visible
    assert_text "See you tomorrow."
  end

  test "closing the thread leaves focus on the bubble" do
    visit root_path
    find(".rail__act[aria-expanded]").click

    assert_selector ".rail__act[aria-expanded='false']:focus", visible: :all
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

  test "the pin is first-class: one tap and the note is open" do
    visit root_path
    open_the_note

    assert_text "standing in for it"
    assert_equal "daily-note", find(".plate__img")["aria-describedby"]

    wait_for("the completed beacon") do
      SitCounter.find_by(date: Date.current)&.completed.to_i >= 1
    end
  end

  test "re-closing the pin hands the description back to the prompt" do
    visit root_path
    open_the_note
    assert_equal "daily-note", find(".plate__img")["aria-describedby"]

    find(".cmt__pin[open] .cmt__fold").click
    assert_equal "sit-prompt", find(".plate__img")["aria-describedby"]
  end

  test "the pin never stays open across a reload — it costs a tap every time" do
    visit root_path
    open_the_note
    assert_text "standing in for it"

    visit root_path
    assert_no_selector ".cmt__pin[open]"
    assert_no_text "standing in for it"
  end

  # Regression: the suite runs with forgery protection off (config/environments/
  # test.rb), so a `fetch()` that forgot to send the CSRF token shipped green
  # and 422'd on every real save — found live against a dev server, never by
  # this suite, because the composer's own `<form>` (Rails' `form_with`
  # default) DOES embed a hidden `authenticity_token` field the whole time;
  # the bug was `autosave_controller.js` never reading it. Same shape as
  # `sit_beacon_test.rb`'s own precedent: turn real protection on and prove
  # the save still lands.
  # Found by /qa on 2026-09-01.
  test "the answer saves with forgery protection genuinely on" do
    with_forgery_protection do
      sign_in_as_reader
      visit root_path
      page.execute_script("try { localStorage.clear() } catch (e) {}")
      visit root_path

      assert_selector ".sit__input", wait: 3
      find(".sit__input").fill_in(with: "protected by a real token")
      find(".sit__input").send_keys(:tab)

      assert_selector ".sit__saved", text: /saved/i, wait: 3
      assert_equal "protected by a real token", Impression.last&.body
    end
  end

  test "a signed-in reader answers under the prompt, autosaved on blur, still a composer" do
    sign_in_as_reader
    visit root_path
    page.execute_script("try { localStorage.clear() } catch (e) {}")
    visit root_path

    assert_selector ".sit__input", wait: 3
    find(".sit__input").fill_in(with: "the butterflies arrive before the eye does")
    find(".sit__input").send_keys(:tab) # blur, without a coordinate-based click

    assert_selector ".sit__saved", text: /saved/i, wait: 3
    assert_selector ".sit__input" # still a composer — blur never commits (eng OV1)

    impression = Impression.last
    assert_equal "the butterflies arrive before the eye does", impression.body
    assert_equal daily_picks(:today).sit_prompt, impression.prompt
  end

  test "Enter sets the line down: the comment replaces the composer" do
    sign_in_as_reader
    visit root_path
    page.execute_script("try { localStorage.clear() } catch (e) {}")
    visit root_path

    assert_selector ".sit__input", wait: 3
    find(".sit__input").fill_in(with: "a hum of yellow")
    find(".sit__input").send_keys(:enter)

    assert_selector ".cmt__body--mine", text: "a hum of yellow", wait: 3
    assert_no_selector ".sit__input"
    # The prompt does not survive into the answered state.
    assert_no_text daily_picks(:today).sit_prompt
  end

  test "a same-day return finds the comment standing, not the composer" do
    sign_in_as_reader
    visit root_path
    page.execute_script("try { localStorage.clear() } catch (e) {}")
    visit root_path

    assert_selector ".sit__input", wait: 3
    find(".sit__input").fill_in(with: "kept for the return")
    find(".sit__input").send_keys(:enter)
    assert_selector ".cmt__body--mine", text: "kept for the return", wait: 3

    visit root_path

    assert_selector ".cmt__body--mine", text: "kept for the return", wait: 3
    assert_no_selector ".sit__input"
  end

  test "tapping today's own comment returns it to the composer, prefilled" do
    sign_in_as_reader
    visit root_path
    page.execute_script("try { localStorage.clear() } catch (e) {}")
    visit root_path

    find(".sit__input", wait: 3).fill_in(with: "first thought")
    find(".sit__input").send_keys(:enter)
    assert_selector ".cmt__edit", wait: 3

    find(".cmt__edit").click

    assert_selector ".sit__input", wait: 3
    assert_equal "first thought", find(".sit__input").value
  end

  # Regression: `autosave_controller` is mounted once, on the persistent
  # frame — `connect()` never re-runs on the composer/comment swap a tap-
  # to-edit triggers, so `this.saved` has to resync some other way or it
  # stays stale from before the prefill. Read it straight off the live
  # controller instance rather than inferring it from a network call.
  test "editing without changing anything reads as clean, not dirty" do
    sign_in_as_reader
    visit root_path
    page.execute_script("try { localStorage.clear() } catch (e) {}")
    visit root_path

    find(".sit__input", wait: 3).fill_in(with: "steady as it goes")
    find(".sit__input").send_keys(:enter)
    assert_selector ".cmt__edit", wait: 3

    find(".cmt__edit").click
    assert_selector ".sit__input", wait: 3

    saved = page.evaluate_script(%{
      (() => {
        const frame = document.querySelector('[data-sit-target="slot"]')
        return window.Stimulus.getControllerForElementAndIdentifier(frame, "autosave").saved
      })()
    })
    assert_equal "steady as it goes", saved
  end

  test "an emptied line and Enter takes the answer back" do
    sign_in_as_reader
    visit root_path
    page.execute_script("try { localStorage.clear() } catch (e) {}")
    visit root_path

    find(".sit__input", wait: 3).fill_in(with: "second thoughts")
    find(".sit__input").send_keys(:enter)
    assert_selector ".cmt__edit", wait: 3

    find(".cmt__edit").click
    find(".sit__input", wait: 3).fill_in(with: "")
    find(".sit__input").send_keys(:enter)

    assert_selector ".sit__input", wait: 3
    assert_no_selector ".cmt__edit"
    assert_equal 0, Impression.count
  end

  test "the reveal survives leaving and coming back" do
    sign_in_as_reader
    visit root_path
    open_the_note
    assert_text "standing in for it"

    click_link "Wander the full gallery →"
    assert_current_path feed_path
    page.go_back

    assert_text "standing in for it"
  end

  test "a museum-fallback day pins too, and More works after the pin opens" do
    daily_picks(:today).update!(blurb: "")
    paintings(:sunflowers).update!(description: ("A long museum sentence. " * 40).strip)

    visit root_path
    assert_no_selector ".label__more", visible: :visible

    open_the_note
    # The re-measure on toggle (eng OV4): clamped copy overflows only once
    # it has layout, so the button may only appear now.
    assert_selector ".label__more", text: /more/i, wait: 2
    find(".label__more").click
    assert_selector ".label__body.expanded"
    assert_selector ".cmt__fold", text: /Pinned/i
    assert_selector ".cmt__meta", text: paintings(:sunflowers).credit_line
  end

  test "a wordless day neither threads nor prompts" do
    daily_picks(:today).update!(blurb: "")
    paintings(:sunflowers).update!(description: nil)

    visit root_path

    assert_no_selector ".conv"
    assert_no_selector ".rail__act[aria-expanded]"
    assert_no_selector ".label__body"
    assert_no_text "From" # no dangling museum attribution
    assert_selector ".label__credit" # picture + credit, the quiet floor
    assert_nil find(".plate__img")["aria-describedby"].presence,
      "nothing to describe the artwork by — the reference must not dangle"
  end

  test "the archive is never gated: the pin opens by default, no bubble at all" do
    sign_in_as_reader
    visit day_path(daily_picks(:yesterday).scheduled_on)

    assert_no_selector ".rail__act[aria-expanded]"
    assert_selector ".cmt__pin[open]"
    assert_text "mixed in the open air" # yesterday's note, open by default
  end

  test "the archive never offers a composer, only a past line if one exists" do
    sign_in_as_reader
    Impression.create!(user: User.last, painting: daily_picks(:yesterday).painting,
      body: "wet grey, remembered", prompt: daily_picks(:yesterday).sit_prompt)

    visit day_path(daily_picks(:yesterday).scheduled_on)

    assert_selector ".cmt__body--mine", text: "wet grey, remembered"
    assert_no_selector ".sit__input"
    # An archived day's own answer is read-only, never tap-to-edit.
    assert_no_selector ".cmt__edit"
  end

  test "the pin states the whole tap bar" do
    visit root_path
    height = page.evaluate_script('document.querySelector(".cmt__fold").getBoundingClientRect().height')
    assert_operator height, :>=, 44, "rule 9: the pin's fold is a tap target"
  end

  private

    # Fill is the state, the same mechanism Keep's own glyph uses — see
    # `sit_controller#syncBubble`.
    def bubble_fill
      page.evaluate_script(%{document.querySelector('[data-sit-target="bubble"] svg').getAttribute("fill")})
    end

    def wait_for(what, timeout: 3)
      deadline = Time.now + timeout
      until yield
        flunk "timed out waiting for #{what}" if Time.now > deadline
        sleep 0.05
      end
    end
end
