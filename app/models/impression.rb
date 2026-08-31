# One line, written before the note was read (story 0032).
#
#   sit (60s) ──> ready state ──> reader writes ──> reveal ──> line sits
#                                                              above the note
#
# Ink, not pencil: one impression per reader per painting, never edited,
# never rewritten (D6 — the owner's slow-looking protocol treats the notebook
# as write-once; the cross-model dissent wanting edits is recorded in the
# plan). Account-backed only — a device identity keeps favorites but cannot
# write here (owner decision 2026-08-31; challenged on record, upheld).
class Impression < ApplicationRecord
  belongs_to :user
  belongs_to :painting

  # Strip first so " " cannot dodge the presence check, and so a trailing
  # newline from a shell client does not count against the 280.
  before_validation { self.body = body&.strip }

  validates :body, presence: true, length: { maximum: 280 }
  validates :painting_id, uniqueness: { scope: :user_id }
end
