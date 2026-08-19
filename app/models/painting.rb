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

  # Story 0018. Names that show up as a literal `artist` value but are a
  # curator field, not a hand that painted anything — the four museums put the
  # culture, country, or a placeholder in the same column when no artist is
  # credited.
  #
  # Deny-listed by exact string, not by shape. Single-word suppression was
  # tried and rejected (eng review E2): it also silences Govardhan, Chokha,
  # Fayzullah, Basavana and Purkhu, real Mughal and Pahari painters with 2-4
  # works each in this pool.
  #
  # The five placeholder strings below (found by /qa, 2026-08-19, browsing
  # /feed) are the second shape of the same defect: E2's review query asked
  # only "is `artist` a literal country/culture name", so `Painting.where(
  # artist: "Unidentified artist")` — a museum's own "we don't know" marker —
  # was never checked and rendered as a live, tappable artist page. Exhaustive
  # for the pool as measured: `Painting.where.not(artist: [nil, ""]).distinct.
  # pluck(:artist).select { |a| a =~ /unidentified|unknown|anonymous|various|
  # not identified|maker unknown/i }` returns exactly these five, 9 works
  # total, none previously in this list.
  # Third recurrence of one defect, and the first time it was measured rather
  # than sampled (story 0019, eng review finding 3). E2 found culture strings by
  # asking "is `artist` a literal country name"; `/qa` found museum placeholders
  # the same way; both were spot checks. Sweeping the manifest and all four
  # mirrors with `Pool.place_shaped?` — the same `PLACES` vocabulary
  # `Pool.region_for` uses — returns **102 distinct strings over 580 rows**, of
  # which 49 works over 31 strings were already live `/artists/:slug` pages in
  # production: `/artists/india-calcutta` with 5 works, `/artists/probably-mexico`
  # with 5, `/artists/persia-iran` with 5.
  #
  # Still an EXACT-string list, not a shape rule. E2 settled that and the sweep
  # confirms it: "Mewar Stipple Master" and "Ugolino da Siena" are painters named
  # for places, and any rule that suppressed the strings below would suppress
  # them too. `pool:report` now prints both the single-word slugs and every
  # place-shaped string so the next one surfaces for a human pass before seeding
  # instead of after — which is the forcing function the first two rounds lacked.
  NOT_AN_ARTIST = [
    # Museum placeholders: "we don't know" in the artist column.
    #
    # "Anonymous" is the sixth, and it is the FOURTH time this defect has been
    # found by hand rather than by a check (0018 E2 → /qa ISSUE-001 → 0019's
    # eng review → 0019's code review, which caught `/artists/anonymous` live
    # in the re-curated manifest). The placeholder shape is a closed set of
    # English words, so it is now an assertion in `pool_quota_test` rather
    # than a list somebody has to remember to read.
    "Unidentified", "Unknown", "Anonymous", "Artist unknown", "Unidentified artist",
    "Various artists",
    # A country or culture standing in for a hand.
    #
    # Teotihuacan, Chancay and Gujarati came in with the re-curation and are
    # not in `Pool::PLACES` — that vocabulary maps works to REGIONS, so
    # widening it to catch culture names would change `region_for` and the
    # range bars with it. They are caught the way every other one is: the
    # report lists them, a human reads it.
    "China", "Japan", "Islamic", "Tibet", "India", "Korea", "Nepal", "Egypt",
    "Teotihuacan", "Chancay", "Gujarati",
    "Italy", "Ethiopia", "Sweden", "United States", "Mughal",
    "Italian", "French", "German", "Spanish", "Dutch", "Flemish", "British", "English", "Austrian",
    "Ancient Egyptian", "Probably Mexico", "Mewar school", "Painter: Mughal school",
    "Northern Europe (active England)", "Egypt; or Mesopotamia (Iraq)",
    "Workshop: Mewar (Udaipur) workshop", "Possibly Persia (Iran); or Turkey",
    # The Met's form for an anonymous work of a known school.
    "French Painter", "Russian Painter", "British Painter", "German Painter", "Spanish Painter",
    "North Italian Painter", "Northern French Painter", "Italian (Florentine) Painter",
    "Spanish (Catalan) Painter", "British School", "French School",
    # Region-with-subregion, the Cleveland and Minneapolis form.
    "Persia (Iran)", "Mexico (Mexico City)", "Italy (Pompeii)", "Austria (Tyrol)",
    "India (Calcutta)", "India (Rajasthan)", "India (Madhya Pradesh)", "India (Kishangarh)",
    "India (Jaipur, Rajasthan)", "India (Bikaner)", "India (Kangra)", "India (Marwar)",
    "India (Deccan)", "India (Mewar)", "India (Gujarat)", "India (Thanjavur, Tamil Nadu)",
    "India (Chambra)"
  ].freeze

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

  # The slug an artist string resolves to, or nil when it must never carry a
  # link: blank, a `NOT_AN_ARTIST` culture string, or a name that
  # transliterates to nothing at all (an OCR-shaped artifact — `parameterize`
  # on punctuation alone returns ""). One function, so `artist_path` is never
  # built with an empty segment (`UrlGenerationError`), and the migration
  # backfill and this row's own write path read the same implementation
  # (eng review E1/T12).
  def self.artist_slug_for(artist)
    name = artist.to_s.strip
    # `casecmp?`, not `.include?` — found by /code-review: a differently-cased
    # duplicate of an already-known placeholder ("CHINA", "unidentified
    # artist") would otherwise slip the deny-list on a future reseed. The
    # list itself stays as-written case (it is also the display fallback
    # elsewhere); only the comparison folds case.
    return nil if name.blank? || NOT_AN_ARTIST.any? { |denied| denied.casecmp?(name) }

    name.parameterize.presence
  end

  before_save { self.artist_slug = self.class.artist_slug_for(artist) }

  # The heading for an artist page, computed over the artist strings the page
  # is already holding (never re-queried — the caller has the rows loaded).
  # Among every distinct string, the one with the most accented characters
  # wins — an accent is information and its absence is loss — then the more
  # frequent spelling, then alphabetical, for a result with no ties in the
  # pool as measured (eng review E4). "Most frequent" alone titled the
  # 9-work flagship page "Paul Cezanne" over "Paul Cézanne".
  def self.canonical_artist_name(names)
    names.tally.min_by { |name, count| [ -accent_count(name), -count, name ] }&.first
  end

  # Counts diacritic letters, not any non-ASCII character — found by
  # /code-review: a curly quote or em dash (this pool's own museum-paste-up
  # artifacts, see `plain_text` above) is non-ASCII but not an accent, and
  # counting it could tip the tie-break on punctuation rather than the
  # genuine diacritic the rule is about.
  def self.accent_count(string)
    string.to_s.each_char.count { |char| char.ord > 127 && char.match?(/\p{L}/) }
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
  # rather than truncating — a title is never cut. A class method too: the
  # artist page's heading is a bare string, not a Painting, and needs the
  # same threshold (story 0018) — one comparison, not two copies of it.
  LONG_TITLE = 60

  def self.long_title?(string)
    string.to_s.length > LONG_TITLE
  end

  def long_title?
    self.class.long_title?(title)
  end
end
