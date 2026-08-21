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
#
# Story 0026 adds two rows, measured against the mirrors before their quota
# was set (plan step 3):
#
#   - "Madhubani Painting" (`madhubani`, `mithila`) — 11 CC0 CMA candidates,
#     culture "Eastern India, Bihar ... Mithila". Placed BEFORE Tibetan &
#     Nepalese: `mithila`/`nepal` co-occur on the region's border-adjacent
#     culture strings and Nepal must not win the tie.
#   - "Ukiyo-e Painting" is NOT a culture-string term — `ukiyo`/`floating
#     world` fire on zero mirror candidates; museums catalogue these works
#     by school and format, never the English art-historical label. Matched
#     instead by a curated artist allowlist (the story's own framing:
#     "Moronobu, Toyohiro, Katsushika Ōi") plus a medium check that keeps
#     woodblock PRINTS out — "ukiyo-e" spans both, and this facet is
#     specifically the pool's genuine hand-painted works (nikuhitsu-ga).
#     `ukiyo_e?` runs before the TABLE loop, ahead of Japanese Painting's
#     bare `japan` term. Measured 126 candidates across all four museums —
#     wider than 0008's 16 (that probe scoped to AIC+CMA only; MIA alone
#     holds 53 explicitly tagged `medium: "... (nikuhitsu) ..."`, the
#     museums' own term for a hand-painted hanging scroll, as opposed to a
#     print). Deviation from the plan's assumed culture-substring approach,
#     logged in specs/0026-the-wider-pool/plan.md Deviations.
module Pool
  module Tradition
    TABLE = [
      [ "Mughal Painting", %w[mughal] ],
      [ "Pahari Painting", %w[pahari kangra guler basohli mandi nurpur bilaspur] ],
      [ "Rajput Painting", %w[rajput mewar marwar bundi kota bikaner kishangarh] ],
      [ "Kalighat Painting", %w[kalighat] ],
      [ "Jain Manuscript Painting", %w[jain gujarat] ],
      [ "Madhubani Painting", %w[madhubani mithila] ],
      [ "Korean Painting", %w[korea] ],
      [ "Chinese Painting", %w[china chinese] ],
      [ "Japanese Painting", %w[japan] ],
      [ "Persian & Islamic Painting", %w[persia iran safavid qajar islamic ottoman baysunghur] ],
      [ "Tibetan & Nepalese Painting", %w[tibet nepal] ]
    ].freeze

    # Exact-name allowlist, not substring — the same caution `Recognizable`
    # takes with attribution: a school name like "Katsukawa Shunsho" is
    # matched by inclusion against `artist`, never a loose word.
    UKIYO_E_ARTISTS = %w[
      Moronobu Toyohiro Toyoharu Toyokuni Hokusai Hiroshige Utamaro Sharaku
      Kuniyoshi Kunisada Harunobu Kiyonaga Kiyomasu Kiyonobu Eizan Eisen Eishi
      Koryusai Koryūsai Shunsho Shunshō Shunkō Shunman Masanobu Sukenobu
      Choshun Chōshun Settei Katsushika Yoshitoshi Kaigetsudō Kaigetsudo
    ].freeze

    def self.ukiyo_e?(artist:, medium:)
      return false if artist.blank? || medium.blank?
      return false unless UKIYO_E_ARTISTS.any? { |name| Pool.word_match?(artist, name, case_insensitive: true) }

      m = medium.downcase
      return false if m.include?("print") || m.include?("woodblock") || m.include?("book")

      m.include?("hanging scroll") || m.include?("nikuhitsu") || m.include?("fan painting")
    end

    # `TABLE`'s terms compiled to `\b`-anchored, case-insensitive `Regexp`s
    # once at load time, not per painting — `from_strings` runs once per
    # work on every seed and every `backfill!` row (eng review: ~15,000
    # regex compiles per run against `TABLE` uncompiled).
    PATTERNS = TABLE.map { |value, terms| [ value, terms.map { |t| /\b#{Regexp.escape(t)}\b/i } ] }.freeze

    # The full canonical vocabulary `from_strings` can return — `TABLE`'s
    # values plus "Ukiyo-e Painting", which is matched by `ukiyo_e?` before
    # the TABLE loop ever runs and so is not itself a TABLE row. Callers that
    # need "every value this function can produce" (the quota test's
    # vocabulary/floor assertions) should use this, not `TABLE.map(&:first)`.
    VALUES = (TABLE.map(&:first) + [ "Ukiyo-e Painting" ]).freeze

    # Returns the canonical display value or nil. `artist` participates in
    # the TABLE match ONLY when it is a NOT_AN_ARTIST placeholder — a real
    # name is never pattern-matched there. `medium` is used only by
    # `ukiyo_e?`, checked first (before Japanese Painting's bare `japan`
    # term would otherwise win).
    def self.from_strings(culture:, country:, department:, artist: nil, medium: nil)
      return "Ukiyo-e Painting" if ukiyo_e?(artist: artist, medium: medium)

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
      "Persian & Islamic Painting" => 19,
      # Story 0026: Ukiyo-e's researched figure is 0008's AIC+CMA-only "16
      # strict" scope; the shipped matcher measures all four museums (126) —
      # a wider net by design, not a starved bucket, so this entry exists for
      # the record rather than to gate `starved?`.
      "Ukiyo-e Painting" => 16, "Madhubani Painting" => 11
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
          department: painting.department, artist: painting.artist, medium: painting.medium)
        next if painting.tradition == value

        painting.update_column(:tradition, value)
        updated += 1
      end
      BackfillResult.new(updated: updated, total: total)
    end

    ReconciliationRow = Struct.new(:value, :shipped, :researched, :starved?, keyword_init: true)
    AuditResult = Struct.new(:reconciliation, :sample, keyword_init: true)

    # Weight given to the smallest shipped bucket in `audit`'s sample — a
    # small bucket's errors move its own percentage most, so it is
    # oversampled relative to its share of the pool (code review: was an
    # unexplained `sample_size / 5`).
    SMALLEST_BUCKET_WEIGHT = 0.2

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

      AuditResult.new(reconciliation: reconciliation, sample: sample_rows(stamped, sample_size))
    end

    # Two non-overlapping queries, not one query with a coincidence between
    # them (code review: `smallest` and `weighted_count` used to collapse to
    # matching no-ops only by chance when `stamped` is empty; the id
    # exclusion below also stops the two random draws from ever returning
    # the same row twice, which they could when the smallest bucket is a
    # real subset of "every stamped row").
    def self.sample_rows(stamped, sample_size)
      return Painting.none if stamped.empty?

      smallest = stamped.min_by { |_, n| n }.first
      weighted_count = [ (sample_size * SMALLEST_BUCKET_WEIGHT).round, stamped.size ].min

      weighted = Painting.where(tradition: smallest).order("RANDOM()").limit(weighted_count).to_a
      rest = Painting.where.not(tradition: nil).where.not(id: weighted.map(&:id))
        .order("RANDOM()").limit(sample_size - weighted_count)
      weighted + rest
    end
  end
end
