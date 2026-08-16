class Painting < ApplicationRecord
  has_one_attached :image

  # The four collections the pool is drawn from (story 0013). Names carry their
  # own article because they are read mid-sentence — "From the Cleveland Museum
  # of Art" — and two of the four want one while two do not.
  SOURCES = {
    "mia" => { name: "the Minneapolis Institute of Art", url: "https://collections.artsmia.org" },
    "met" => { name: "The Metropolitan Museum of Art",   url: "https://www.metmuseum.org/art/collection" },
    "aic" => { name: "the Art Institute of Chicago",     url: "https://www.artic.edu/collection" },
    "cma" => { name: "the Cleveland Museum of Art",      url: "https://www.clevelandart.org/art/collection" }
  }.freeze

  # Museum copy arrives as HTML from half the collections — Cleveland ships
  # <em>/<i> title italics, Minneapolis ships whole Google Docs paste-ups
  # (<span style>, <font face>, <b id="docs-internal-guid-…">) — and the page
  # renders `description` as one escaped paragraph, so anything that survives
  # ingest is read by the visitor as a literal "<em>" (bug, 2026-08-15).
  #
  # Stripped, not sanitized: keeping <em> for one italic would mean calling
  # html_safe on third-party copy, and <p>/<br> cannot legally nest inside the
  # single clamped <p> the wall label already is.
  #
  # Block tags become a space FIRST — strip_tags alone closes the gap and gives
  # "prosperity.Waldo sold", which is worse than the tag it removed.
  NBSP = /&nbsp;|\u00A0/
  BLOCK_TAG = %r{</?(?:p|br|div|li|tr|h[1-6]|blockquote)\b[^>]*>}i

  # Two passes, because the copy carries both live tags and tags the museum
  # escaped before storing them — AIC ships a literal "&lt;BIG&gt;" — and one
  # pass leaves behind whichever kind it did not start with. Stable at two:
  # `plain_text(plain_text(x)) == plain_text(x)` for every row in the pool, and
  # the model test pins that.
  def self.plain_text(html)
    return nil if html.blank?

    text = html.to_s
    2.times do
      text = ActionView::Base.full_sanitizer.sanitize(text.gsub(NBSP, " ").gsub(BLOCK_TAG, " "))
      text = CGI.unescapeHTML(text.to_s)
    end
    text.squish.presence
  end

  # On the model, not in each source adapter: every write path goes through
  # here — four adapters, `db/seeds.rb`, and whatever the fifth museum turns out
  # to be — and a source added later cannot reintroduce this by forgetting a
  # call (R1).
  normalizes :description, with: ->(html) { plain_text(html) }

  # Museum object ids collide across museums, so identity is the pair.
  validates :source, presence: true, inclusion: { in: SOURCES.keys }
  validates :source_id, presence: true, uniqueness: { scope: :source }
  validates :title, presence: true

  scope :feed_ordered, -> { order(:feed_order, :id) }

  # The museums actually in the pool, heaviest first. The gallery's closing line
  # credits these rather than a hard-coded list, so it stays true after a reseed
  # changes the mix (story 0013).
  def self.represented_sources
    group(:source).order(count_all: :desc).count.keys.filter_map { |key| SOURCES[key] }
  end

  # Serve the locally stored copy when present; fall back to the museum CDN
  # so the feed still works before `db:seed` finishes downloading images.
  def display_image?
    image.attached? || image_url_800.present?
  end

  def source_name = SOURCES.dig(source, :name)
  def source_url  = SOURCES.dig(source, :url)

  # Stable across reseeds, unique across museums — the feed anchors on it.
  def dom_key = "#{source}_#{source_id}"

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
