# A registered iOS install (story 0015). The column is the SHA256 of the
# Keychain UUID — the cookie is the bearer credential, this table is not a
# second copy of it. Deleting a row is the revocation story: that device is out,
# with a validly signed cookie in hand, and nobody else notices (decisions/0011).
class Device < ApplicationRecord
  validates :token_digest, presence: true, uniqueness: true

  # The token→digest rule is this table's invariant, so it lives here — the
  # wall, registration, and the tests all call this instead of each spelling
  # the hash themselves. The App Attest upgrade path would change one method.
  def self.digest(token)
    Digest::SHA256.hexdigest(token)
  end

  # Once a day, not once a request, and update_column on purpose: no
  # validations, no callbacks, no updated_at churn — SQLite does not take a
  # write per pageview for a timestamp nobody reads more often than daily.
  def note_seen
    return if last_seen_at && last_seen_at > 24.hours.ago
    update_column(:last_seen_at, Time.current)
  end

  # Find-or-create by a raw token, racing cold launches absorbed the same
  # way everywhere: two callers used to spell this rescue independently
  # (device_registrations_controller.rb, push_registrations_controller.rb)
  # — one home for it now (/simplify, reuse finding).
  #
  # Rescues BOTH races the uniqueness index can produce, not just one
  # (/code-review, finding 3): a raw INSERT collision raises
  # RecordNotUnique, but if the second request's own uniqueness-validation
  # SELECT runs after the first request's row has already committed — a
  # wider window than the raw-insert race — `create!` raises RecordInvalid
  # instead, from the model's own `validates ... uniqueness: true`. Only
  # rescuing the first left `POST /device/registrations` and
  # `POST /device/push_registrations` with mode=enroll exposed to an
  # unhandled 500 under that timing.
  def self.find_or_create_by_digest!(token)
    find_or_create_by!(token_digest: digest(token))
  rescue ActiveRecord::RecordNotUnique, ActiveRecord::RecordInvalid
    find_by!(token_digest: digest(token))
  end

  # Story 0010. Clears by TOKEN VALUE, not by row: a device wipe re-mints
  # the Keychain UUID and can leave a stale second row holding the same
  # apns_token, and a row-scoped clear would leave that phone still getting
  # knocked. Three call sites need this (opt-out from the web, the
  # `.denied` reconcile clearing a token from the app, DailyPushJob pruning
  # a dead token) — one method so the invariant can't be half-applied
  # (/simplify, altitude finding: the `.denied` path had drifted to a
  # row-scoped `update_column` before this).
  def self.clear_apns_token!(token)
    where(apns_token: token).update_all(apns_token: nil)
  end
end
