require "test_helper"

# Capybara matches a button or link by its id, name, value, title or text — and
# by its `aria-label` only if this is on. It defaults to off.
#
# Story 0014 made that a suite-wide concern rather than a preference: the action
# rail's controls are bare glyphs with no text at all, so the accessible name is
# the ONLY handle they have. Off, `assert_button` cannot see them and a test can
# only reach them by CSS class — which would pass just as happily against a
# button with no accessible name at all, and that is exactly the regression worth
# catching. On, a control a test can find is a control a screen reader can find.
Capybara.enable_aria_label = true

# The daily page is designed for a phone held at breakfast, so that is the
# window every system test runs in.
class ApplicationSystemTestCase < ActionDispatch::SystemTestCase
  # 375x667 is the smallest phone this product supports. In the Hotwire Native
  # shell (story 0008) the page owns the entire screen — there is no browser
  # chrome and no navigation bar — so the viewport really is the device.
  VIEWPORT_WIDTH = 375
  VIEWPORT_HEIGHT = 667

  driven_by :selenium, using: :headless_chrome, screen_size: [ VIEWPORT_WIDTH, VIEWPORT_HEIGHT ]

  # `screen_size` sets the *window* size, and headless Chrome then takes ~143px
  # off the top for its own chrome. So every fold-budget assertion in this suite
  # was measuring a 524px-tall viewport while its failure message said 667 —
  # tighter than any real device, and tighter than the shell, which has no
  # chrome at all.
  #
  # Resizing the *window* cannot do it. Headless Chrome on macOS refuses to go
  # below roughly 500px wide, so `window.resize_to` silently clamped and every
  # test in this suite has been running 375-wide assertions in a 500-wide
  # viewport since the day it was written — looser than the phone it names, in
  # the direction that hides bugs. Story 0012 found it: the compass fits on one
  # row at 500px and wraps to two at 375, and the wrapped row costs 44px of the
  # fold budget that `dynamic_type_test.rb` exists to protect.
  #
  # `Emulation.setDeviceMetricsOverride` sets the viewport directly through the
  # DevTools protocol and is not bound by any window minimum. It is the same
  # mechanism Chrome's own device toolbar uses. `mobile: true` comes with it so
  # the page is laid out the way a phone lays it out, not the way a narrow
  # desktop window does.
  setup { fit_viewport }

  # A second phone, for the tests that have to prove a `dvh`-relative rule holds
  # on more than the smallest screen — a term that fits at 375x667 can still be
  # wrong at 402x874. The class default stays the small phone; a test opts in for
  # the length of a block and the ensure puts it back, so nothing leaks into the
  # next test in the file.
  #
  # Deleted by the story 0015 merge and restored here. The branch was cut before
  # 9e298be added this, so git resolved the conflict by taking the branch's side
  # and dropping a method three `dynamic_type_test.rb` tests call. Textually
  # clean, semantically broken — the kind of merge damage only running the suite
  # finds.
  def with_viewport(width, height)
    fit_viewport(width, height)
    yield
  ensure
    fit_viewport
  end

  # The whole-file form for system tests, mirroring the integration macro in
  # test_helper — though the two take different doors on purpose: that one
  # registers a device, this one signs in as a web reader.
  def self.behind_the_wall!
    setup { sign_in_as_reader }
  end

  # The account key, from the browser's side (story 0015, repointed by 0017).
  # Providers are mocked suite-wide, so tapping the real button IS the whole
  # flow: POST → mocked consent → callback → session. Tests that need a reader
  # behind the wall call this first, and it stays the same door a real web
  # reader walks through.
  #
  # That door moved. It used to be a lazy fragment at the foot of the landing
  # page, reached by `#{root_path}#signin` so the frame would scroll into view.
  # Story 0017 deleted the fragment and gave the doors a page of their own, and
  # `/you` is now where `require_reader` bounces every cookieless visitor — so
  # this is still "wherever the wall sends them", with no anchor and no lazy
  # load to wait on.
  def sign_in_as_reader
    mock_auth
    visit corner_path
    click_button "Continue with Google"
    # Wait for the callback's landing, not for "a masthead" — the landing page
    # has one too, and a test that proceeds mid-navigation renders its next
    # page against half-finished state (found as a race the first full run).
    assert_current_path days_path, wait: 5
  end

  private
    def fit_viewport(width = VIEWPORT_WIDTH, height = VIEWPORT_HEIGHT)
      page.driver.browser.execute_cdp("Emulation.setDeviceMetricsOverride",
        width: width, height: height, deviceScaleFactor: 1, mobile: true)
    end
end
