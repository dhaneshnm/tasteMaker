# Story 0025 — the title-route genre fill's backfill and audit. Thin
# printers only (the 0024 tradition.rake shape): the logic lives on
# `Pool::TitleGenre` (`backfill!`, `audit`) so it has Minitest coverage and
# later stories can call the same methods directly.
namespace :genre do
  desc "Backfill paintings.genre on existing rows: manifest tag || title inference (metadata-only, no reseed)"
  task backfill: :environment do
    result = Pool::TitleGenre.backfill!
    puts "Backfilled genre on #{result.updated} of #{result.total} paintings."
  end

  desc "Audit the title-route genre fills: weighted precision sample + reconciliation vs the 0008 probe ceilings"
  task audit: :environment do
    result = Pool::TitleGenre.audit

    puts "== Reconciliation: title-route fills vs 0008 §3.6 probe ceilings (ceilings, not expectations) =="
    result.reconciliation.each do |row|
      flags = []
      flags << "<-- STARVED vs ceiling, investigate" if row.starved?
      flags << "<-- UNDER DISPLAY FLOOR, never renders" if row.sub_floor?
      puts "  #{row.shipped.to_s.rjust(4)} filled  vs  #{(row.ceiling || "?").to_s.rjust(4)} ceiling   #{row.value}  #{flags.join(' ')}"
    end

    puts "\n== Precision sample: #{result.sample.size} title-route rows, weighted toward the smallest bucket =="
    result.sample.each do |p|
      puts "  [#{p.genre}] #{p.title}"
    end
    puts "\nHand-check the sample above. Ship gate: >= 95% correctly attributed (story success signal 2); 93-95% = narrow and rerun."
  end
end
