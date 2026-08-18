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

  test "provider_name speaks the reader's language, not OAuth's" do
    assert_equal "Google", User.new(provider: "google_oauth2").provider_name
    assert_equal "Apple", User.new(provider: "apple").provider_name
  end

  # Apple's Hide My Email can withhold the address, and a reader who declines
  # the scope leaves it nil — so the branch that drops "as …" is the one worth
  # pinning. Two screens print this string: the corner, where the account is
  # administered, and the foot of the collection.
  test "the identity line names the provider, and the address only when there is one" do
    user = User.from_omniauth(auth(provider: "google_oauth2", email: "maya@example.com"))
    assert_equal "Google as maya@example.com", user.signed_in_summary

    user.update!(email: nil)
    assert_equal "Google", user.signed_in_summary

    user.update!(email: "   ")
    assert_equal "Google", user.signed_in_summary,
      "a blank address is not an address"
  end
end
