ENV["RAILS_ENV"] ||= "test"
# Only the floor for a machine with no credentials — a fresh clone, or CI with
# no master key. Where credentials DO carry these, they win the `||` in the two
# controllers, so nothing below may hard-code these strings: ask
# `Admin::BaseController.expected_password` and
# `DeviceRegistrationsController.expected_app_secret` instead.
ENV["CURATOR_PASSWORD"] ||= "test-curator-password"
ENV["TONDO_APP_SECRET"] ||= "test-tondo-app-secret"
require_relative "../config/environment"
require "rails/test_help"
require "tempfile"

# Every provider is mocked for the whole suite (story 0015): a real OAuth
# round-trip needs Google's or Apple's servers, and the Apple flow cannot be
# exercised off the deployed domain at all (specs/0015 plan, eng review A2).
# Individual tests override `mock_auth` for their own personas.
OmniAuth.config.test_mode = true

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

    # Render error pages the way a reader gets them.
    #
    # Two switches, not one. `show_exceptions` decides whether a raise is rescued
    # at all; `show_detailed_exceptions` decides whether the rescued request gets
    # the developer's debug page or the reader's. The test environment sets both
    # the developer's way, so flipping only the first still asserts against the
    # debug page — which has no masthead and no linen, and will fail in a way
    # that looks like the error page is broken.
    def with_rescued_exceptions
      config = Rails.application.env_config
      was = config.values_at("action_dispatch.show_exceptions",
        "action_dispatch.show_detailed_exceptions")
      config["action_dispatch.show_exceptions"] = :all
      config["action_dispatch.show_detailed_exceptions"] = false
      yield
    ensure
      config["action_dispatch.show_exceptions"], config["action_dispatch.show_detailed_exceptions"] = was
    end

    # The whole-file form, for a test case whose every test needs it.
    def self.with_rescued_exceptions!
      setup    { @rescued_was = Rails.application.env_config.values_at(
                   "action_dispatch.show_exceptions", "action_dispatch.show_detailed_exceptions")
                 Rails.application.env_config["action_dispatch.show_exceptions"] = :all
                 Rails.application.env_config["action_dispatch.show_detailed_exceptions"] = false }
      teardown { Rails.application.env_config["action_dispatch.show_exceptions"],
                 Rails.application.env_config["action_dispatch.show_detailed_exceptions"] = @rescued_was }
    end

    # A mocked OAuth identity (story 0015). `mock_auth` writes it; the sign-in
    # helpers below drive the same POST → callback path a reader's tap does.
    def mock_auth(provider: :google_oauth2, uid: "test-uid-1",
                  email: "reader@example.com", name: "Test Reader")
      OmniAuth.config.mock_auth[provider] = OmniAuth::AuthHash.new(
        provider: provider.to_s, uid: uid,
        info: { email: email, name: name }.compact
      )
    end

    # A recognizable-name list (story 0019), written to a real file with the
    # real constant pointed at it.
    #
    # Not a stubbed accessor: Minitest 6 no longer ships `minitest/mock`, and
    # swapping the path exercises the genuine read-parse-match path the curation
    # task uses. Three test files need this — the matcher, the curator's seed
    # stage, and the coverage report — so it lives here rather than in whichever
    # one happened to write it first.
    # The original path is captured BEFORE anything that can raise, and the
    # restore is guarded on having actually swapped. Written the other way
    # round first, a raise inside the setup left the constant restored to `nil`
    # and every later test in that process died in `load_names`.
    def with_recognizable_names(names, &)
      file = Tempfile.new([ "recognizable", ".json" ])
      file.write(::JSON.generate({ "names" => Array(names) }))
      file.flush
      with_recognizable_list(Pathname.new(file.path), &)
    ensure
      file&.close!
    end

    # No list at all — the state every test that does not curate runs in, and
    # the one the curator has to keep working in.
    def without_recognizable_names(&)
      with_recognizable_list(Rails.root.join("tmp/no-such-recognizable-list.json"), &)
    end

    def with_recognizable_list(path)
      original = Pool::Recognizable::LIST
      swapped = false
      swap_recognizable_list(path)
      swapped = true
      yield
    ensure
      swap_recognizable_list(original) if swapped || original
    end

    def swap_recognizable_list(path)
      Pool::Recognizable.send(:remove_const, :LIST)
      Pool::Recognizable.const_set(:LIST, path)
      Pool::Recognizable.reload!
    end

    # The curator's credentials, in one place. Integration tests want them as a
    # header hash (`curator_headers` below); the system test hands the same string
    # to Chrome over CDP. `ActionDispatch::SystemTestCase` descends from
    # ActiveSupport::TestCase, not from IntegrationTest, so this is the only
    # ancestor both can reach.
    def curator_credentials(password: Admin::BaseController.expected_password)
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
        source: "mia",
        source_id: (Painting.maximum(:source_id).to_i + 1),
        title: "A Day in #{date.strftime("%B")}",
        artist: "Unknown Hand",
        image_url_800: paintings(:woodcut).image_url_800,
        image_width: 800, image_height: 1000
      )
      DailyPick.create!(painting: painting, scheduled_on: date, blurb: blurb)
    end

    # Facet fixtures for story 0022/0024/0027 — genre and tradition stay out
    # unless a test asks for them, so a test that only ever sets one facet
    # proves nothing about the byte-identical-except-active-rows claim.
    # Moved here from `feed_filter_test.rb` (`/simplify`) once
    # `painting_test.rb`'s `scoped_to`/`index_for` tests needed the same
    # shape — one copy for both files, not two.
    def create_paintings(count, source_id_start:, period: nil, genre: nil, tradition: nil, **attrs)
      count.times do |i|
        Painting.create!(
          source: "met", source_id: source_id_start + i, title: "Work #{source_id_start + i}",
          image_url_800: paintings(:woodcut).image_url_800,
          period: period, genre: genre, tradition: tradition, **attrs
        )
      end
    end
  end
