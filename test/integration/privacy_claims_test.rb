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
end
