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

    # `TABLE`'s terms compiled to `\b`-anchored, case-insensitive `Regexp`s
    # once at load time, not per painting — `from_strings` runs once per
    # work on every seed and every `backfill!` row (eng review: ~15,000
    # regex compiles per run against `TABLE` uncompiled).
    PATTERNS = TABLE.map { |value, terms| [ value, terms.map { |t| /\b#{Regexp.escape(t)}\b/i } ] }.freeze

    # Returns the canonical display value or nil. `artist` participates in
    # the match ONLY when it is a NOT_AN_ARTIST placeholder — a real name is
    # never pattern-matched.
    def self.from_strings(culture:, country:, department:, artist: nil)
      fields = [ culture, country, department ]
      fields << artist if artist.present? && Painting.artist_slug_for(artist).nil?

      haystack = fields.compact.join(" ")
      return nil if haystack.blank?

      PATTERNS.each do |value, patterns|
        return value if patterns.any? { |re| re.match?(haystack) }
      end
      nil
    end

    # The 0008 research report's per-tradition counts (`user-research/
    # 0008-recognizable-themes.md` §3.5) — the sizing instrument the shipping
    # table's stricter matching is measured against in `audit`. Deliberate
    # departures (Rajput's dropped `rajasthan`) are named in
    # `specs/0024-the-named-traditions/plan.md`'s Deviations, not repeated
    # here as a second source of truth.
    RESEARCH_COUNTS = {
      "Japanese Painting" => 276, "Chinese Painting" => 180, "Mughal Painting" => 102,
      "Rajput Painting" => 102, "Pahari Painting" => 84, "Jain Manuscript Painting" => 52,
      "Kalighat Painting" => 44, "Korean Painting" => 32, "Tibetan & Nepalese Painting" => 24,
      "Persian & Islamic Painting" => 19
    }.freeze

    BackfillResult = Struct.new(:updated, :total, keyword_init: true)

    # Backfills `paintings.tradition` on existing rows without a reseed —
    # `db/seeds.rb` already writes it at seed time; this is for rows created
    # before this story shipped, or after a metadata-only migration.
    def self.backfill!
      updated = 0
      total = 0
      Painting.find_each do |painting|
        total += 1
        value = from_strings(culture: painting.culture, country: painting.country,
          department: painting.department, artist: painting.artist)
        next if painting.tradition == value

        painting.update_column(:tradition, value)
        updated += 1
      end
      BackfillResult.new(updated: updated, total: total)
    end

    ReconciliationRow = Struct.new(:value, :shipped, :researched, :starved?, keyword_init: true)
    AuditResult = Struct.new(:reconciliation, :sample, keyword_init: true)

    # Two instruments (story 0024 eng review): a precision sample (catches
    # false positives — a wrongly-stamped row) and a reconciliation against
    # `RESEARCH_COUNTS` (catches the failure the sample structurally cannot:
    # a starved bucket, where an unstamped work is never in the sample —
    # this is how the Jain-without-`gujarat` regression was caught at plan
    # time, before it shipped). The sample weights toward the smallest
    # shipped bucket, since a small bucket's errors move its percentage most.
    def self.audit(sample_size: 50)
      stamped = Painting.where.not(tradition: nil).group(:tradition).count
      reconciliation = (RESEARCH_COUNTS.keys | stamped.keys).sort.map do |value|
        shipped = stamped[value] || 0
        researched = RESEARCH_COUNTS[value]
        ReconciliationRow.new(value: value, shipped: shipped, researched: researched,
          starved?: researched && shipped < researched * 0.5)
      end

      smallest = stamped.min_by { |_, n| n }&.first
      weighted_count = [ sample_size / 5, stamped.size ].min
      sample = Painting.where(tradition: smallest).order("RANDOM()").limit(weighted_count) +
        Painting.where.not(tradition: nil).order("RANDOM()").limit(sample_size - weighted_count)

      AuditResult.new(reconciliation: reconciliation, sample: sample)
    end
  end
end
