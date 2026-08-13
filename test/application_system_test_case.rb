require "test_helper"

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

  private
    def fit_viewport
      page.driver.browser.execute_cdp("Emulation.setDeviceMetricsOverride",
        width: VIEWPORT_WIDTH, height: VIEWPORT_HEIGHT, deviceScaleFactor: 1, mobile: true)
    end
end
