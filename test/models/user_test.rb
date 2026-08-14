require "test_helper"

class UserTest < ActiveSupport::TestCase
  def auth(provider: "apple", uid: "uid-1", email: nil, name: nil)
    OmniAuth::AuthHash.new(provider: provider, uid: uid,
      info: { email: email, name: name }.compact)
  end

  test "from_omniauth creates once and finds after" do
    first = User.from_omniauth(auth(email: "a@example.com"))
    second = User.from_omniauth(auth)

    assert_equal first, second
    assert_equal 1, User.count
  end

  # Apple sends name and email only on the FIRST authorization. A later auth
  # without them must not null out what was captured — losing them then is
  # losing them forever.
  test "a later auth without name and email does not erase them" do
    User.from_omniauth(auth(email: "a@example.com", name: "A Reader"))

    user = User.from_omniauth(auth)

    assert_equal "a@example.com", user.email
    assert_equal "A Reader", user.name
  end

  test "the same person on two providers is two users, deliberately" do
    User.from_omniauth(auth(provider: "google_oauth2", email: "same@example.com"))
    User.from_omniauth(auth(provider: "apple", email: "same@example.com"))

    # Cross-provider linking by email is an account-takeover vector; two rows
    # is the accepted, stated behaviour (specs/0015, eng review).
    assert_equal 2, User.count
  end

  test "display_identity falls back to the provider when Apple withheld the email" do
    assert_equal "Apple", User.from_omniauth(auth).display_identity
    assert_equal "a@example.com",
      User.from_omniauth(auth(uid: "uid-2", email: "a@example.com")).display_identity
  end
end
