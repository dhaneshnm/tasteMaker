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

    # One more published day, with a painting of its own.
    #
    # A DailyPick needs a painting no other pick has taken (`painting_id` is
    # unique) and that painting needs a usable image, which leaves exactly one
    # free fixture — :woodcut. Any test wanting a second extra day hits
    # "Artwork has already had its day" with no hint why, so this makes its own
    # painting rather than competing for the fixtures.
    def publish_day(date, blurb: "A note long enough to read the way a real one does.")
      painting = Painting.create!(
        mia_id: (Painting.maximum(:mia_id).to_i + 1),
        title: "A Day in #{date.strftime("%B")}",
        artist: "Unknown Hand",
        image_url_800: paintings(:woodcut).image_url_800,
        image_width: 800, image_height: 1000
      )
      DailyPick.create!(painting: painting, scheduled_on: date, blurb: blurb)
    end
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
