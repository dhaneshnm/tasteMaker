# Story 0024 — the tradition facet's backfill and audit. Two separate
# concerns, one file: `backfill` writes the column on existing rows after a
# metadata-only migration (no reseed, no plate re-download); `audit` is the
# facet's enforcement, run by hand after a curation and reused unchanged by
# story 0026's `fill_themes` against the expanded pool.
namespace :tradition do
  desc "Backfill paintings.tradition on existing rows (metadata-only, no reseed)"
  task backfill: :environment do
    updated = 0
    Painting.find_each do |painting|
      value = Pool::Tradition.from_strings(
        culture: painting.culture, country: painting.country,
        department: painting.department, artist: painting.artist
      )
      next if painting.tradition == value

      painting.update_column(:tradition, value)
      updated += 1
    end
    puts "Backfilled tradition on #{updated} of #{Painting.count} paintings."
  end

  desc "Audit the tradition facet: precision sample + reconciliation vs the 0008 research counts"
  task audit: :environment do
    # 0008 §3.5's probe counts — the sizing instrument the shipping table's
    # stricter matching is measured against. Deliberate departures (Rajput's
    # dropped `rajasthan`) are named in the plan's Deviations, not repeated
    # here as a second source of truth.
    RESEARCH_COUNTS = {
      "Japanese Painting" => 276, "Chinese Painting" => 180, "Mughal Painting" => 102,
      "Rajput Painting" => 102, "Pahari Painting" => 84, "Jain Manuscript Painting" => 52,
      "Kalighat Painting" => 44, "Korean Painting" => 32, "Tibetan & Nepalese Painting" => 24,
      "Persian & Islamic Painting" => 19
    }.freeze

    puts "== Reconciliation: stamped counts vs 0008 §3.5 research counts =="
    stamped = Painting.where.not(tradition: nil).group(:tradition).count
    (RESEARCH_COUNTS.keys | stamped.keys).sort.each do |value|
      shipped = stamped[value] || 0
      researched = RESEARCH_COUNTS[value]
      flag = researched && shipped < researched * 0.5 ? "  <-- STARVED, investigate" : ""
      puts "  #{shipped.to_s.rjust(4)} shipped  vs  #{(researched || "?").to_s.rjust(4)} researched   #{value}#{flag}"
    end

    puts "\n== Precision sample: 50 random tradition-stamped rows, weighted toward the smallest bucket =="
    smallest = stamped.min_by { |_, n| n }&.first
    weighted_sample = Painting.where(tradition: smallest).order("RANDOM()").limit(10) +
      Painting.where.not(tradition: nil).order("RANDOM()").limit(40)
    weighted_sample.each do |p|
      puts "  [#{p.tradition}] #{p.title} — artist=#{p.artist.inspect} culture=#{p.culture.inspect} country=#{p.country.inspect} dept=#{p.department.inspect}"
    end
    puts "\nHand-check the sample above. Ship gate: >= 95% correctly attributed (story success signal 2)."
  end
end
