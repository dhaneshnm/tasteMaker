class Painting < ApplicationRecord
  has_one_attached :image

  validates :mia_id, presence: true, uniqueness: true
  validates :title, presence: true

  scope :feed_ordered, -> { order(:feed_order, :id) }

  # Serve the locally stored copy when present; fall back to the museum CDN
  # so the feed still works before `db:seed` finishes downloading images.
  def display_image?
    image.attached? || image_url_800.present?
  end

  def aspect_ratio
    return nil unless image_width.to_i.positive? && image_height.to_i.positive?
    "#{image_width} / #{image_height}"
  end

  def artist_display
    artist.presence || culture.presence || "Unknown artist"
  end

  def meta_line
    [ dated.presence, medium.presence ].compact.join(" — ")
  end

  def credit_line
    [ creditline.presence, accession_number.presence ].compact.join(" · ")
  end

  def alt_text
    "#{title} — #{artist_display}"
  end

  # Museum titles run long. Past this the daily page steps the type down
  # rather than truncating — a title is never cut.
  LONG_TITLE = 60

  def long_title?
    title.to_s.length > LONG_TITLE
  end
end
