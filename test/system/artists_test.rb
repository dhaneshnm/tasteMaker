require "application_system_test_case"

# Story 0020, test 2: the artist page's half of the keep control, the other
# walled surface `paintings/_painting.html.erb` renders inline. Zero-work and
# multi-work page shapes, 404s, and the freshness contract are all covered at
# the integration level in `test/integration/artists_test.rb` — this file is
# the browser-only half: does tapping the mark actually feel like keeping
# something, without moving the reader anywhere.
class ArtistsTest < ApplicationSystemTestCase
  behind_the_wall!

  # Every `.post` opens at `opacity: 0` and only reaches `opacity: 1` once its
  # own `IntersectionObserver` sees it enter the viewport
  # (`reveal_controller.js`, `application.css` `.post.reveal-init`), and this
  # driver treats `opacity: 0` as not-visible. See `feed_test.rb`, which has
  # the same helper for the same reason.
  def reveal(aria_label)
    page.execute_script(<<~JS)
      document.querySelector('[aria-label="#{aria_label}"]')
        ?.closest(".post")?.scrollIntoView({ block: "center" })
    JS
  end

  test "keeping a work on the artist page fills its mark and stays on the page" do
    visit artist_path("berthe-morisot")
    assert_selector "h1.label__title", text: "Berthe Morisot"

    click_on "Keep Harbour at Dawn in your collection"

    assert_button "Remove Harbour at Dawn from your collection"
    assert_selector "h1.label__title", text: "Berthe Morisot"
    # D1: mark-only here too — no `"N kept"` link, even once something is kept.
    assert_no_selector ".rail__count"
  end

  # Two works, two independent marks — proof the frame swap on one does not
  # touch the other, the same nested-frame property `feed_test.rb` guards.
  test "keeping one work on the artist page leaves the other's mark alone" do
    visit artist_path("berthe-morisot")

    click_on "Keep Harbour at Dawn in your collection"

    assert_button "Remove Harbour at Dawn from your collection"
    reveal "Keep A Wide Harbour in your collection"
    assert_button "Keep A Wide Harbour in your collection"
  end

  test "unkeeping on the artist page empties the mark and stays on the page" do
    visit artist_path("berthe-morisot")
    click_on "Keep Harbour at Dawn in your collection"
    assert_button "Remove Harbour at Dawn from your collection"

    click_on "Remove Harbour at Dawn from your collection"

    assert_button "Keep Harbour at Dawn in your collection"
    assert_selector "h1.label__title", text: "Berthe Morisot"
  end
end
