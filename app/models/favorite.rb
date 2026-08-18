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

  # The claim (story 0017 Release 2, decisions/0013). One way, once.
  #
  #   device rows                      account rows
  #   collector_digest = sha256(uuid)  user_id = N
  #        │                                ▲
  #        └──── claim! ────────────────────┘
  #              painting already kept there? the device row is DELETED
  #              otherwise?                    it is MOVED
  #
  # Two statements inside one transaction, not a loop.
  #
  # The delete has to come first. `index_favorites_on_user_id_and_painting_id`
  # is unique, so moving a row for a painting the account already holds raises
  # instead of merging — and a row-at-a-time loop that raises partway leaves the
  # collection split across both identities, which on an operation with no undo
  # is the worst available outcome. Clearing the collisions first makes the
  # update total.
  #
  # Cost is two queries whatever the size of the collection, and the transaction
  # plus SQLite's single-writer serialization is what makes a retried handoff
  # idempotent rather than racy: the second call finds nothing left to move.
  #
  # SQLITE IS LOAD-BEARING HERE. `index_favorites_on_collector_digest_and_painting_id`
  # is unique and NOT partial, unlike its `user_id` sibling. Setting the digest
  # to NULL on many rows at once only works because SQLite treats NULLs as
  # distinct in a unique index. Postgres does too, but `CLAUDE.md` says Postgres
  # needs a written reason — this is one of the lines that would have to be
  # re-read if that ever changes.
  #
  # Returns the number of works that actually moved, which is what tells the
  # caller whether the reader has a collection to be shown.
  def self.claim!(device:, user:)
    moved = 0

    transaction do
      mine = collected_by(device.token_digest)
      mine.where(painting_id: owned_by(user).select(:painting_id)).delete_all
      moved = mine.update_all(user_id: user.id, collector_digest: nil)
    end

    # Only when something moved. A device that claimed nothing has handed
    # nothing over, and the empty-collection copy keyed on this column would
    # otherwise tell a first-day reader their works are with an account.
    device.update_column(:claimed_at, Time.current) if moved.positive?

    moved
  end
end
