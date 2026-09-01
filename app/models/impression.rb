# The reader's answer to the day's looking prompt (story 0032, redesigned
# 2026-09-01).
#
#   prompt ──> reader types (autosaves, draft) ──> reveal ──> the answer
#                                                             sits above the note
#
# A DRAFT until the reveal: autosave updates it freely while the reader
# looks; opening the note is what makes it ink (owner decision 2026-09-01,
# amending D6's write-once — the enforcement is UI-level: the field never
# renders after the reveal, and the server allowing a reader to rewrite
# their own 280 characters by hand-rolled request harms no one). One row
# per reader per painting still — the unique index is identity, not
# immutability. Account-backed only — a device identity keeps favorites
# but cannot write here (owner decision 2026-08-31).
class Impression < ApplicationRecord
  belongs_to :user
  belongs_to :painting

  # Strip first so " " cannot dodge the presence check, and so a trailing
  # newline from a shell client does not count against the 280.
  before_validation { self.body = body&.strip }

  # Reader-facing words (owner's copy pass, 2026-08-31) — the partial renders
  # `errors.map(&:message)`, never full_messages, so no "Body" prefix ever
  # reaches the page. The uniqueness message is a backstop: the field never
  # renders once a line exists, so only a race or a hand-rolled POST sees it.
  validates :body, presence: { message: "Write something first." },
                   length: { maximum: 280, message: "Keep it under 280 characters." }
  validates :painting_id, uniqueness: { scope: :user_id, message: "Already saved." }
end
