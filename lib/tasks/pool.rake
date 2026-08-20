# Story 0013 — the pool grows from 110 works in one museum to 2,000 across four.
#
#   bin/rails pool:mirror   metadata for every open-licence painting (~15K), cached in tmp/
#   bin/rails pool:curate   applies the quota table, writes the manifest and the report
#   bin/rails db:seed       downloads image bytes for the 2,000 selected, resumably
#
# Metadata is mirrored wide and cheap; image bytes are fetched narrow and slow.
# That split is why 2,000 images cost ~1 GB instead of the 290 GB a full mirror
# of all four collections would take.
namespace :pool do
  desc "Mirror painting metadata from all four museums into tmp/pool"
  task mirror: :environment do
    Pool::MIRROR_DIR.mkpath
    only = ENV["SOURCE"].presence

    Pool::Sources.all.each do |name, fetcher|
      next if only && only != name

      path = Pool::MIRROR_DIR.join("#{name}.json")
      started = Time.current
      print "#{name}: fetching… "
      candidates = fetcher.call
      path.write(JSON.generate(candidates.map(&:to_manifest)))
      puts "#{candidates.size} paintings in #{(Time.current - started).round}s → #{path.basename}"
    end
  end

  # A module, not bare `def`s. `def` inside a `namespace` block defines private
  # instance methods on Object — visible to every other rake task and every
  # object in the process once this file loads, and `mirror_candidates` is a
  # generic enough name to collide (code review finding 8).
  module Tasks
    module_function

  # Both `curate` and `coverage` read the same four files; keeping one loader
  # means the coverage report can never be measured against a different mirror
  # than the curation it is judging.
  def mirror_candidates
    Pool::Sources.all.keys.flat_map do |name|
      path = Pool::MIRROR_DIR.join("#{name}.json")
      raise "no mirror for #{name} — run bin/rails pool:mirror first" unless path.exist?

      JSON.parse(path.read).map { |row| Pool::Candidate.new(**row.symbolize_keys) }
    end
  end

  # Every 0007 row carries a `rights` value. Without it a name absent from the
  # mirrors cannot be told from a name in copyright — all four sources are
  # already public-domain-filtered at fetch, so mirror-absence alone
  # discriminates nothing.
  def abort_on_missing_rights
    missing = Pool::Recognizable.rows_missing_rights
    return if missing.empty?

    abort "#{missing.size} recognizable name(s) carry no `rights` (#{Pool::Recognizable::RIGHTS.join('/')}): " \
          "#{missing.first(8).map { |e| e['name'] }.join(', ')}#{'…' if missing.size > 8}"
  end

  # Story 0026. Candidates built from the PREVIOUS committed manifest's own
  # rows — never a mirror lookup, so mirror absence/drift can't touch a
  # pinned work (eng review + outside voice). Returns `[raw_rows,
  # candidates]`, the manifest parsed exactly once: `raw_rows` carries
  # `genre`/`feed_order` (not `Candidate` fields) for the verbatim write-back
  # in `curate`, `candidates` is what `Curator` pins. `[[], []]` on a
  # first-ever curation, when no manifest is committed yet.
  def pinned_candidates
    return [ [], [] ] unless Pool::MANIFEST.exist?

    raw_rows = JSON.parse(Pool::MANIFEST.read)
    candidates = raw_rows.map { |row| Pool::Candidate.new(**row.symbolize_keys.slice(*Pool::FIELDS)) }
    [ raw_rows, candidates ]
  end
  end

  desc "Curate the mirror down to the shipped pool (manifest + report)"
  task curate: :environment do
    candidates = Tasks.mirror_candidates
    puts "#{candidates.size} candidates from #{Pool::Sources.all.size} museums"
    if Pool::Recognizable.available?
      Tasks.abort_on_missing_rights
      puts "#{Pool::Recognizable.names.size} recognizable names loaded (story 0019)"
    else
      warn "  ⚠ no recognizable-name list at #{Pool::Recognizable::LIST.relative_path_from(Rails.root)} — " \
           "curating WITHOUT the coverage fill. See specs/0019-the-coverage-fill/plan.md step 1."
    end

    old_manifest_rows, pinned = Tasks.pinned_candidates
    puts "#{pinned.size} pinned works from the committed manifest (story 0026, Jordan's contract)" if pinned.any?

    resolved = 0
    curator = Pool::Curator.new(
      candidates,
      target: (ENV["TARGET"] || Pool::Curator::TARGET).to_i,
      pinned: pinned,
      # Every plate is proven to exist before its work can enter the pool.
      # Sampling was not enough: Minneapolis publishes `rights_type: "Public
      # Domain"` and `Rights_Image_Display: "Full"` for works whose image then
      # 403s, and 43 of them reached the seed and stayed blank. The Met's check
      # is its own, because reading the plate's dimensions already proves it.
      # Never called for pinned candidates (`Curator#take(resolve: false)`) —
      # their plates are already cached locally and on the prod volume.
      resolver: ->(candidate) {
        resolved += 1
        puts "  verifying plates… #{resolved}" if (resolved % 250).zero?

        next Pool::Sources.resolve_met_image(candidate) if candidate.source == "met"

        Pool::Sources.plate_reachable?(candidate.image_url_full)
      }
    )
    selected = curator.curate!
    puts "\nselected #{selected.size}; rejected #{curator.rejected.map { |k, v| "#{k}=#{v}" }.join(' ')}"

    # Story 0026: only the NEW candidates' plates are re-checked here — a
    # pinned identity's plate already lives in Active Storage, so an
    # upstream re-check buys nothing and costs ~2,000 requests.
    new_candidates = selected.reject { |c| curator.pinned?(c) }

    print "checking plates on #{new_candidates.size} new work(s)… "
    dead = Pool::Sources.check_plates(new_candidates)
    raise "unreachable images:\n  #{dead.join("\n  ")}" if dead.any?

    puts "all sampled plates reachable"

    # Story 0026: pinned rows are written back VERBATIM from the OLD
    # manifest's own dicts — never through `Candidate#to_manifest`, which
    # would drop `genre` (`Pool::GenreFill`, story 0022) and `feed_order`
    # both, since neither is a `Candidate` field. New works append after,
    # feed_order continuing from where the pinned block ends, shuffled only
    # among themselves — every bookmarked `/feed` offset inside the pinned
    # range survives untouched, and appending (not interleaving) is the one
    # scheme where prod's existing 0..N-1 numbering can never collide with
    # the backfill (eng review + outside voice, plan step 2).
    ordered_new = new_candidates.shuffle(random: Random.new(Pool::Curator::SEED))
    new_rows = ordered_new.each_with_index.map { |c, i|
      c.to_manifest.merge("feed_order" => old_manifest_rows.size + i)
    }
    Pool::MANIFEST.write(JSON.pretty_generate(old_manifest_rows + new_rows))

    report = Pool::Report.new(curator).to_markdown
    Pool::REPORT.write(report)
    puts "\n#{report}"
    puts "manifest: db/seeds/paintings.json (#{(Pool::MANIFEST.size / 1024.0 / 1024).round(1)} MB)"
  end

  desc "Print the pool report for the committed manifest"
  task report: :environment do
    puts Pool::REPORT.read
    puts
    puts Pool::Report.artist_slug_section
    puts
    puts Pool::Report.genre_section
  end

  # Story 0022 Release 2. One targeted API call per AIC/MET work already in
  # the committed manifest — see lib/pool/genre_fill.rb for why this is not
  # a pool:mirror re-run. DRY_RUN=1 fetches and reports without writing.
  desc "Backfill genre from AIC/MET native tags into the committed manifest"
  task genre_fill: :environment do
    result = Pool::GenreFill.run!(dry_run: ENV["DRY_RUN"].present?)
    puts "AIC/MET works considered: #{result.total}"
    puts "fetched successfully: #{result.fetched}"
    puts "skipped (fetch failed): #{result.skipped}"
    puts "  #{result.skipped_ids.join(', ')}" if result.skipped_ids.any?
    puts "matched a genre: #{result.matched}"
    puts ENV["DRY_RUN"].present? ? "DRY_RUN — manifest not written" : "db/seeds/paintings.json updated"
  end

  # Story 0019. Run it BEFORE re-curating to get the baseline, and after to get
  # the receipt — the story's first success signal is the difference between
  # the two, so both have to be producible on demand from committed files.
  desc "Report recognizable-name coverage of the committed manifest (story 0019)"
  task coverage: :environment do
    unless Pool::Recognizable.available?
      abort "no recognizable-name list — see specs/0019-the-coverage-fill/plan.md step 1"
    end
    Tasks.abort_on_missing_rights

    raw = Tasks.mirror_candidates
    scratch = Pool::Curator.new(raw)
    usable = scratch.dedup(scratch.reject_unusable(raw))

    coverage = Pool::Coverage.new(
      manifest: JSON.parse(Pool::MANIFEST.read), usable:, raw:
    )
    puts coverage.to_markdown
  end
end
