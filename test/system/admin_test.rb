require "application_system_test_case"

# One test, and it exists for one reason.
#
# The queue's delete control is a link with `data: { turbo_method: :delete }`.
# Turbo turns that into a DELETE by reading `meta[name=csrf-token]` out of the
# page. Story 0007 removed that tag from the reader layout, so if the admin
# layout ever loses it too, deletion silently stops working — and no integration
# test can see it, because an integration DELETE never runs the JS that reads
# the tag. Only a real browser does.
class AdminTest < ApplicationSystemTestCase
  # Basic auth through a real Chrome. Not credentials in the URL: Chrome skips ES
  # module scripts on a URL with embedded auth, so Turbo would never boot and this
  # test would pass for the wrong reason.
  def authenticate_curator!
    credentials = ActionController::HttpAuthentication::Basic.encode_credentials(
      Admin::BaseController::USERNAME, ENV.fetch("CURATOR_PASSWORD")
    )
    page.driver.browser.execute_cdp("Network.enable")
    page.driver.browser.execute_cdp("Network.setExtraHTTPHeaders",
      headers: { "Authorization" => credentials })
  end

  # Runs with forgery protection ON. With it off — the suite default — the server
  # accepts the DELETE whether or not Turbo found a token, so the test would pass
  # against a layout with no meta tag and prove nothing. On, the request is only
  # accepted if Turbo actually read the tag and sent a valid token, which is the
  # exact chain story 0007 could break.
  test "the curator deletes a queued day, with Turbo reading the CSRF meta tag" do
    with_forgery_protection do
      authenticate_curator!
      pick = daily_picks(:tomorrow)

      visit admin_daily_picks_path
      assert_text pick.painting.title

      accept_confirm { click_on "Remove", match: :first }

      assert_no_text pick.painting.title
      assert_nil DailyPick.find_by(id: pick.id), "the day was not actually deleted"
    end
  end
end
