# One work a reader kept. Free, permanent, and never gated — that promise is the
# whole reason this exists (see specs/personas.md, persona 2 and persona 6).
#
# Identity is a random token in the reader's cookie. This table stores only its
# SHA256, so the column is not a credential:
#
#   cookie:  collector = "8hJBF1m2ivBz39U2qC9iHdnm"     ← the bearer secret
#   table:   collector_digest = sha256(that)            ← cannot be replayed
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

  validates :collector_digest, presence: true
  validates :painting_id, uniqueness: { scope: :collector_digest }

  # Not `scope :for` — `for` is a Ruby keyword and reads like a bug at the call site.
  scope :collected_by, ->(digest) { where(collector_digest: digest) }
end
