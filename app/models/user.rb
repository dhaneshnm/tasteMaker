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
  # Reader-written lines (story 0032). Same deletion contract as favorites:
  # the corner's delete-account action must strand no user content (eng A2).
  has_many :impressions, dependent: :delete_all

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

  # The handoff token (story 0017 Release 2).
  #
  # ASWebAuthenticationSession runs in a Safari-backed container with its OWN
  # cookie jar, so the session it establishes is invisible to the WKWebView the
  # reader returns to. Apple gives no way to share them. The way across is a
  # short-lived token: the callback signs one into the `tondo://` redirect, the
  # shell hands it to the web view, and `SessionsController#handoff` spends it
  # for a real session in the jar that matters.
  #
  # Rails signs and expires it, so there is no table and nothing to sweep. The
  # block's value is embedded in the token and compared on lookup, so bumping
  # `handoff_seq` invalidates every token issued before it — which is what makes
  # this single-use rather than merely short-lived. That matters: the token
  # rides a custom URL scheme, and on iOS a scheme can be claimed by more than
  # one app.
  #
  # 60 seconds is the whole budget for "sheet closes, shell navigates". The
  # duration is part of the signature, so changing it invalidates outstanding
  # tokens too.
  generates_token_for :handoff, expires_in: 60.seconds do |user|
    user.handoff_seq
  end

  # Spend it. `increment!` writes the counter the token embeds, so the same
  # token cannot be presented twice — a replay lands on a payload that no longer
  # matches and `find_by_token_for` returns nil, exactly as an expired one does.
  def spend_handoff_tokens!
    increment!(:handoff_seq)
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
