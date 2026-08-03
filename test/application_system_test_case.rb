require "test_helper"

# The daily page is designed for a phone held at breakfast, so that is the
# window every system test runs in.
class ApplicationSystemTestCase < ActionDispatch::SystemTestCase
  driven_by :selenium, using: :headless_chrome, screen_size: [ 375, 667 ]
end
