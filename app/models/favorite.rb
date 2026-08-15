# One work a reader kept. Free, permanent, and never gated — that promise is the
# whole reason this exists (see specs/personas.md, persona 2 and persona 6).
#
# Two keys since story 0015, exactly one per row:
#
#   device world (iOS)              account world (web)
#   collector_digest = sha256 of    user_id → users row created by
#   the Keychain UUID the shell     Google/Apple sign-in
#   registered
#
# The worlds do not merge (decisions/0011, Q5): a device's keeps and a user's
# keeps are separate collections, and no claim path exists until a real user
# asks for one.
#
#   cookie:  device = "8hJBF1m2…" (signed)   ← the bearer secret
#   table:   collector_digest = sha256(…)    ← cannot be replayed
#
# Keyed to a painting rather than to a DailyPick on purpose. A pick can be
# rescheduled or removed by the curator; a kept work must survive that:
#
#   Aug 2  pick ──> painting ──> favorite     curator deletes the Aug 2 pick
#                      ▲                             │
#                      └── favorite still points here ┘
#                          the row renders unlinked, and its owner can still
#                          let it go (see days/_row.html.erb)
class Favorite < ApplicationRecord
  belongs_to :painting
  belongs_to :user, optional: true

  # Exactly one identity, stated as two validations so each failure names the
  # missing or extra half rather than a combined riddle.
  validates :collector_digest, presence: true, unless: :user_id
  validates :collector_digest, absence: true, if: :user_id

  validates :painting_id, uniqueness: { scope: :collector_digest }, unless: :user_id
  validates :painting_id, uniqueness: { scope: :user_id }, if: :user_id

  # Not `scope :for` — `for` is a Ruby keyword and reads like a bug at the call site.
  scope :collected_by, ->(digest) { where(collector_digest: digest) }
  scope :owned_by, ->(user) { where(user: user) }
end
