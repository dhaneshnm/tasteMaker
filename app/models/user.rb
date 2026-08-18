# A web reader with the account key (story 0015). OAuth subject and nothing
# else: `[provider, uid]` is the identity, unique together. Email and name are
# display data, never identity — email may be nil, may be an Apple private-relay
# address, and may go stale; nothing looks a user up by it. The same person
# signing in with Google one day and Apple the next is two users, deliberately:
# cross-provider linking by email is an account-takeover vector and stays out
# of scope (specs/0015, eng review).
class User < ApplicationRecord
  # delete_all skips callbacks on purpose — favorites have none today, and if
  # they ever grow any this line is the tripwire to revisit (eng review, Codex).
  has_many :favorites, dependent: :delete_all

  validates :provider, presence: true
  validates :uid, presence: true, uniqueness: { scope: :provider }

  # Apple sends name and email ONLY on the first authorization — losing them
  # then is losing them forever, so the create path persists them and a later
  # auth without them must not null them out.
  def self.from_omniauth(auth)
    user = find_or_initialize_by(provider: auth.provider, uid: auth.uid)
    user.email = auth.info&.email if auth.info&.email.present?
    user.name = auth.info&.name if auth.info&.name.present?
    user.save!
    user
  end

  def provider_name
    { "google_oauth2" => "Google", "apple" => "Apple" }.fetch(provider, provider)
  end

  # How this reader is named back to themselves — "Google as maya@example.com",
  # or just "Google" when the provider handed over no address (Apple's Hide My
  # Email can, and a reader who declined the scope will).
  #
  # One method because two screens print it: the corner, where the account is
  # administered, and the foot of the collection. They were two copies differing
  # in whitespace, and the day one gains a detail the other silently disagrees
  # on the page a reader opens in order to delete their account.
  def signed_in_summary
    email.present? ? "#{provider_name} as #{email}" : provider_name
  end
end
