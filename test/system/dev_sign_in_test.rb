require "application_system_test_case"

# The real-browser proof for story 0021's mock door. The integration test
# (test/integration/dev_sign_in_routing_test.rb) drives requests directly and
# never runs Turbo or JavaScript — which is exactly how the first version of
# this shipped broken: Turbo Drive is pinned and imported globally, it
# intercepted `#new`'s form POST, and refused to render `#create`'s 200
# response ("Form responses must redirect to another location"), so an
# actual click never reached the auto-submit chain. Caught by code review,
# not by the integration test or the curl-based manual check that preceded
# it. This test is what makes sure it stays fixed.
class DevSignInTest < ApplicationSystemTestCase
  test "clicking through the mock door signs a reader in" do
    with_dev_sign_in_enabled do
      visit dev_sign_in_path
      click_button "Sign in"

      assert_current_path days_path, wait: 5
    end
  end

  private
    def with_dev_sign_in_enabled
      was = Rails.application.config.x.dev_sign_in_enabled
      Rails.application.config.x.dev_sign_in_enabled = true
      yield
    ensure
      Rails.application.config.x.dev_sign_in_enabled = was
    end
end
