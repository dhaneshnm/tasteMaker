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

    # `config/environments/test.rb` turns forgery protection off for the whole
    # suite. That means `csrf_meta_tags` renders nothing at all — it returns early
    # without ever calling `form_authenticity_token` — and a POST with no token is
    # accepted. So any test whose subject IS the CSRF machinery passes without
    # asserting anything unless it turns protection back on first. That includes
    # the tests proving public pages emit no session cookie: with protection off,
    # the *old* layout emitted none either.
    def with_forgery_protection
      was = ActionController::Base.allow_forgery_protection
      ActionController::Base.allow_forgery_protection = true
      yield
    ensure
      ActionController::Base.allow_forgery_protection = was
    end

    # The whole-file form, for a test case whose every test needs it. One
    # implementation, so the two cannot drift: a file that hand-rolls its own
    # save/set/restore keeps the old semantics the day this helper has to do more.
    def self.with_forgery_protection!
      setup    { @forgery_protection_was = ActionController::Base.allow_forgery_protection
                 ActionController::Base.allow_forgery_protection = true }
      teardown { ActionController::Base.allow_forgery_protection = @forgery_protection_was }
    end

    # The curator's credentials, in one place. Integration tests want them as a
    # header hash (`curator_headers` below); the system test hands the same string
    # to Chrome over CDP. `ActionDispatch::SystemTestCase` descends from
    # ActiveSupport::TestCase, not from IntegrationTest, so this is the only
    # ancestor both can reach.
    def curator_credentials(password: ENV.fetch("CURATOR_PASSWORD"))
      ActionController::HttpAuthentication::Basic.encode_credentials(
        Admin::BaseController::USERNAME, password
      )
    end

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
  # The curator's desk is behind HTTP basic auth; tests knock politely. The
  # password's default lives on `curator_credentials` alone — repeating it here
  # would put the thing that was just extracted back in two places.
  def curator_headers(**options)
    { "HTTP_AUTHORIZATION" => curator_credentials(**options) }
  end
end
