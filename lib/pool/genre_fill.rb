# Story 0022 Release 2. Rewrites `db/seeds/paintings.json` in place, adding
# `genre` to every AIC/MET entry `Pool::GenreTerms` can match. CMA and MIA
# entries are never touched — measured live against both museums' real APIs
# (Release 2 dry-run): neither carries a subject/genre field at all, so
# there is nothing to fetch for them.
#
# Standalone, not `curator.rb` (eng review Issue 1): `curator.rb` SELECTS
# which works make the pool. This ENRICHES metadata on works already
# selected and shipped — a different job.
#
# One targeted per-object API call per already-shipped work, not a
# `pool:mirror` re-run (a build-time correction to the reviewed plan's
# original Step 1 — noted in specs/0022-what-kind-and-when/plan.md
# Deviations). MET's bulk CSV, the mirror's normal MET source, carries no
# tags at all — they exist ONLY on the per-object REST endpoint — so
# widening the mirror adapter would cost thousands of calls against
# candidates that were never selected. This touches exactly the ~403 works
# already in the committed manifest.
#
#   db/seeds/paintings.json (AIC/MET rows only)
#           │
#           ▼
#   one GET per row — AIC api.artic.edu, MET collectionapi.metmuseum.org
#           │
#           ├─ network/parse error on ONE row → logged, skipped, the run
#           │  continues (the critical gap eng review flagged: one bad
#           │  record must not abort the other ~402)
#           │
#           ▼
#   Pool::GenreTerms.match(raw tags) → canonical genre value, or nil
#           │
#           ▼
#   entry["genre"] = value  (nil stays nil — never an empty string)
#           │
#           ▼
#   db/seeds/paintings.json rewritten, same shape, `genre` added
module Pool
  module GenreFill
    AIC_URL = "https://api.artic.edu/api/v1/artworks/%d"
    MET_URL = "https://collectionapi.metmuseum.org/public/collection/v1/objects/%d"

    # The only two sources with a reachable subject/genre field, measured
    # live against every museum's real API (Release 2 dry-run). CMA and MIA
    # are deliberately absent from this list, not filtered out downstream —
    # nothing here ever looks at a CMA/MIA row at all.
    SOURCES = %w[aic met].freeze

    Result = Struct.new(:total, :fetched, :skipped, :matched, :skipped_ids, keyword_init: true)

    def self.run!(manifest_path: Pool::MANIFEST, dry_run: false, sleep_between: 0.1)
      entries = JSON.parse(manifest_path.read)
      targets = entries.select { |e| SOURCES.include?(e["source"]) }

      fetched = 0
      matched = 0
      skipped_ids = []

      targets.each do |entry|
        terms = fetch_terms(entry["source"], entry["source_id"])
        sleep(sleep_between) if sleep_between&.positive?

        if terms.nil?
          skipped_ids << "#{entry['source']}:#{entry['source_id']}"
          next
        end

        fetched += 1
        genre = Pool::GenreTerms.match(terms)
        next unless genre

        entry["genre"] = genre
        matched += 1
      end

      manifest_path.write(JSON.pretty_generate(entries)) unless dry_run

      Result.new(total: targets.size, fetched: fetched, skipped: skipped_ids.size,
        matched: matched, skipped_ids: skipped_ids)
    end

    # nil = the fetch itself failed (network error, malformed response, 404)
    # — the caller skips this one record and moves on. `[]` = fetched fine,
    # genuinely no tags on this object. The two are different facts and the
    # coverage report should not confuse them.
    def self.fetch_terms(source, source_id)
      case source
      when "aic" then fetch_aic(source_id)
      when "met" then fetch_met(source_id)
      end
    rescue StandardError => e
      warn "  ⚠ genre fetch failed for #{source}:#{source_id} (#{e.message}) — skipped, not aborting the run"
      nil
    end

    def self.fetch_aic(id)
      body = Pool::Sources.get_json(format(AIC_URL, id), { "fields" => "id,subject_titles" })
      return nil if body.nil?

      Array(body.dig("data", "subject_titles"))
    end

    def self.fetch_met(id)
      body = Pool::Sources.get_json(format(MET_URL, id))
      return nil if body.nil?

      Array(body["tags"]).filter_map { |tag| tag["term"] }
    end
  end
end
