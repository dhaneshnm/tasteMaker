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
  # This resizes the window until the viewport is the size the tests claim.
  setup { fit_viewport }

  private
    def fit_viewport
      width, height = page.evaluate_script("[window.innerWidth, window.innerHeight]")
      return if width == VIEWPORT_WIDTH && height == VIEWPORT_HEIGHT

      window = page.driver.browser.manage.window
      size = window.size
      window.resize_to(
        size.width + (VIEWPORT_WIDTH - width),
        size.height + (VIEWPORT_HEIGHT - height)
      )
    end
end
