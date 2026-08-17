require "test_helper"

# R1 for the privacy policy: no artifact without its enforcement.
#
# `/privacy` tells readers there is no advertising, no third-party analytics and
# no cross-app tracking, and the App Store privacy labels are filed to match. Both
# are statements about what this app's code does. Nothing stops the code from
# changing underneath them — and session gate 6 REQUIRES error tracking and
# analytics before the first external user, so the day this stops being true is
# already scheduled.
#
# Without this test that day arrives silently and the filing becomes false with
# no failure anywhere. With it, the build goes red and points at the two things
# that have to change together: the policy's words and the labels in App Store
# Connect.
#
# Sibling of `pool_quota_test.rb` (a claim about the collection) and
# `brand_test.rb` (a claim about the name). Same shape: the repo asserts
# something in prose, so the suite holds it to it.
class PrivacyClaimsTest < ActionDispatch::IntegrationTest
  # Not exhaustive and not trying to be — a deliberately blunt instrument. Any
  # of these landing means a human has to reread the policy, which is the whole
  # job. A tool not on this list slipping through is a smaller failure than a
  # test nobody trusts because it cries wolf.
  TRACKING_GEMS = %w[
    ahoy_matey mixpanel-ruby segment analytics-ruby staccato google-analytics-rails
    sentry-ruby sentry-rails appsignal honeybadger scout_apm bugsnag rollbar
    skylight newrelic_rpm datadog ddtrace posthog-ruby amplitude-api
    rack-tracker fullstory heap logrocket
  ].freeze

  CLAIM = "No third-party analytics".freeze

  setup do
    @lockfile = Rails.root.join("Gemfile.lock").read
    get "/privacy"
    @policy = response.body
  end

  test "the policy still makes the claim this test exists to guard" do
    # If the claim is rewritten or removed, this test's subject is gone and the
    # test below is silently guarding nothing. Fail here first, loudly, so the
    # pair cannot rot into a no-op.
    assert_includes @policy, CLAIM,
      "The privacy page no longer says #{CLAIM.inspect}. If that was deliberate, " \
      "update this test and the App Store privacy labels in the same commit."
  end

  test "no tracking or analytics dependency while the policy denies one" do
    present = TRACKING_GEMS.select { |gem| @lockfile.match?(/^\s+#{Regexp.escape(gem)}\s/) }

    assert_empty present, <<~MESSAGE
      Gemfile.lock now carries #{present.join(", ")}, and /privacy still says
      "#{CLAIM}". One of the two is wrong.

      This is not a request to remove the gem — session gate 6 requires error
      tracking before the first external user, so adding one is expected. It is a
      reminder that three things change together:

        1. app/views/pages/privacy.html.erb — say what is collected and by whom
        2. PagesController::POLICY_UPDATED_ON — bump it
        3. App Store Connect → App Privacy — refile the labels

      Then add the gem to an allowlist here, or narrow CLAIM to what stays true.
    MESSAGE
  end

  test "the policy's own last-updated date is what the page shows" do
    # The stamp is rendered from a constant rather than a literal in the view, so
    # the two cannot drift. Cheap, and it is the field a reader uses to decide
    # whether to read this again.
    assert_includes @policy, PagesController::POLICY_UPDATED_ON.strftime("%-d %B %Y")
  end

  # THE ONE THIS FILE DID NOT HAVE.
  #
  # Story 0017's plan claimed this file already pinned "the deletion path the
  # policy names is the path that exists", and that it had caught the story 0016
  # defect. Neither was true: every other test here checks a STRING in the page,
  # a gem in the lockfile, or a date. None of them touches a route, so the
  # policy could name a control that does not exist and this file would stay
  # green — which is exactly what happened in 0016, where the policy promised
  # in-app deletion the majority reader had no way to perform.
  #
  # So: follow the policy's own instructions and assert the controls are there
  # and the routes answer. Both identities, because the policy makes the promise
  # to both and the device half is the one that was false.
  test "the deletion controls the policy names exist where it says they are" do
    get privacy_path
    assert_response :success
    assert_match "Your corner", response.body,
      "the policy must name the screen the controls are actually on"

    # With an account.
    sign_in
    get corner_path
    assert_select "form[action=?][method=post]", account_path, count: 1,
      message: "the policy promises Delete account on this screen"
    assert_difference "User.count", -1 do
      delete account_path
    end

    # Without an account, on the iOS app. This is the case 0016 shipped false.
    reset!
    token = register_device
    Favorite.create!(painting: paintings(:sunflowers), collector_digest: Device.digest(token))

    get corner_path
    assert_select "form[action=?][method=post]", device_path, count: 1,
      message: "the policy promises Delete this device's data on this screen"

    assert_difference [ "Device.count", "Favorite.count" ], -1 do
      delete device_path
    end
  end
end
