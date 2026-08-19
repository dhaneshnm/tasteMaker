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

  desc "Curate the mirror down to the shipped pool (manifest + report)"
  task curate: :environment do
    candidates = Pool::Sources.all.keys.flat_map do |name|
      path = Pool::MIRROR_DIR.join("#{name}.json")
      raise "no mirror for #{name} — run bin/rails pool:mirror first" unless path.exist?

      JSON.parse(path.read).map { |row| Pool::Candidate.new(**row.symbolize_keys) }
    end
    puts "#{candidates.size} candidates from #{Pool::Sources.all.size} museums"

    resolved = 0
    curator = Pool::Curator.new(
      candidates,
      target: (ENV["TARGET"] || Pool::Curator::TARGET).to_i,
      # Every plate is proven to exist before its work can enter the pool.
      # Sampling was not enough: Minneapolis publishes `rights_type: "Public
      # Domain"` and `Rights_Image_Display: "Full"` for works whose image then
      # 403s, and 43 of them reached the seed and stayed blank. The Met's check
      # is its own, because reading the plate's dimensions already proves it.
      resolver: ->(candidate) {
        resolved += 1
        puts "  verifying plates… #{resolved}" if (resolved % 250).zero?

        next Pool::Sources.resolve_met_image(candidate) if candidate.source == "met"

        Pool::Sources.plate_reachable?(candidate.image_url_full)
      }
    )
    selected = curator.curate!
    puts "\nselected #{selected.size}; rejected #{curator.rejected.map { |k, v| "#{k}=#{v}" }.join(' ')}"

    # Prove the plates exist before committing a manifest that points at them.
    print "checking plates… "
    dead = Pool::Sources.check_plates(selected)
    raise "unreachable images:\n  #{dead.join("\n  ")}" if dead.any?

    puts "all sampled plates reachable"

    # The feed order is fixed here, once, over the whole pool — the same stable
    # shuffle db/seeds.rb has always used, moved to where the pool is decided.
    ordered = selected.shuffle(random: Random.new(Pool::Curator::SEED))
    Pool::MANIFEST.write(JSON.pretty_generate(ordered.each_with_index.map { |c, i|
      c.to_manifest.merge("feed_order" => i)
    }))

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
  end
end
