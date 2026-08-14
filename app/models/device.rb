# A registered iOS install (story 0015). The column is the SHA256 of the
# Keychain UUID — the cookie is the bearer credential, this table is not a
# second copy of it. Deleting a row is the revocation story: that device is out,
# with a validly signed cookie in hand, and nobody else notices (decisions/0011).
class Device < ApplicationRecord
  validates :token_digest, presence: true, uniqueness: true

  # Once a day, not once a request, and update_column on purpose: no
  # validations, no callbacks, no updated_at churn — SQLite does not take a
  # write per pageview for a timestamp nobody reads more often than daily.
  def note_seen
    return if last_seen_at && last_seen_at > 24.hours.ago
    update_column(:last_seen_at, Time.current)
  end
end