end

class ActionDispatch::IntegrationTest
  # The registration limiter counts by IP and every test is 127.0.0.1 —
  # without this, one file's registrations 429 another file's tests (the
  # store is process-wide, and a store that ISN'T would be the silent-no-op
  # bug eng review A1 exists to prevent).
  setup { DeviceRegistrationsController::RATE_LIMIT_STORE.clear }

  # The curator's desk is behind HTTP basic auth; tests knock politely. The
  # password's default lives on `curator_credentials` alone — repeating it here
  # would put the thing that was just extracted back in two places.
  def curator_headers(**options)
    { "HTTP_AUTHORIZATION" => curator_credentials(**options) }
  end

  # The two keys, as one-liners (story 0015). Both go through the real front
  # desks rather than writing cookies or sessions by hand, so every test that
  # uses them also exercises registration and the OAuth callback.

  # Registers a device and leaves its signed cookie in the jar — the state an
  # iOS reader is in for every request after first launch. `session:` lets a
  # test register a second reader in an `open_session` without re-typing the
  # endpoint and secret-header idiom.
  def register_device(token: "test-device-uuid", session: self)
    session.post "/device/registrations", params: { device_token: token },
      headers: { "X-Tondo-App" => DeviceRegistrationsController.expected_app_secret }
    session.assert_response :no_content
    token
  end

  # The push opt-in's native call (story 0010), same secret-header idiom.
  # `apns_token` defaults to a fixture-shaped hex string that clears
  # PushRegistrationsController::APNS_TOKEN_FORMAT; pass `apns_token: nil` for
  # the one real call that omits it (`mode: "refresh", enabled: false`).
  def register_push(device_token: "test-device-uuid", mode: "enroll",
                    apns_token: "a" * 64, enabled: nil, session: self)
    params = { device_token: device_token, mode: mode }
    params[:apns_token] = apns_token if apns_token
    params[:enabled] = enabled unless enabled.nil?

    session.post "/device/push_registrations", params: params,
      headers: { "X-Tondo-App" => DeviceRegistrationsController.expected_app_secret }
  end

  # The whole-file form, matching `with_rescued_exceptions!`: a test case whose
  # every test reads gated pages declares it once instead of pasting the same
  # setup. When identity establishment changes (App Attest), one place moves.
  def self.behind_the_wall!
    setup { register_device }
  end

  # Signs in through the mocked provider and follows the redirect chain to a
  # signed-in session. Returns the User the callback created or found.
  def sign_in(provider: :google_oauth2, uid: "test-uid-1", **identity)
    mock_auth(provider: provider, uid: uid, **identity)
    post "/auth/#{provider}"
    follow_redirect! # to the provider (mocked: straight to the callback)
    follow_redirect! if response.redirect? # callback → /days
    User.find_by!(provider: provider.to_s, uid: uid)
  end
end
