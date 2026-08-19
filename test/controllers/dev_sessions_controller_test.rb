require "test_helper"

# `.build_auth_hash` in isolation (story 0021). No ActionController::TestCase
# in this repo (the gem isn't in the Gemfile — no controller test has ever
# needed it), and none is needed here: the method is a plain class method
# with no request or controller instance involved. The behavioral tests
# (routing, the full sign-in path, the bad-provider guard) live in
# test/integration/dev_sign_in_routing_test.rb, where an actual request is
# the point.
class DevSessionsControllerTest < ActiveSupport::TestCase
  test "carries the given provider, uid, email and name" do
    auth = DevSessionsController.build_auth_hash(
      provider: "google_oauth2", uid: "reader-1", email: "a@example.com", name: "A Reader"
    )

    assert_equal "google_oauth2", auth.provider
    assert_equal "reader-1", auth.uid
    assert_equal "a@example.com", auth.info.email
    assert_equal "A Reader", auth.info.name
  end

  test "a blank uid falls back to a stable default" do
    auth = DevSessionsController.build_auth_hash(
      provider: "apple", uid: "", email: "a@example.com", name: "A Reader"
    )

    assert_equal "dev-uid-1", auth.uid
  end

  test "blank email and name are absent from info, not stored as empty strings" do
    auth = DevSessionsController.build_auth_hash(
      provider: "google_oauth2", uid: "reader-1", email: "", name: nil
    )

    assert_nil auth.info.email
    assert_nil auth.info.name
    refute auth.info.to_h.key?("email"), "a blank email must be omitted, not stored empty"
    refute auth.info.to_h.key?("name"), "a blank name must be omitted, not stored empty"
  end
end
