# Seeds the feed from the curated pool — 2,000 public-domain paintings drawn
# from four museums (the Met, the Art Institute of Chicago, Cleveland and
# Minneapolis), selected by the quota table in `lib/pool/curator.rb`.
#
# The manifest and its report are committed. Rebuild them with:
#
#   bin/rails pool:mirror && bin/rails pool:curate
#
# Idempotent: records are upserted by (source, source_id); images are only
# downloaded for paintings that don't have one attached yet, so an interrupted
# run resumes rather than restarting 2,000 downloads.
#
#   bin/rails db:seed              # metadata + full-quality images (resized to 1600px)
#   FAST=1 bin/rails db:seed       # metadata + smaller 800px images (much faster)
#   SKIP_IMAGES=1 bin/rails db:seed  # metadata only (feed falls back to museum CDN)
#   LIMIT=50 bin/rails db:seed     # first 50 of the feed only, for a quick local pass

require "json"
require "open-uri"
require "tempfile"
require "fileutils"

seed_file = Rails.root.join("db/seeds/paintings.json")
paintings = JSON.parse(seed_file.read)
paintings = paintings.first(ENV["LIMIT"].to_i) if ENV["LIMIT"].present?

puts "Seeding #{paintings.size} paintings…"
paintings.each do |attrs|
  painting = Painting.find_or_initialize_by(source: attrs.fetch("source"), source_id: attrs.fetch("source_id"))
  painting.assign_attributes(
    title: attrs["title"],
    artist: attrs["artist"],
    life_date: attrs["life_date"],
    dated: attrs["dated"],
    medium: attrs["medium"],
    dimension: attrs["dimension"],
    country: attrs["country"],
    culture: attrs["culture"],
    department: attrs["department"],
    # Never blank out museum text we already hold: a published day with no
    # hand-written note is reading it, and the model's "something to read"
    # check only runs when the pick is saved, not when the painting changes.
    description: attrs["description"].presence || painting.description,
    creditline: attrs["creditline"],
    accession_number: attrs["accession_number"],
    image_width: attrs["image_width"],
    image_height: attrs["image_height"],
    image_url_full: attrs["image_url_full"],
    image_url_800: attrs["image_url_800"],
    image_license: attrs["image_license"],
    feed_order: attrs["feed_order"]
  )
  painting.save!
end
puts "Metadata done (#{Painting.count} paintings from #{Painting.distinct.count(:source)} museums)."

# Re-curating the pool drops works the quota table no longer wants. Those rows
# would otherwise sit in the feed forever with a stale order. A work that has
# already been published or kept is never deleted — story 0002's archive and
# persona 2's collection are both promises that outlive a reseed.
if ENV["LIMIT"].blank?
  wanted = paintings.map { |a| [ a["source"], a["source_id"] ] }.to_set
  orphans = Painting.all.reject { |p| wanted.include?([ p.source, p.source_id ]) }
  spoken_for = DailyPick.where(painting: orphans).pluck(:painting_id) | Favorite.where(painting: orphans).pluck(:painting_id)
  stale = orphans.reject { |p| spoken_for.include?(p.id) }

  stale.each(&:destroy)
  puts "Pruned #{stale.size} works the pool no longer holds" if stale.any?
  puts "Kept #{spoken_for.size} out-of-pool works that have been published or favorited" if spoken_for.any?

  # A kept work holds the image URL it was seeded with, and museum CDNs retire
  # those. One of these reached the front door reading "This work is resting"
  # instead of showing a painting, so it gets said out loud rather than found
  # by looking at the site.
  blank = Painting.where(id: spoken_for).left_joins(:image_attachment).where(active_storage_attachments: { id: nil })
  warn "  ⚠ #{blank.count} published or kept work(s) have no image and are out of the pool: " \
       "#{blank.map(&:dom_key).join(', ')}" if blank.any?
end

exit if ENV["SKIP_IMAGES"].present?

MAX_PIXELS = 1600 # longest edge after resize; plenty for a retina feed column

# libvips ships in the Docker image; macOS dev boxes have `sips` and usually no
# libvips. Without one of them 2,000 full-size museum plates land on disk at
# several times the ~1 GB decisions/0009 sized the box for, so this refuses to
# run rather than quietly blowing the disk budget.
RESIZER = begin
  require "image_processing/vips"
  :vips
rescue LoadError
  system("which", "sips", out: File::NULL, err: File::NULL) ? :sips : :none
end
raise "no image resizer (libvips or sips) — refusing to seed full-size plates" if RESIZER == :none

def download(url, max_bytes: 60.megabytes)
  URI.parse(url).open(
    "User-Agent" => "Tondo seed (Rails MVP, CC0 images)",
    open_timeout: 15, read_timeout: 180,
    content_length_proc: ->(len) { raise "too large" if len && len > max_bytes }
  )
end

def resize!(path)
  return if File.size(path) <= 1.megabyte

  case RESIZER
  when :vips
    # vips reads lazily, so it must not write over the file it is reading:
    # resize to a new file and move that into place.
    resized = ImageProcessing::Vips.source(path).resize_to_limit(MAX_PIXELS, MAX_PIXELS).call
    FileUtils.mv(resized.path, path)
  when :sips
    # -Z resizes so the longest edge is MAX_PIXELS, preserving aspect ratio.
    system("sips", "-Z", MAX_PIXELS.to_s, path, out: File::NULL, err: File::NULL)
  end
end

def fetch_and_resize(painting)
  fast = ENV["FAST"].present?
  url = fast ? painting.image_url_800 : painting.image_url_full
  io = begin
    download(url)
  rescue => e
    # Full-size rendition occasionally missing or huge — fall back to the 800px one.
    raise if fast

    warn "  full-size failed for #{painting.dom_key} (#{e.message}), trying 800px"
    download(painting.image_url_800)
  end

  tmp = Tempfile.new([ "art-#{painting.dom_key}", ".jpg" ])
  tmp.binmode
  IO.copy_stream(io, tmp)
  tmp.flush
  resize!(tmp.path)
  tmp
end

pending = Painting.feed_ordered.with_attached_image.reject { |p| p.image.attached? }
puts "Downloading images for #{pending.size} paintings (#{ENV['FAST'].present? ? '800px' : "full → #{MAX_PIXELS}px"})…"

queue = Queue.new
pending.each { |p| queue << p }
results = Queue.new

workers = 6.times.map do
  Thread.new do
    while (painting = queue.pop(true) rescue nil)
      begin
        results << [ painting, fetch_and_resize(painting), nil ]
      rescue => e
        results << [ painting, nil, e ]
      end
    end
  end
end

# Attach on the main thread — SQLite writes don't like concurrency.
done = 0
failed = []
pending.size.times do
  painting, tmp, error = results.pop
  if error
    failed << painting
    warn "  ✗ #{painting.dom_key} #{painting.title.truncate(40)}: #{error.message}"
  else
    File.open(tmp.path, "rb") do |f|
      painting.image.attach(io: f, filename: "#{painting.dom_key}.jpg", content_type: "image/jpeg")
    end
    tmp.close!
  end
  done += 1
  print "\r  #{done}/#{pending.size}"
end
workers.each(&:join)
puts

attached = Painting.joins(:image_attachment).count
bytes = ActiveStorage::Blob.sum(:byte_size)
puts "Images attached: #{attached}/#{Painting.count} (#{(bytes / 1024.0**3).round(2)} GB on disk)"
puts "Failed (will use museum CDN fallback): #{failed.map(&:dom_key).join(', ')}" if failed.any?
