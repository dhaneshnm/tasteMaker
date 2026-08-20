# Story 0024 — the tradition facet's backfill and audit. Thin printers only
# (0024 eng review + simplify): the logic lives on `Pool::Tradition`
# (`backfill!`, `audit`) so it has Minitest coverage and story 0026's
# `fill_themes` can call the same methods directly instead of shelling out
# to `rails tradition:audit` from another rake task.
namespace :tradition do
  desc "Backfill paintings.tradition on existing rows (metadata-only, no reseed)"
  task backfill: :environment do
    result = Pool::Tradition.backfill!
    puts "Backfilled tradition on #{result.updated} of #{result.total} paintings."
  end

  desc "Audit the tradition facet: precision sample + reconciliation vs the 0008 research counts"
  task audit: :environment do
    result = Pool::Tradition.audit

    puts "== Reconciliation: stamped counts vs 0008 §3.5 research counts =="
    result.reconciliation.each do |row|
      flag = row.starved? ? "  <-- STARVED, investigate" : ""
      puts "  #{row.shipped.to_s.rjust(4)} shipped  vs  #{(row.researched || "?").to_s.rjust(4)} researched   #{row.value}#{flag}"
    end

    puts "\n== Precision sample: #{result.sample.size} random tradition-stamped rows, weighted toward the smallest bucket =="
    result.sample.each do |p|
      puts "  [#{p.tradition}] #{p.title} — artist=#{p.artist.inspect} culture=#{p.culture.inspect} country=#{p.country.inspect} dept=#{p.department.inspect}"
    end
    puts "\nHand-check the sample above. Ship gate: >= 95% correctly attributed (story success signal 2)."
  end
end
