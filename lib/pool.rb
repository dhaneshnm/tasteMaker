# The candidate pool that story 0013 curates down to the 2,000 paintings the app
# ships with.
#
# Four museums describe the same facts in four vocabularies. Everything here is
# the translation layer: one struct, and the three derivations none of the four
# sources provides — when a painting was made, where it comes from, and whether
# anybody wrote anything about it.
module Pool
  MIRROR_DIR = Rails.root.join("tmp/pool")
  MANIFEST   = Rails.root.join("db/seeds/paintings.json")
  REPORT     = Rails.root.join("db/seeds/pool_report.md")

  # Better bar 7: zoomable, high quality. The current 110 never drop below
  # 1920px, so this is a floor the pool already clears and must not lose.
  MIN_EDGE = 1600

  # A title longer than this pushes the day's first written line off a phone
  # screen at the accessibility type cap, which is the bar story 0008 set and
  # `test/system/dynamic_type_test.rb` enforces. Measured, not guessed: at 95
  # characters the note clears the fold by a full line; at 105 by 2px; at 140 it
  # misses by 26px. Museum catalogue entries that name both sides of a folio and
  # every poem on it run to 300 characters and are not titles a front door can
  # hold.
  MAX_TITLE = 100

  # Museum text short of this is a tombstone — dimensions, a provenance
  # fragment, an inscription transcribed. Bar 6 counts text a reader can read,
  # so the fallback in story 0005 has something to fall back to.
  MIN_TEXT = 120

  # Europe and North America are the canon persona 3 says the leader never
  # leaves. Everything else counts toward range — stricter than the story's
  # "non-European/non-US" bar, which counted Canada as range.
  WESTERN = %w[europe north_america].freeze

  FIELDS = %i[
    source source_id title artist life_date dated year medium dimension
    country culture department region description creditline accession_number
    image_url_full image_url_800 image_width image_height image_license highlight
  ].freeze

  Candidate = Struct.new(*FIELDS, keyword_init: true) do
    def longest_edge = [ image_width.to_i, image_height.to_i ].max
    def text? = description.to_s.strip.length >= MIN_TEXT
    def highlight? = !!highlight

    def western? = WESTERN.include?(region)

    def identity = [ source, source_id ]

    # Anonymous works are not one prolific artist: an empty name falls back to
    # the work's own identity, so the per-artist ceiling cannot collapse every
    # unattributed painting in four museums into a single bucket.
    def artist_key
      normalised = artist.to_s.downcase.gsub(/[^a-z0-9]/, "")
      normalised.presence || "anon:#{source}:#{source_id}"
    end

    # Two museums holding the same painting is one painting.
    def dedup_key
      [ title.to_s.downcase.gsub(/[^a-z0-9]/, ""), artist.to_s.downcase.gsub(/[^a-z0-9]/, "") ].join("|")
    end

    def to_manifest
      to_h.transform_keys(&:to_s)
    end
  end

  REGIONS = %w[
    europe north_america east_asia south_asia southeast_asia
    west_asia_islamic africa latin_america oceania unknown
  ].freeze

  # Country and culture strings, matched as substrings, lowercased. Order
  # matters only within a region; the first region to match wins, so the
  # narrower buckets are listed before the broad ones.
  PLACES = {
    "east_asia" => %w[china chinese japan japanese korea korean tibet tibetan mongolia taiwan
                      guangdong beijing peking nanjing shanghai hangzhou suzhou kyoto edo osaka],
    "south_asia" => %w[india indian pakistan nepal nepalese sri\ lanka ceylon bangladesh bhutan kashmir
                       mughal rajput pahari deccan rajasthan murshidabad bengal punjab lucknow gujarat
                       mewar marwar kangra basohli bikaner jodhpur jaipur tanjore mysore],
    "southeast_asia" => %w[vietnam thailand siam cambodia khmer indonesia java bali burma myanmar laos philippines malaysia],
    # "georgia" is deliberately absent: in these four American collections the
    # word is far more often the state than the country.
    "west_asia_islamic" => %w[iran persia persian turkey turkish ottoman iraq syria lebanon israel palestine arabia yemen
                              afghanistan uzbekistan samarkand bukhara central\ asia islamic safavid qajar egypt egyptian
                              morocco moroccan algeria tunisia armenia azerbaijan],
    "africa" => %w[nigeria benin ghana mali congo ethiopia ethiopian kenya sudan cameroon ivory\ coast senegal
                   south\ africa zimbabwe angola tanzania uganda yoruba ashanti africa african],
    "latin_america" => %w[mexico mexican peru peruvian brazil brazilian colombia cuba cuban guatemala bolivia
                          ecuador chile argentina venezuela haiti jamaica puerto\ rico aztec inca maya mayan],
    "oceania" => %w[australia new\ zealand papua polynesia melanesia micronesia hawaii maori fiji samoa],
    "north_america" => [ "united states", "america", "american", "canada", "canadian", "u.s.a", "usa" ],
    # Museums name a city as often as a country — the Art Institute gives
    # "Holland", "Flanders" and "Venice" where Minneapolis gives "Netherlands".
    "europe" => %w[france french italy italian netherlands holland dutch flemish flanders belgium germany german
                   spain spanish england english britain british united\ kingdom scotland scottish ireland irish
                   austria austrian switzerland swiss russia russian poland polish sweden swedish norway denmark
                   danish finland greece greek portugal hungary czech bohemia romania croatia serbia europe european
                   paris venice florence rome bologna milan naples siena tuscany umbria lombardy antwerp amsterdam
                   bruges ghent vienna prague madrid seville lisbon brussels munich dresden bavaria catalonia]
  }.freeze

  # Departments are the most reliable signal a museum gives — a curator put the
  # object there — so they are consulted before free-text country and culture.
  DEPARTMENTS = {
    "east_asia" => [ "chinese art", "japanese art", "korean art" ],
    "south_asia" => [ "indian art", "south asian art", "himalayan art" ],
    "west_asia_islamic" => [ "islamic art", "ancient near eastern art", "egyptian art" ],
    "africa" => [ "african art", "arts of global africa" ],
    "europe" => [ "european painting", "european art", "european paintings", "medieval art",
                 "greek and roman art", "the cloisters", "robert lehman collection",
                 "painting and sculpture of europe" ],
    "north_america" => [ "american art", "the american wing", "american painting" ]
  }.freeze

  # Departments that name more than one region. They never decide on their own —
  # `Arts of the Americas` is mostly United States work at Minneapolis and at
  # the Art Institute, and reading it as Latin America counted ~290 American
  # paintings as range that is not there.
  AMBIGUOUS_DEPARTMENTS = {
    "arts of the americas" => "north_america",
    "art of the americas" => "north_america",
    "asian art" => "east_asia",
    "arts of asia" => "east_asia",
    "arts of africa, oceania, and the americas" => nil,
    "arts of africa and the americas" => nil,
    "modern and contemporary art" => nil
  }.freeze

  def self.region_for(country:, culture:, department:, continent: nil)
    haystack = [ country, culture, continent ].compact.join(" ").downcase
    dept = department.to_s.downcase
    ambiguous = AMBIGUOUS_DEPARTMENTS.find { |name, _| dept.include?(name) }

    if ambiguous.nil?
      DEPARTMENTS.each do |region, names|
        return region if names.any? { |n| dept.include?(n) }
      end
    end

    # Whole words only: "Indiana" is not India, and an incantation is not Inca.
    PLACES.each do |region, terms|
      return region if terms.any? { |t| haystack.match?(/\b#{Regexp.escape(t)}\b/) }
    end

    # An ambiguous department is better than nothing once the place has failed.
    return ambiguous.last if ambiguous&.last

    # Continent is the last resort: it is the only field MIA gives that always
    # has a value, and it cannot distinguish Japan from India.
    case continent.to_s.downcase
    when "asia" then "east_asia"
    when "africa" then "africa"
    when "europe" then "europe"
    when "north america" then "north_america"
    when "south america" then "latin_america"
    when "oceania" then "oceania"
    else "unknown"
    end
  end

  # Museum date fields are prose ("c. 1570–75", "Edo period (1615–1868)"). The
  # latest year mentioned is when the thing was finished.
  def self.year_from(text, structured = nil)
    return structured.to_i if structured.present? && structured.to_i.between?(-4000, 2100)

    years = expand_abbreviated_ranges(text).scan(/\d{3,4}/).map(&:to_i).select { |y| y.between?(100, 2100) }
    years.max
  end

  # Museums write "c. 1570–75" and mean 1575. Left alone, the range reads as
  # ending in 1570 — which lands on the wrong side of the 1900 bar whenever the
  # abbreviation crosses a century, as "1898–02" does.
  def self.expand_abbreviated_ranges(text)
    text.to_s.gsub(/(\d{2})(\d{2})\s*[-–—]\s*(\d{2})(?!\d)/) do
      century, decade, ending = Regexp.last_match(1).to_i, Regexp.last_match(2).to_i, Regexp.last_match(3).to_i
      century += 1 if ending < decade
      "#{Regexp.last_match(1)}#{Regexp.last_match(2)} #{century}#{Regexp.last_match(3)}"
    end
  end
end
