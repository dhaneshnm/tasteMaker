ENV["RAILS_ENV"] ||= "test"
ENV["CURATOR_PASSWORD"] ||= "test-curator-password"
require_relative "../config/environment"
require "rails/test_help"

module ActiveSupport
  class TestCase
    # Run tests in parallel with specified workers
    parallelize(workers: :number_of_processors)

    # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
    fixtures :all

    # Add more helper methods to be used by all tests here...
  end
end

class ActionDispatch::IntegrationTest
  # The curator's desk is behind HTTP basic auth; tests knock politely.
  def curator_headers(password: ENV.fetch("CURATOR_PASSWORD"))
    credentials = ActionController::HttpAuthentication::Basic.encode_credentials(
      Admin::BaseController::USERNAME, password
    )
    { "HTTP_AUTHORIZATION" => credentials }
  end
end
