# Seeds the feed with curated public-domain paintings from the Minneapolis
# Institute of Art (metadata: github.com/artsmia/collection, CC0).
#
# Idempotent: records are upserted by mia_id; images are only downloaded for
# paintings that don't have one attached yet.
#
#   bin/rails db:seed              # metadata + full-quality images (resized to 1600px)
#   FAST=1 bin/rails db:seed       # metadata + smaller 800px images (much faster)
#   SKIP_IMAGES=1 bin/rails db:seed  # metadata only (feed falls back to museum CDN)

require "json"
require "open-uri"
require "tempfile"

seed_file = Rails.root.join("db/seeds/mia_paintings.json")
paintings = JSON.parse(seed_file.read)

# Stable shuffle so the feed order is varied but reproducible across reseeds.
shuffled = paintings.shuffle(random: Random.new(1889))

puts "Seeding #{shuffled.size} paintings…"
shuffled.each_with_index do |attrs, i|
  painting = Painting.find_or_initialize_by(mia_id: attrs.fetch("mia_id"))
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
    description: attrs["description"],
    creditline: attrs["creditline"],
    accession_number: attrs["accession_number"],
    image_width: attrs["image_width"],
    image_height: attrs["image_height"],
    image_url_full: attrs["image_url_full"],
    image_url_800: attrs["image_url_800"],
    feed_order: i
  )
  painting.save!
end
puts "Metadata done (#{Painting.count} paintings)."

exit if ENV["SKIP_IMAGES"].present?

MAX_PIXELS = 1600 # longest edge after resize; plenty for a retina feed column

def download(url, max_bytes: 60.megabytes)
  URI.parse(url).open(
    "User-Agent" => "tasteMaker seed (Rails MVP, CC0 images)",
    open_timeout: 15, read_timeout: 180,
    content_length_proc: ->(len) { raise "too large" if len && len > max_bytes }
  )
end

def fetch_and_resize(painting)
  fast = ENV["FAST"].present?
  url = fast ? painting.image_url_800 : painting.image_url_full
  io = begin
    download(url)
  rescue => e
    # Full-size rendition occasionally missing or huge — fall back to the 800px one.
    raise if fast
    warn "  full-size failed for #{painting.mia_id} (#{e.message}), trying 800px"
    download(painting.image_url_800)
  end

  tmp = Tempfile.new([ "mia-#{painting.mia_id}", ".jpg" ])
  tmp.binmode
  IO.copy_stream(io, tmp)
  tmp.flush

  # Downscale with macOS `sips` (no imagemagick/libvips dependency).
  # -Z resizes so the longest edge is MAX_PIXELS, preserving aspect ratio.
  if File.size(tmp.path) > 1.megabyte
    system("sips", "-Z", MAX_PIXELS.to_s, tmp.path, out: File::NULL, err: File::NULL)
  end
  tmp
end

pending = Painting.feed_ordered.reject { |p| p.image.attached? }
puts "Downloading images for #{pending.size} paintings (#{ENV['FAST'].present? ? '800px' : 'full → 1600px'})…"

queue = Queue.new
pending.each { |p| queue << p }
results = Queue.new

workers = 5.times.map do
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
    warn "  ✗ #{painting.mia_id} #{painting.title.truncate(40)}: #{error.message}"
  else
    File.open(tmp.path, "rb") do |f|
      painting.image.attach(io: f, filename: "mia-#{painting.mia_id}.jpg", content_type: "image/jpeg")
    end
    tmp.close!
  end
  done += 1
  print "\r  #{done}/#{pending.size}"
end
workers.each(&:join)
puts

puts "Images attached: #{Painting.joins(:image_attachment).count}/#{Painting.count}"
puts "Failed (will use museum CDN fallback): #{failed.map(&:mia_id).join(', ')}" if failed.any?
