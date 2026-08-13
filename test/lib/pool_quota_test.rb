require "test_helper"

# R1: the quota table from story 0013 is only a rule if something enforces it.
#
# This reads the committed manifest and recounts every bar from scratch —
# deliberately not by asking Pool::Curator, which is the thing that could be
# wrong. If a future reseed regresses the pool's range, its era spread, or its
# supply of readable museum text, `bin/ci` goes red here.
class PoolQuotaTest < ActiveSupport::TestCase
  POOL = JSON.parse(Pool::MANIFEST.read).freeze

  def share(count) = count.to_f / POOL.size

  test "the manifest is the pool the story asked for" do
    assert_operator POOL.size, :>=, Pool::Curator::TARGET,
      "pool has shrunk below the target"
  end

  test "no museum owns the pool, and at least four are in it" do
    by_source = POOL.group_by { |w| w["source"] }

    assert_operator by_source.size, :>=, 4, "expected at least four museums"
    assert_equal [], by_source.keys - Painting::SOURCES.keys, "unknown source in the manifest"

    biggest, works = by_source.max_by { |_, w| w.size }
    assert_operator share(works.size), :<=, Pool::Curator::MAX_SOURCE_SHARE,
      "#{biggest} holds #{works.size} of #{POOL.size}"
  end

  # Persona 3: "repeated tired old Van Goghs which are already super famous."
  test "no artist holds more than the ceiling" do
    counts = POOL.group_by { |w| w["artist"].to_s.downcase.gsub(/[^a-z0-9]/, "") }
                 .reject { |name, _| name.empty? } # anonymous works are not one artist
                 .transform_values(&:size)
    worst, count = counts.max_by { |_, c| c }

    assert_operator count, :<=, Pool::Curator::MAX_PER_ARTIST,
      "#{worst} appears #{count} times"
  end

  # Persona 3: "almost a complete disregard for works outside of the western canon."
  test "range beyond Europe and North America holds" do
    outside = POOL.count { |w| !Pool::WESTERN.include?(w["region"]) }

    assert_operator share(outside), :>=, Pool::Curator::MIN_NON_WESTERN,
      "only #{outside} of #{POOL.size} are from outside Europe and North America"
  end

  # Persona 5: "all I get are paintings from before 1900AD and I just don't like them."
  test "the pool reaches past 1900" do
    modern = POOL.count { |w| w["year"].to_i >= 1900 }

    assert_operator share(modern), :>=, Pool::Curator::MIN_POST_1900,
      "only #{modern} of #{POOL.size} are dated 1900 or later"
  end

  test "famous works anchor the pool without dominating it" do
    highlights = POOL.count { |w| w["highlight"] }

    assert_operator share(highlights), :<=, Pool::Curator::HIGHLIGHT_SHARE,
      "#{highlights} of #{POOL.size} are museum highlights"
  end

  # Story 0005: a pick with neither a hand-written note nor museum text is
  # invalid. Below this line the pool is a backlog of unpublishable paintings.
  test "most of the pool carries museum text a reader could actually read" do
    readable = POOL.count { |w| w["description"].to_s.strip.length >= Pool::MIN_TEXT }

    assert_operator share(readable), :>=, Pool::Curator::MIN_TEXT_SHARE,
      "only #{readable} of #{POOL.size} carry museum text"
  end

  # Story 0008's fold budget: at the accessibility type cap the day's first
  # written line has to stay on screen, and a museum catalogue entry that names
  # both sides of a folio pushes it 193px off. Enforced here because the pool is
  # what decides which titles ever reach the front door.
  test "no title is long enough to push the day's first line off the screen" do
    overlong = POOL.select { |w| w["title"].to_s.length > Pool::MAX_TITLE }

    assert_empty overlong.first(3).map { |w| w["title"] },
      "#{overlong.size} titles exceed #{Pool::MAX_TITLE} characters"
  end

  # Better bar 7: zoomable, high-quality images. Count is never traded for it.
  test "every plate clears the resolution floor" do
    small = POOL.select { |w| [ w["image_width"].to_i, w["image_height"].to_i ].max < Pool::MIN_EDGE }

    assert_empty small.first(5).map { |w| "#{w['source']}/#{w['source_id']}" },
      "#{small.size} plates are under #{Pool::MIN_EDGE}px"
  end

  test "every work is seedable" do
    POOL.first(50).each do |work|
      assert work["title"].present?, "a work has no title"
      assert work["image_url_full"].present?, "#{work['title']} has no image"
      assert Painting::SOURCES.key?(work["source"]), "#{work['source']} is not a known museum"
    end
    assert_equal POOL.size, POOL.map { |w| [ w["source"], w["source_id"] ] }.uniq.size,
      "the manifest contains the same work twice"
  end

  test "the committed report describes the committed manifest" do
    assert Pool::REPORT.exist?, "pool_report.md is missing — run bin/rails pool:curate"
    assert_includes Pool::REPORT.read, "#{POOL.size} paintings",
      "the report is stale against the manifest"
  end
end
