require "test_helper"

# The matcher, which is the part of story 0019 that is easy to get wrong in
# both directions at once.
#
# Too strict and it finds nothing: exact-slug matching finds 0 works for
# Francisco Goya against mirrors that hold 29, because no museum spells him
# "Francisco Goya". Too loose and it lies: substring matching puts "Polidoro da
# Caravaggio" — a different painter — on Caravaggio's page, and "Workshop of
# Titian" under Titian, which is an attribution this pipeline has already
# decided it will not invent (story 0018).
class PoolRecognizableTest < ActiveSupport::TestCase
  LIST = [
    { "rank" => 1, "name" => "Francisco Goya", "aliases" => [ "Goya", "Francisco de Goya",
                                                              "Francisco José de Goya y Lucientes" ] },
    { "rank" => 2, "name" => "Titian", "aliases" => [ "Tiziano Vecellio" ] },
    { "rank" => 3, "name" => "Caravaggio", "aliases" => [ "Michelangelo Merisi" ] },
    { "rank" => 4, "name" => "Claude Monet", "aliases" => [] }
  ].freeze

  def with_list(names = LIST, &) = with_recognizable_names(names, &)

  def candidate(artist, id = rand(1_000_000))
    Pool::Candidate.new(source: "cma", source_id: id, title: "Work #{id}", artist: artist)
  end

  # --- variant_slugs ---------------------------------------------------

  test "a museum parenthetical reaches the artist three ways" do
    assert_equal %w[titian-tiziano-vecellio titian tiziano-vecellio],
      Pool::Recognizable.variant_slugs("Titian (Tiziano Vecellio)")
  end

  test "attribution qualifiers match nothing at all" do
    [ "Workshop of Titian", "Follower of Rembrandt van Rijn", "Imitator of Titian",
      "Circle of Rubens", "After Raphael", "Attributed to Vermeer", "School of Giotto",
      "Manner of Van Dyck", "Studio of Rembrandt", "Copy after Titian", "Possibly by Goya" ].each do |string|
      assert_empty Pool::Recognizable.variant_slugs(string),
        "#{string.inspect} names an attribution, not the artist"
    end
  end

  test "a blank artist yields no slugs" do
    assert_empty Pool::Recognizable.variant_slugs(nil)
    assert_empty Pool::Recognizable.variant_slugs("   ")
  end

  # --- match -----------------------------------------------------------

  test "aliases find the works exact-slug matching misses" do
    with_list do
      works = [ candidate("Francisco José de Goya y Lucientes", 1),
                candidate("Goya (Francisco de Goya y Lucientes)", 2),
                candidate("Goya", 3) ]
      matches, = Pool::Recognizable.match(works)
      goya = matches.find { |m| m.name == "Francisco Goya" }

      assert_equal 3, goya.total, "all three spellings are the same man"
      # The parenthetical is a MATCHING aid, not a rename: the work still files
      # under its own full string, so three spellings are three artist pages.
      # That is the fragmentation this story measures and deliberately does not
      # fix — canonicalising the stored artist string is deferred (plan C4b).
      assert_equal 3, goya.pages, "one man, three artist pages"
      assert_equal %w[francisco-jose-de-goya-y-lucientes goya-francisco-de-goya-y-lucientes goya].to_set,
        goya.by_slug.keys.to_set
    end
  end

  test "matching is exact after reduction, never substring" do
    with_list do
      works = [ candidate("Polidoro da Caravaggio", 1), candidate("Cecco del Caravaggio", 2) ]
      matches, = Pool::Recognizable.match(works)

      assert_empty matches, "different painters whose names contain Caravaggio"
    end
  end

  test "the primary slug is the page holding the most works, and its works come first" do
    with_list do
      works = [ candidate("Goya", 1), candidate("Francisco de Goya", 2),
                candidate("Francisco de Goya", 3), candidate("Francisco de Goya", 4) ]
      matches, = Pool::Recognizable.match(works)
      goya = matches.find { |m| m.name == "Francisco Goya" }

      assert_equal "francisco-de-goya", goya.primary_slug
      assert_equal %w[francisco-de-goya francisco-de-goya francisco-de-goya goya],
        goya.works.map { |c| Painting.artist_slug_for(c.artist) },
        "the deep page is filled first so three works land together, not one on each of three pages"
    end
  end

  test "an alias collision is resolved by rank and reported, never split silently" do
    colliding = [
      { "rank" => 1, "name" => "Claude Monet", "aliases" => [ "Monet" ] },
      { "rank" => 2, "name" => "Berthe Morisot", "aliases" => [ "Monet" ] }
    ]
    with_list(colliding) do
      matches, collisions = Pool::Recognizable.match([ candidate("Monet", 1) ])

      assert_equal [ "Claude Monet" ], matches.map(&:name), "the higher-ranked name keeps the slug"
      assert_equal 1, collisions.size
      assert_equal({ slug: "monet", kept: "Claude Monet", dropped: "Berthe Morisot" }, collisions.first)
    end
  end

  test "a name with no candidate is absent from the matches rather than empty in them" do
    with_list do
      matches, = Pool::Recognizable.match([ candidate("Claude Monet", 1) ])

      assert_equal [ "Claude Monet" ], matches.map(&:name)
    end
  end

  test "matches arrive in list rank order" do
    with_list do
      works = [ candidate("Claude Monet", 1), candidate("Titian", 2), candidate("Goya", 3) ]
      matches, = Pool::Recognizable.match(works)

      assert_equal [ "Francisco Goya", "Titian", "Claude Monet" ], matches.map(&:name)
    end
  end

  # --- loading ---------------------------------------------------------

  test "the committed envelope and a bare array both parse" do
    envelope = Pool::Recognizable.parse('{"generated_on":"2026-08-19","names":[{"rank":1,"name":"Titian"}]}')
    bare     = Pool::Recognizable.parse('[{"rank":1,"name":"Titian"}]')

    assert_equal [ "Titian" ], envelope.map { |e| e["name"] }
    assert_equal envelope, bare
  end

  test "entries with no usable name are dropped rather than occupying a rank" do
    parsed = Pool::Recognizable.parse(
      '[{"rank":1,"name":""},{"rank":2,"name":"   "},{"rank":3},{"rank":4,"name":"Titian"},"nonsense"]'
    )

    assert_equal [ "Titian" ], parsed.map { |e| e["name"] },
      "a blank name builds an empty slug set and would silently match nothing"
  end

  # A broken commit must be loud. Staying quiet here would drop the entire
  # coverage fill while every bar stayed green.
  test "malformed JSON warns and yields no names rather than raising" do
    out = capture_io { assert_empty Pool::Recognizable.parse("{ not json") }

    assert_match(/not valid JSON/, out.join)
  end

  test "a missing list file is a legitimate state, not a crash" do
    without_recognizable_names do
      assert_not Pool::Recognizable.available?
      assert_empty Pool::Recognizable.names
      assert_empty Pool::Recognizable.match([ candidate("Titian", 1) ]).first
    end
  end

  test "the list is read from disk, not from a stub" do
    with_list([ { "rank" => 1, "name" => "Titian", "aliases" => [ "Tiziano Vecellio" ] } ]) do
      assert Pool::Recognizable.available?
      matches, = Pool::Recognizable.match([ candidate("Tiziano Vecellio", 1) ])

      assert_equal [ "Titian" ], matches.map(&:name),
        "the alias reached the matcher through a real file read and parse"
    end
  end
end
