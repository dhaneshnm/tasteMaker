require "application_system_test_case"

# Story 0031. Every assertion here runs against a plain browser — no native
# adapter, no spoofed User-Agent — which is what every reader of this suite
# actually is. `reveal_shell_share` stamps `data-shell-share` by hand where a
# test needs the REVEALED state, standing in for the real mechanism: an
# inline script in `layouts/_head.html.erb` reads the `bridge-components:
# [share]` string a shell's User-Agent carries. See that file for why the
# mechanism is a UA read rather than the bridge package's own (later-arriving)
# dataset attribute.
#
# Capybara's matchers take an options hash, not a message string (the same
# constraint `test/integration/favorites_test.rb` already documents) — the
# "why" for each assertion below lives in a comment, not an argument.
class ShareTest < ApplicationSystemTestCase
  behind_the_wall!

  test "on the front door, the share button exists but stays hidden until the shell reveals it" do
    visit root_path

    assert_no_selector ".rail__share"
    assert_selector ".rail__share", visible: :hidden

    reveal_shell_share
    assert_selector ".rail__share", visible: :visible
    assert_share_left_of_keep
  end

  test "on an archived day, the share button behaves the same way" do
    DailyPick.create!(painting: paintings(:woodcut), scheduled_on: 2.days.ago.to_date,
      blurb: "Old enough to archive.")
    visit day_path(2.days.ago.to_date.iso8601)

    assert_no_selector ".rail__share"
    assert_selector ".rail__share", visible: :hidden

    reveal_shell_share
    assert_selector ".rail__share", visible: :visible
    assert_share_left_of_keep
  end

  test "in the gallery, the share button behaves the same way" do
    visit feed_path

    assert_no_selector ".rail__share"
    assert_selector ".rail__share", visible: :hidden, minimum: 1

    reveal_shell_share
    assert_selector ".rail__share", visible: :visible, minimum: 1
    assert_share_left_of_keep
  end

  test "on an artist page, the share button behaves the same way" do
    visit artist_path("berthe-morisot")

    assert_no_selector ".rail__share"
    assert_selector ".rail__share", visible: :hidden

    reveal_shell_share
    assert_selector ".rail__share", visible: :visible
    assert_share_left_of_keep
  end

  # A resting work (no picture, no CDN fallback) is still a work you can
  # keep — but there is no file to hand off, so it gets no share button at
  # all, shell or no shell. `DailyPick` itself validates its painting has a
  # usable image, so the way every other test in this suite gets a resting
  # day is the same way this one does: publish a real day, then take the
  # picture away from the painting afterward
  # (`test/integration/favorites_test.rb`'s equivalent case for keep).
  test "a resting work offers no share button, even with the shell revealed" do
    pick = daily_picks(:yesterday)
    pick.painting.update!(image_url_800: nil)

    visit day_path(pick.scheduled_on.iso8601)
    reveal_shell_share

    assert_no_selector ".rail__share", visible: :all
  end

  # The controller extends the bridge package's own `BridgeComponent`, whose
  # `static shouldLoad` reads the REAL `navigator.userAgent` — untouched by
  # `reveal_shell_share`, which only satisfies this app's own CSS reveal. So
  # a headless Chrome tab that can SEE the (CSS-revealed) button still has no
  # controller connected to it: tapping does nothing, not a crash.
  test "tapping the revealed button with no native adapter present is inert" do
    visit root_path
    reveal_shell_share

    find(".rail__share").click

    assert_current_path root_path
    assert_selector ".rail__share", visible: :visible
  end

  private
    def reveal_shell_share
      page.execute_script('document.documentElement.dataset.shellShare = "1"')
    end

    # Scoped to whichever `.rail` actually carries a share button, not
    # blindly "the first `.rail` on the page" — `/feed` renders many posts
    # per load and fixture ids are hashed rather than sequential
    # (`test/fixtures/paintings.yml`), so a resting work can sort ahead of
    # one with a picture and the wrong `.rail` would silently answer this.
    def assert_share_left_of_keep
      in_order = page.evaluate_script(<<~JS)
        (() => {
          const rail = [...document.querySelectorAll(".rail")]
            .find(r => r.querySelector(".rail__share"))
          if (!rail) return false
          const kids = [...rail.children]
          const shareIdx = kids.findIndex(el => el.classList.contains("rail__share"))
          const keepIdx = kids.findIndex(el => el.tagName === "TURBO-FRAME")
          return shareIdx >= 0 && keepIdx >= 0 && shareIdx < keepIdx
        })()
      JS
      assert in_order, "share did not sit to the left of the keep frame"
    end
end
