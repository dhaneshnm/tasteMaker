require "test_helper"

# The dev-only mock sign-in door (story 0021) — reachable only when
# `config.x.dev_sign_in_enabled` is true, checked by a routing CONSTRAINT on
# `config/routes.rb`'s `dev/sign_in` routes rather than a boot-time
# `if Rails.env.development?`. The constraint form is what makes the happy
# path testable at all: routes load once at boot and this suite always boots
# in `test`, so a boot-time `if` would make the route permanently
# unreachable here. Flipping the config value for one test's duration
# (`with_dev_sign_in_enabled`) drives the real route instead.
class DevSignInRoutingTest < ActionDispatch::IntegrationTest
  test "the flag defaults to false in this environment" do
    # Closes the one critical gap eng review flagged: test.rb's and
    # production.rb's `false` defaults are otherwise enforced only by a
    # comment next to development.rb's `true`. If a future edit flips one by
    # mistake, this goes red instead of shipping silently.
    assert_equal false, Rails.application.config.x.dev_sign_in_enabled
  end

  test "the door does not exist at the default flag value" do
    # Not `assert_raises(ActionController::RoutingError)` — this app sets
    # `config.exceptions_app = routes` (config/application.rb), so a routing
    # miss is rescued and rendered as a normal 404 response, the same shape
    # `sessions_test.rb`'s "an unknown provider's callback is a 404, not a
    # 500" test pins for the constrained-out `auth/:provider/callback` route.
    get "/dev/sign_in"
    assert_response :not_found

    post "/dev/sign_in"
    assert_response :not_found
  end

  test "an unrecognized provider redirects back without touching mock_auth" do
    with_dev_sign_in_enabled do
      post "/dev/sign_in", params: { provider: "not_a_real_provider" }

      assert_redirected_to dev_sign_in_path
      assert_nil OmniAuth.config.mock_auth[:not_a_real_provider]
    end
  end

  # The whole point of the story, and the test outside-voice review caught a
  # real bug in: the FIRST render (GET /dev/sign_in) also needs forgery
  # protection forced on, not just the last POST — `token_tag` only embeds
  # the hidden `authenticity_token` field when `allow_forgery_protection` is
  # true, and test.rb defaults it false. Every leg below runs inside one
  # `with_forgery_protection` block so every extracted token is real. This
  # repo has already shipped one test that passed vacuously because of
  # exactly that default (`test/integration/sessions_test.rb`'s Apple CSRF
  # test) — this is the failure mode the wrap exists to avoid repeating.
  test "the mock door signs a reader in through the real, unmodified path" do
    with_dev_sign_in_enabled do
      with_forgery_protection do
        get "/dev/sign_in"
        dev_sign_in_token = extract_authenticity_token

        post "/dev/sign_in", params: {
          provider: "google_oauth2", uid: "dev-uid-1",
          email: "dev@example.com", name: "Dev Reader",
          authenticity_token: dev_sign_in_token
        }
        assert_response :success
        auth_token = extract_authenticity_token
        assert auth_token, "the rendered auto-submit form must carry a real CSRF token"

        post "/auth/google_oauth2", params: { authenticity_token: auth_token }
        follow_redirect! # to the provider (mocked: straight to the callback)
        follow_redirect! if response.redirect? # callback → /days
      end
    end

    assert_equal "/days", path
    assert_response :success
    assert_not_nil session[:user_id]
    assert User.exists?(provider: "google_oauth2", uid: "dev-uid-1")
  end

  private
    def with_dev_sign_in_enabled
      was = Rails.application.config.x.dev_sign_in_enabled
      Rails.application.config.x.dev_sign_in_enabled = true
      yield
    ensure
      Rails.application.config.x.dev_sign_in_enabled = was
    end

    def extract_authenticity_token
      response.body[/name="authenticity_token" value="([^"]+)"/, 1]
    end
end
