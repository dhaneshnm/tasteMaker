# One painting, one calendar day, one hand-written note.
#
# `blurb` is the curator's own writing and is deliberately separate from
# `paintings.description`, which is museum copy.
#
#   Aug 1 ✓        Aug 2 ✓        Aug 3 (none)      Aug 4 ✓ queued
#   ├─ pick        ├─ pick        ├─ nothing        ├─ exists in the table
#   └─ shown,      └─ shown,      └─ Aug 2 stays    └─ invisible until the
#      dated Aug 1    dated Aug 2     up, still         Eastern clock reaches
#                                     dated Aug 2       Aug 4
#
# `current` never reaches past today, so the queue can be filled weeks ahead
# without leaking tomorrow's artwork.
class DailyPick < ApplicationRecord
  BLURB_WORDS = (60..180) # calibration target; the admin nudges, never blocks

  belongs_to :painting

  validates :painting_id, uniqueness: { message: "has already had its day" }
  validates :scheduled_on, presence: true,
    uniqueness: { message: "already has an artwork scheduled" }
  validates :blurb, presence: true
  validate :painting_must_have_an_image

  scope :published, -> { where(scheduled_on: ..Date.current) }
  scope :with_artwork, -> { includes(painting: { image_attachment: :blob }) }

  # The artwork of the day: the most recent pick that has actually arrived.
  # Falls back to the last published day when today was never scheduled.
  #
  # Deliberately not eager-loaded: `includes` is a no-op for a single record,
  # and the daily page revalidates on every visit, so preloading the painting
  # would cost three throwaway queries on each 304.
  def self.current
    published.order(scheduled_on: :desc).first
  end

  # The neighbours a reader walks to. Bounded by `published`, so the walk never
  # steps into the queue and never lands on a day that was skipped: a gap is
  # simply not there, and the next published day is the next step.
  #
  #   Aug 1 ✓ ── Aug 2 ✓ ── (Aug 3 none) ── Aug 4 ✓
  #     └─ next ────┘             next ────────┘
  #
  def previous_published
    self.class.published.where(scheduled_on: ...scheduled_on).order(scheduled_on: :desc).first
  end

  def next_published
    self.class.published.where(scheduled_on: (scheduled_on + 1)..).order(:scheduled_on).first
  end

  # The first day from today forward that has no artwork yet — never a
  # historical gap, never a date that is already taken.
  def self.first_open_date
    taken = where(scheduled_on: Date.current..).pluck(:scheduled_on)
    date = Date.current
    date += 1 while taken.include?(date)
    date
  end

  # The paintings a curator can still choose. This mirrors the "one day per
  # painting" rule above, plus whichever painting `pick` already holds so a
  # record never vanishes from its own edit form. Kept here so the rule has
  # one home when the pool grows and the constraint relaxes.
  def self.selectable_paintings(pick = nil)
    spoken_for = where.not(id: pick&.id).select(:painting_id)

    Painting.with_attached_image
            .select(:id, :title, :artist, :culture, :dated, :image_url_800)
            .where.not(id: spoken_for)
            .order(:title)
  end

  def blurb_word_count
    blurb.to_s.split.size
  end

  def published?
    scheduled_on <= Date.current
  end

  private

  # A day with no picture is not a day worth publishing. Catching it here keeps
  # the broken-image state on the public page nearly unreachable.
  def painting_must_have_an_image
    return if painting.blank?
    errors.add(:painting, "has no usable image") unless painting.display_image?
  end
end
