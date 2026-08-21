# Turns a work's TITLE into a genre value for works the museum-tag route
# (story 0022, `Pool::GenreFill`) left nil — story 0025. `Tradition`'s twin:
# a pure function over an ordered pattern table, first match wins, compiled
# once at load.
#
# Two routes, one column, one ladder (plan D1 — stated here because this
# file is where route two lives):
#
#   db/seeds.rb / backfill! per work:
#     genre = manifest genre (museum tag, 0022)  ← tags outrank titles
#             || TitleGenre.infer(title)         ← this file, TITLE-ONLY
#             || nil
#
# TITLE-ONLY is load-bearing, not an abbreviation (plan F2): description
# matching was measured against the real manifest and bought ~31 fills
# (~1.5% coverage) while its first sampled hit was a false positive —
# "Falcon on a Perch", description "this painting may be a portrait of a
# favorite bird". Museum prose hedges ("may be", "reminiscent of") are
# exactly what anchored patterns cannot see coming. One argument, one
# precision surface — do not add a description parameter back without
# re-running that measurement.
#
# Table order is the tie-break (the `GenreTerms`/`Tradition` idiom). Three
# measured traps pin it (plan F3 + implement-time adjudication over the
# manifest's real genre-nil titles — wrong-label-worse-than-no-label,
# 0022's BCE lesson, 0024's Korea-before-Japan lesson):
#
#   Portrait  > Mythological — "Portrait of Diana Mary Barker" is a person
#                              named Diana, not the huntress
#   Mythological > Religious — "Diana or Artemis, Goddess of the Hunt"
#                              fires `goddess`; classical myth, not
#                              religious art
#   Religious > Flowers      — "Lotus Sutra with a Frontispiece" opens with
#                              a flower noun; it is a Buddhist manuscript
#
# Patterns are anchored phrase shapes, not bare nouns — a title that IS the
# thing ("Peonies", "Portrait of a Lady") is the museum saying what the
# picture is; a mid-string noun is not. Every pattern here was promoted
# from the 0008 probe's candidate lists (user-research/scripts/0008/
# pool_coverage.py) and carries a fixture in pool_title_genre_test.rb.
#
# "Flowers" is a stated deviation from 0022's Getty-AAT-terms constraint
# (AAT's concept is "flower pieces") — it is the reader's word ("paintings
# of flowers", 0008 §3.3), logged in the 0025 plan, not a silent widening.
#
# Story 0026 adds three rows, each measured against the mirrors first (plan
# step 3) and each placed ahead of a row it would otherwise be swallowed by:
#
#   Vanitas   > Still Life — "Vanitas Still Life with a Flag..." already
#                             matches `\bstill life\b`; Vanitas is the more
#                             specific reading and the theme this story asks
#                             the pool to name.
#   Icon      > Religious Art — `icon` is already a RELIGIOUS_TERMS word;
#                             "Icon of the Mother of God" is a distinct,
#                             named demand (0008), not generic religious art.
#   Cityscape > Landscape — Landscape's own `\Aview of\b` is a blunt
#                             instrument: measured against the mirrors, most
#                             "View of X" titles are natural or river views
#                             ("View of Cotopaxi", "View of a Lake"), not
#                             cities. Cityscape does NOT reuse that bare
#                             pattern — it anchors on a curated city-name
#                             list (`CITIES`), so a genuine city view
#                             ("View of Genoa", "View of the Town of
#                             Alkmaar") reclassifies while a volcano or lake
#                             stays Landscape. Measured 12 candidates this
#                             way (quota wants 10); the blunt pattern would
#                             have wrongly relabeled all 44.
module Pool
  module TitleGenre
    # Deity/saint/scene names, each reviewed against the manifest's actual
    # genre-nil titles (0008 probe list minus the unanchorable). Names only
    # ever match the TITLE — an artist string never participates (unlike
    # `Tradition`, there is no placeholder-artist edge here).
    RELIGIOUS_TERMS = %w[
      madonna virgin christ crucifixion annunciation adoration
      apostle apostles sutra mandala icon
      buddha bodhisattva bodhisattvas guanyin arhat arhats luohan
      krishna shiva vishnu devi goddess deity deities
    ].freeze

    MYTHOLOGICAL_TERMS = %w[
      venus apollo diana cupid jupiter bacchus nymph nymphs muse muses
      hercules perseus andromeda leda europa danae orpheus
    ].freeze

    # Leading-position flower plurals: the whole title is (or opens with)
    # the flower, so the flower is the subject, not an ornament mid-title.
    FLOWER_NOUNS = %w[
      flowers blossoms peonies peony chrysanthemums irises orchids roses
      tulips lilies hollyhocks poppies hydrangeas wisteria lotus
    ].freeze

    # Major historically-painted cities/towns — a curated allowlist, not a
    # bare noun match, matching the caution `Tradition`'s PLACES table takes
    # (0008 §3.5 named this bucket "Cityscape/veduta"; "veduta" and
    # "cityscape" never appear verbatim in a museum title, so a term match
    # yields zero — this list is the only way in).
    CITIES = %w[
      Rome Florence Venice Genoa Naples Milan Bologna Turin Siena Pisa
      Paris Lyon Marseille Bordeaux Rouen
      London Amsterdam Haarlem Delft Alkmaar Antwerp Bruges Ghent Rotterdam Utrecht Leiden
      Toledo Madrid Seville Lisbon Cordoba Granada
      Vienna Prague Dresden Munich Cologne Emmerich
      Tangier Cairo Constantinople Istanbul
      Beijing Kyoto Edo Osaka Nanjing Suzhou Hangzhou Shanghai Canton Guangzhou
    ].freeze

    TABLE = [
      [ "Portrait", [
        /\bportrait of\b/i,
        /\bself-portrait\b/i,
        /\Aportrait\b/i
      ] ],
      [ "Mythological Art", [
        /\b(#{MYTHOLOGICAL_TERMS.join("|")})\b/i,
        /\bmytholog/i
      ] ],
      [ "Vanitas", [
        /\bvanitas\b/i,
        /\btrompe.l.?oeil\b/i
      ] ],
      [ "Icon", [
        /\Aicon\b/i,
        /\bicon of\b/i
      ] ],
      [ "Religious Art", [
        /\b(#{RELIGIOUS_TERMS.join("|")})\b/i,
        /\bsaints?\b(?!-)/i,
        # Not the historical Rani Lakshmi Bai of Jhansi (audit catch: one
        # 1857-rebellion history painting is not religious art).
        /\blakshmi\b(?!\s+bai)/i,
        /\bholy family\b/i
      ] ],
      [ "Still Life", [
        /\bstill life\b/i
      ] ],
      [ "Flowers", [
        /\bbouquet\b/i,
        /\bvase of (#{FLOWER_NOUNS.join("|")})\b/i,
        /\bbirds? and flowers?\b/i,
        /\A(#{FLOWER_NOUNS.join("|")})\b/i
      ] ],
      [ "Cityscape", [
        # Lookahead, not an anchored "View of <city>": real titles put the
        # city name after an article or a river/quai phrase ("View of the
        # Town of Alkmaar", "View of the Saône ... (Lyon, France)") — the
        # requirement is "starts with View of AND a known city appears
        # anywhere", not "immediately follows".
        /\Aview of\b(?=.*\b(?:#{CITIES.join("|")})\b)/i
      ] ],
      [ "Landscape", [
        /\Alandscape\b/i,
        /\blandscape with\b/i,
        /\Aview of\b/i
      ] ],
      [ "Marine Art", [
        /\bseascape\b/i,
        /\bshipwreck\b/i,
        /\bharbou?r\b/i
      ] ],
      [ "Nude", [
        /\bnude\b/i,
        /\bbathers\b/i
      ] ]
    ].freeze

    # Returns the canonical display value or nil. Title-only, by design —
    # see the header comment before widening the signature.
    def self.infer(title)
      return nil if title.blank?

      TABLE.each do |value, patterns|
        return value if patterns.any? { |re| re.match?(title) }
      end
      nil
    end

    # The committed manifest's tag-route genre per (source, source_id) —
    # route one of the ladder, loaded once. `backfill!` recomputes the FULL
    # ladder for every row (plan D4/F7): a "nil rows only" runner would be
    # one-way — a wrong title-route value shipped to prod could never be
    # retracted by narrowing this table, because reruns would skip it.
    # Recomputing tag || infer for all rows makes narrow-and-rerun a real
    # correction path, and reproduces museum-tag values from the manifest so
    # they stand by construction (story non-goal).
    def self.manifest_genres(manifest_path: Pool::MANIFEST)
      JSON.parse(manifest_path.read).each_with_object({}) do |entry, map|
        map[[ entry["source"], entry["source_id"].to_s ]] = entry["genre"]
      end
    end

    def self.backfill!(manifest_path: Pool::MANIFEST)
      tag_route = manifest_genres(manifest_path: manifest_path)
      updated = 0
      total = 0
      Painting.find_each do |painting|
        total += 1
        value = tag_route[[ painting.source, painting.source_id.to_s ]] || infer(painting.title)
        next if painting.genre == value

        painting.update_column(:genre, value)
        updated += 1
      end
      # Same two-field shape as Tradition's — reused, not redefined (this
      # file's twin, per the header comment).
      Pool::Tradition::BackfillResult.new(updated: updated, total: total)
    end

    # The 0008 §3.6 probe's candidate counts over the genre-nil works —
    # CEILINGS (loose candidate-finder regexes needing adjudication), not
    # expectations, unlike `Tradition::RESEARCH_COUNTS`. The reconciliation
    # therefore flags "well under half the ceiling" only as a look-here,
    # and its real job is catching a bucket that never clears the display
    # floor (plan D5) — the Jain-bucket class of regression.
    PROBE_CEILINGS = {
      "Religious Art" => 302, "Landscape" => 210, "Portrait" => 163,
      "Flowers" => 148, "Still Life" => 27, "Mythological Art" => 24,
      "Marine Art" => 12, "Nude" => 11,
      # Story 0026 — measured against the mirrors at plan step 3, not the
      # 0008 probe (which never scoped these three).
      "Vanitas" => 7, "Icon" => 8, "Cityscape" => 12
    }.freeze

    ReconciliationRow = Struct.new(:value, :shipped, :ceiling, :starved?, :sub_floor?, keyword_init: true)
    AuditResult = Struct.new(:reconciliation, :sample, keyword_init: true)

    # Precision sample is 100 rows, not 50 (plan F5): with a 95% gate, a
    # 50-row sample fails ~46% of the time when true precision is exactly
    # 95% — the gate would be a coin flip at its own bar. Weighted toward
    # the smallest bucket, using `Tradition`'s own weight constant directly
    # (not a second copy of the same number) — a small bucket's errors move
    # its own percentage most, and an unweighted draw would make Marine/
    # Flowers errors structurally invisible under Portrait's bulk.
    SMALLEST_BUCKET_WEIGHT = Pool::Tradition::SMALLEST_BUCKET_WEIGHT

    # Audits TITLE-ROUTE fills only — tag-route values are the museum's own
    # and were 0022's audit's job. A row is title-route when the manifest
    # carries no genre for it but `infer` fires on its title.
    def self.audit(sample_size: 100, manifest_path: Pool::MANIFEST)
      tag_route = manifest_genres(manifest_path: manifest_path)
      title_route = Painting.where.not(genre: nil)
        .select(:id, :source, :source_id, :genre, :title)
        .reject { |p| tag_route[[ p.source, p.source_id.to_s ]].present? }

      # One query for the WHOLE facet's per-value counts (simplify: was one
      # `Painting.where(genre: value).count` per reconciliation row) — the
      # same `facet_counts` every other facet consumer already uses.
      total_counts = Painting.facet_counts(:genre)
      counts = title_route.group_by(&:genre).transform_values(&:size)
      reconciliation = (PROBE_CEILINGS.keys | counts.keys).sort.map do |value|
        shipped = counts[value] || 0
        ceiling = PROBE_CEILINGS[value]
        ReconciliationRow.new(value: value, shipped: shipped, ceiling: ceiling,
          starved?: ceiling && shipped < ceiling * 0.5,
          sub_floor?: total_counts[value].to_i < Painting::MIN_FACET_WORKS)
      end

      AuditResult.new(reconciliation: reconciliation,
        sample: sample_rows(title_route, counts, sample_size))
    end

    def self.sample_rows(title_route, counts, sample_size)
      return title_route.shuffle.first(sample_size) if counts.size < 2

      smallest = counts.min_by { |_, n| n }.first
      small_rows, rest = title_route.partition { |p| p.genre == smallest }
      small_take = [ (sample_size * SMALLEST_BUCKET_WEIGHT).round, small_rows.size ].min
      small_rows.shuffle.first(small_take) + rest.shuffle.first(sample_size - small_take)
    end
    private_class_method :sample_rows
  end
end
