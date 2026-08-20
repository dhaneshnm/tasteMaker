# Turns a work's culture/country/department strings (plus, in one narrow
# case, its artist string — see below) into a named painting tradition a
# reader can filter by (story 0024). `PeriodBucket`'s twin: a pure function,
# ordered pattern table, first match wins.
#
# Match fields: culture ∪ country ∪ department, PLUS `artist` when — and
# only when — the artist string is a `NOT_AN_ARTIST` placeholder
# (`Painting.artist_slug_for` returns nil for it). Museums misfile school
# data in the artist column, and only some of those strings are on the
# model's own deny-list ("Mewar school", "Painter: Mughal school" are;
# "Nurpur workshop", "Baysunghur school" are NOT — verified against the
# manifest, and a real, if uncredited, painter attribution stays a real
# attribution, never pattern-matched). The union is load-bearing for the
# two that ARE listed: their rows carry `country: "India"` alone, which
# matches no table term — "Mewar school"/"Painter: Mughal school" is the
# only signal that resolves them to Rajput/Mughal respectively.
# A real artist's name never participates in the match, so an artist whose
# real name happens to contain a term (e.g. "Kota Ezawa") can never be
# mislabeled — the placeholder check runs first and gates the whole field.
#
# Every pattern is \b-word-anchored and case-insensitive: "Indochina" must
# not fire `china`, "Normandie" must not fire `mandi`. Word boundaries cost
# nothing and the pool is rebuilt by re-curation, so a collision that isn't
# in today's manifest is still a real future risk (eng review, story 0024).
#
# Three table calls, each from a measured fact against the committed
# manifest (eng review + outside voice, story 0024):
#
#   - `gujarat` stays in the Jain row: the pool's ~51 Jain manuscript works
#     (Kalpa-sutra folios) carry culture "Western India, Gujarat" — the bare
#     `jain` substring alone matches exactly 1 work. Dropping `gujarat`
#     ships a value that never clears MIN_FACET_WORKS and never renders.
#     Bare `rajasthan` stays OUT — the Rajput row's school terms carry that
#     bucket fine without the wider, noisier region word.
#   - Korean precedes Japanese: culture "Korea, Japanese colonial period
#     (1910−1945)" fires both `korea` and `japan`; table order is the
#     tie-break, and Japan-first would label colonial-era Korean painting
#     "Japanese" — wrong-label-worse-than-no-label (0022's BCE lesson).
#   - "Persian & Islamic Painting" is a deliberate merge: 0008 measured
#     "Persian miniature" demand: the pool's ~19 works span Persian,
#     Ottoman and Indo-Islamic sources. Splitting drops every piece below
#     the display floor.
module Pool
  module Tradition
    TABLE = [
      [ "Mughal Painting", %w[mughal] ],
      [ "Pahari Painting", %w[pahari kangra guler basohli mandi nurpur bilaspur] ],
      [ "Rajput Painting", %w[rajput mewar marwar bundi kota bikaner kishangarh] ],
      [ "Kalighat Painting", %w[kalighat] ],
      [ "Jain Manuscript Painting", %w[jain gujarat] ],
      [ "Korean Painting", %w[korea] ],
      [ "Chinese Painting", %w[china chinese] ],
      [ "Japanese Painting", %w[japan] ],
      [ "Persian & Islamic Painting", %w[persia iran safavid qajar islamic ottoman baysunghur] ],
      [ "Tibetan & Nepalese Painting", %w[tibet nepal] ]
    ].freeze

    # Returns the canonical display value or nil. `artist` participates in
    # the match ONLY when it is a NOT_AN_ARTIST placeholder — a real name is
    # never pattern-matched.
    def self.from_strings(culture:, country:, department:, artist: nil)
      fields = [ culture, country, department ]
      fields << artist if artist.present? && Painting.artist_slug_for(artist).nil?

      haystack = fields.compact.join(" ")
      return nil if haystack.blank?

      TABLE.each do |value, terms|
        return value if terms.any? { |term| word_match?(haystack, term) }
      end
      nil
    end

    def self.word_match?(haystack, term)
      haystack.match?(/\b#{Regexp.escape(term)}\b/i)
    end
  end
end
