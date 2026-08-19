require "test_helper"

# The curator's job is to hold the quota table under input that would break it.
# These are the adversarial cases: one artist who painted everything, a museum
# that holds everything, two museums holding the same painting, and a pool that
# simply cannot meet a floor.
class PoolCuratorTest < ActiveSupport::TestCase
  # `plate: false` reproduces the Met, whose CSV carries no image URL and no
  # dimensions — both are only knowable per work, through the resolver.
  def candidate(source:, id:, artist: "Painter #{id}", region: "europe", year: 1850,
                text: true, edge: 3000, highlight: false, title: "Work #{source}#{id}", plate: true)
    Pool::Candidate.new(
      source: source, source_id: id, title: title, artist: artist, region: region,
      year: year, culture: region, dated: year.to_s, highlight: highlight,
      description: text ? "x" * (Pool::MIN_TEXT + 10) : nil,
      image_url_full: plate ? "https://example.test/#{source}/#{id}.jpg" : nil,
      image_width: plate ? edge : 0, image_height: plate ? edge : 0
    )
  end

  # A pool wide enough to satisfy every floor, so each test can break exactly
  # one thing and see the curator react to that alone. The Met's works are mute
  # and plate-less here because that is what the Met actually publishes.
  def wide_pool(per_region: 60)
    regions = %w[europe north_america east_asia south_asia southeast_asia west_asia_islamic africa latin_america]
    id = 0
    regions.flat_map do |region|
      per_region.times.map do
        id += 1
        source = %w[aic cma mia met][id % 4]
        candidate(source: source, id: id, region: region, year: id.even? ? 1750 : 1950,
                  text: source != "met" && id % 10 != 0, plate: source != "met")
      end
    end
  end

  # Stands in for the Met object API: hands back a plate for the works that have
  # one. `missing` names the ids the Met turns out to hold no photograph for.
  def met_resolver(missing: ->(_id) { false })
    lambda do |c|
      next true unless c.source == "met"
      next false if missing.call(c.source_id)

      c.image_url_full = "https://images.metmuseum.org/#{c.source_id}.jpg"
      c.image_width = c.image_height = 4000
      true
    end
  end

  def curate(candidates, target: 200, resolver: met_resolver)
    curator = Pool::Curator.new(candidates, target: target, resolver: resolver)
    curator.curate!
    curator
  end

  test "curates a pool that meets every bar" do
    curator = curate(wide_pool)

    assert_equal 200, curator.selected.size
    curator.bars.each { |name, (have, want, ok)| assert ok, "#{name}: have #{have}, want #{want}" }
  end

  test "the same painting in two museums enters once" do
    shared = [
      candidate(source: "met", id: 1, artist: "Rembrandt", title: "The Night Watch", text: false, edge: 5000),
      candidate(source: "cma", id: 2, artist: "Rembrandt", title: "The night watch!", text: true, edge: 2000)
    ]
    curator = Pool::Curator.new(shared, target: 1)
    kept = curator.dedup(curator.reject_unusable(shared))

    assert_equal 1, kept.size
    assert_equal "cma", kept.first.source, "the copy with museum text should win"
    assert_equal 1, curator.rejected[:duplicate]
  end

  # Persona 3's actual complaint, as an input the curator must survive.
  test "one prolific artist cannot take over the pool" do
    flood = 400.times.map { |i| candidate(source: "aic", id: i, artist: "Vincent van Gogh", region: "europe") }
    curator = curate(flood + wide_pool)

    van_goghs = curator.selected.count { |c| c.artist == "Vincent van Gogh" }
    assert_operator van_goghs, :<=, Pool::Curator::MAX_PER_ARTIST
  end

  test "anonymous works are not treated as one prolific artist" do
    anonymous = 100.times.map { |i| candidate(source: "cma", id: 5_000 + i, artist: "", region: "east_asia") }
    curator = curate(anonymous + wide_pool)

    assert_operator curator.selected.count { |c| c.artist.blank? }, :>, Pool::Curator::MAX_PER_ARTIST,
      "a blank artist name should not collapse every unattributed work into one bucket"
  end

  test "no museum takes more than half the pool" do
    lopsided = 500.times.map { |i| candidate(source: "cma", id: 9_000 + i, region: "east_asia") }
    curator = curate(lopsided + wide_pool)

    assert_operator curator.selected.count { |c| c.source == "cma" }, :<=, 100
  end

  # Meeting the range floor by draining the deepest non-Western collection
  # answers persona 3 with a different monoculture. The first real run came out
  # 46% South Asian this way.
  test "no single tradition takes more than a quarter of the pool" do
    deep = 900.times.map { |i| candidate(source: "cma", id: 30_000 + i, region: "south_asia") }
    curator = curate(deep + wide_pool)

    assert_operator curator.selected.count { |c| c.region == "south_asia" }, :<=, 50
    assert_operator curator.selected.map(&:region).uniq.size, :>=, 6,
      "capping one region should spread the pool, not shrink it"
  end

  test "a pool that cannot meet a floor fails loudly instead of shipping short" do
    all_european = 400.times.map { |i| candidate(source: "aic", id: i, region: "europe") }

    error = assert_raises(Pool::Curator::Unmeetable) do
      curate(all_european)
    end
    assert_match(/outside Europe and North America|only \d+ usable/, error.message)
  end

  test "works below the resolution floor never enter" do
    small = 10.times.map { |i| candidate(source: "cma", id: 7_000 + i, edge: 900) }
    curator = curate(small + wide_pool)

    assert_equal 10, curator.rejected[:too_small]
    assert curator.selected.all? { |c| c.longest_edge >= Pool::MIN_EDGE }
  end

  # The Met publishes no image URL and no dimensions, so a resolver decides per
  # work whether a plate exists. A missing one must cost range, not count.
  test "a Met work with no plate is skipped and its place refilled" do
    # Every fourth work in the fixture pool is a Met work; this makes half of
    # those come back without a photograph.
    missing = ->(id) { id % 8 == 3 }
    curator = curate(wide_pool, resolver: met_resolver(missing: missing))
    selected = curator.selected

    assert_equal 200, selected.size, "a missing plate should cost range, not count"
    assert_operator curator.rejected[:no_plate], :>, 0, "the resolver should have vetoed some works"
    assert selected.none? { |c| c.source == "met" && missing.call(c.source_id) }
    assert selected.all? { |c| c.image_url_full.present? && c.longest_edge >= Pool::MIN_EDGE }
  end

  test "the same candidates always produce the same pool" do
    first = curate(wide_pool).selected.map(&:identity)
    second = curate(wide_pool).selected.map(&:identity)

    assert_equal first, second
  end

  test "museum text shorter than a tombstone does not count as text" do
    assert_not candidate(source: "cma", id: 1, text: false).text?
    brief = Pool::Candidate.new(description: "Oil on canvas, 24 x 36 in. Gift of a donor.")
    assert_not brief.text?, "a provenance fragment is not something to read"
  end

  # --- the recognizable-name seed stage (story 0019) ---------------------
  #
  # The quota table optimises range, era and readable text and is blind to
  # whether anybody has heard of the artist, which is how a 2,000-work pool
  # shipped with no Vermeer and no Hokusai while both sat unused in the
  # mirrors. This stage runs first; these pin that it does, and that running
  # first cannot break a bar.

  NAMES = [ { "rank" => 1, "name" => "Johannes Vermeer" },
            { "rank" => 2, "name" => "Katsushika Hokusai" } ].freeze

  # Mute and small — the back of the queue, where `ordered` puts works nothing
  # else would reach at this target.
  def unloved(artist, id, region: "europe")
    candidate(source: "cma", id: id, artist: artist, region: region,
              text: false, edge: Pool::MIN_EDGE, title: "Late #{id}")
  end

  test "recognizable names are taken before any other stage sees the queue" do
    pool = wide_pool + [ unloved("Johannes Vermeer", 9001),
                         unloved("Katsushika Hokusai", 9002, region: "east_asia") ]

    with_recognizable_names(NAMES) do
      curator = curate(pool)

      assert_equal [ "Johannes Vermeer", "Katsushika Hokusai" ], curator.selected.first(2).map(&:artist),
        "the seed stage did not run first"
      curator.bars.each { |name, (have, want, ok)| assert ok, "#{name}: have #{have}, want #{want}" }
    end
  end

  test "the fill is a substitution, not an expansion — every bar still holds" do
    pool = wide_pool + 12.times.map { |i| unloved("Johannes Vermeer", 9100 + i) }

    with_recognizable_names(NAMES) do
      curator = curate(pool)

      assert_equal 200, curator.selected.size
      curator.bars.each { |name, (have, want, ok)| assert ok, "#{name}: have #{have}, want #{want}" }
    end
  end

  test "depth is capped even when the queue holds far more by that artist" do
    works = 10.times.map { |i| unloved("Johannes Vermeer", 9200 + i) }

    with_recognizable_names(NAMES) do
      curator = Pool::Curator.new(works, target: 200)
      curator.fill_recognizable(works)

      assert_equal Pool::Recognizable::DEPTH, curator.selected.size
      assert_equal({ taken: 3, available: 10, pages: 1, primary_slug: "johannes-vermeer" },
        curator.recognizable["Johannes Vermeer"])
    end
  end

  # The stage calls `take`, so every cap applies to it exactly as to every
  # other stage: the fill can come out INCOMPLETE, never invalid.
  test "room_for? still binds inside the seed stage" do
    works = 10.times.map { |i| unloved("Johannes Vermeer", 9300 + i) }

    with_recognizable_names(NAMES) do
      # Target 8 puts the region cap at 2 (MAX_REGION_SHARE 0.25), below the
      # depth target of 3, so a recognizable work is refused by a quota bar
      # rather than by supply — the case that proves the fill cannot break one.
      curator = Pool::Curator.new(works, target: 8)
      curator.fill_recognizable(works)

      assert_equal 2, curator.selected.size, "the region cap refused the third"
      assert_equal 2, curator.recognizable["Johannes Vermeer"][:taken],
        "an incomplete fill, not a broken bar"
    end
  end

  test "a name the mirror cannot supply is skipped without raising" do
    works = [ unloved("Katsushika Hokusai", 9400, region: "east_asia") ]

    with_recognizable_names(NAMES) do
      curator = Pool::Curator.new(works, target: 200)
      curator.fill_recognizable(works)

      assert_equal 1, curator.selected.size
      assert_not curator.recognizable.key?("Johannes Vermeer"), "no candidate, no row"
      assert_equal 1, curator.recognizable["Katsushika Hokusai"][:taken]
    end
  end

  test "a work whose artist has no reachable page is never seeded" do
    # `artist_slug_for` returns nil for a NOT_AN_ARTIST string, so no artist
    # page exists — filling it could not answer "I looked and found nothing".
    with_recognizable_names([ { "rank" => 1, "name" => "China" } ]) do
      works = [ unloved("China", 9500) ]
      curator = Pool::Curator.new(works, target: 200)
      curator.fill_recognizable(works)

      assert_empty curator.selected
    end
  end

  test "with no list the curator behaves exactly as it did before the story" do
    without_recognizable_names do
      curator = curate(wide_pool)

      assert_equal 200, curator.selected.size
      assert_empty curator.recognizable
      curator.bars.each { |name, (have, want, ok)| assert ok, "#{name}: have #{have}, want #{want}" }
    end
  end
end
