require "test_helper"

class PaintingTest < ActiveSupport::TestCase
  # Story 0013: object ids collide across museums — the Met and Minneapolis both
  # number a painting 45734 — so identity is the pair, not the id.
  test "two museums may hold works with the same object id" do
    a = Painting.create!(source: "met", source_id: 45_734, title: "A Met painting")
    b = Painting.new(source: "cma", source_id: 45_734, title: "A Cleveland painting")

    assert b.valid?, b.errors.full_messages.to_sentence
    assert_not_equal a.id, b.tap(&:save!).id
  end

  test "the same work cannot be seeded twice" do
    Painting.create!(source: "met", source_id: 1_001, title: "First")
    duplicate = Painting.new(source: "met", source_id: 1_001, title: "Again")

    assert_not duplicate.valid?
    assert_includes duplicate.errors[:source_id], "has already been taken"
  end

  test "a painting from a museum we do not draw from is invalid" do
    assert_not Painting.new(source: "louvre", source_id: 1, title: "Not ours").valid?
  end

  test "each museum names itself, so a day credits the right one" do
    assert_equal "the Cleveland Museum of Art", Painting.new(source: "cma").source_name
    assert_equal "The Metropolitan Museum of Art", Painting.new(source: "met").source_name
    assert_equal "https://www.artic.edu/collection", Painting.new(source: "aic").source_url
  end

  test "the feed anchor is unique across museums and stable across reseeds" do
    met = Painting.new(source: "met", source_id: 45_734)
    mia = Painting.new(source: "mia", source_id: 45_734)

    assert_not_equal met.dom_key, mia.dom_key
    assert_equal "met_45734", met.dom_key
  end

  # Museum HTML on the wall label (bug, 2026-08-15). The page escapes
  # `description`, so every tag that reaches the column is read by a visitor.
  test "museum markup never reaches the column" do
    painting = Painting.create!(source: "cma", source_id: 6_001, title: "Old Pat",
      description: %(a portrait called <em>The Beggar&#39;s Dessert</em> that included a bone))

    assert_equal "a portrait called The Beggar's Dessert that included a bone",
      painting.description
  end

  test "block tags become a space, so the words on either side stay apart" do
    assert_equal "One. Two.", Painting.plain_text("<p>One.</p><p>Two.</p>")
    assert_equal "A line next line third", Painting.plain_text("A line<br>next line<br />third")
    assert_equal "Waldo sold many copies",
      Painting.plain_text(%(<span style="color: rgb(0,0,0)">Waldo sold </span><span>many copies</span>))
  end

  # Minneapolis ships whole Google Docs paste-ups, and one <span style> is
  # longer than the 120 readable characters bar 6 counts.
  test "a paste-up leaves only its words" do
    assert_equal "Titled work", Painting.plain_text(
      %(<b id="docs-internal-guid-478" style="font-weight: normal;">) +
      %(<span style="font-style: italic;">Titled</span></b> work))
  end

  # Entities are the same bug wearing a different coat: ERB escapes the
  # ampersand, so a stored "&quot;" is read as literal &quot; on the page.
  test "entities are decoded, including tags the museum escaped itself" do
    assert_equal %(For "Allegory of Summer," he depicted),
      Painting.plain_text(%(For &quot;Allegory of Summer,&quot; he depicted))
    assert_equal "Rock & Roll", Painting.plain_text("Rock &amp; Roll")
    assert_equal "a slug and grasshopper", Painting.plain_text("a slug&nbsp;and grasshopper")
    # AIC stores this one already escaped — one strip pass leaves it visible.
    assert_equal "this screen shows", Painting.plain_text("&lt;BIG&gt;this screen shows")
  end

  test "flattening is stable, so a reseed over flattened rows changes nothing" do
    once = Painting.plain_text(%(<p>Rock &amp; Roll: <i>a &lt;study&gt;</i></p><p>Two.</p>))

    assert_equal once, Painting.plain_text(once)
  end

  test "text with nothing readable in it becomes nothing, not an empty string" do
    assert_nil Painting.plain_text("<p></p>")
    assert_nil Painting.plain_text(nil)
    assert_nil Painting.create!(source: "met", source_id: 6_002, title: "No text",
      description: "  ").description
  end

  # Third-party copy, so the sanitizer's job is load-bearing, not cosmetic:
  # nothing here is ever marked html_safe, and this pins that it need not be.
  test "script and event handlers do not survive ingest" do
    painting = Painting.create!(source: "mia", source_id: 6_003, title: "Hostile",
      description: %(hi <script>alert(1)</script><img src=x onerror=alert(2)> there))

    assert_equal "hi alert(1) there", painting.description
    assert_no_match(/<|onerror/, painting.description)
  end

  # Story 0018, eng review T3. Every fixture's committed `artist_slug` (set
  # explicitly in the YAML — fixtures bypass `before_save`) must equal what
  # the model's own function computes, or the backfill migration and this
  # file's hand-verified values have silently drifted apart.
  test "every fixture's committed artist_slug matches the model's own function" do
    Painting.find_each do |painting|
      expected = Painting.artist_slug_for(painting.artist)
      message = "#{painting.artist.inspect} (#{painting.title}) has a stale artist_slug fixture value"

      if expected.nil?
        assert_nil painting.artist_slug, message
      else
        assert_equal expected, painting.artist_slug, message
      end
    end
  end

  test "a blank artist resolves to no slug at all" do
    assert_nil Painting.artist_slug_for(nil)
    assert_nil Painting.artist_slug_for("")
    assert_nil Painting.artist_slug_for("   ")
  end

  # E2. Deny-listed by exact string — the pool measurement behind this list.
  # Covers both shapes found in the pool: literal country/culture names, and
  # (regression, found by /qa on 2026-08-19 browsing /feed — "Unidentified
  # artist", 5 works, linked to a live page) museum attribution placeholders
  # like "we don't know who painted this". Same E2 defect; the review's
  # original query only checked the first shape.
  test "a culture string or attribution placeholder in the artist column resolves to no slug" do
    Painting::NOT_AN_ARTIST.each do |culture|
      assert_nil Painting.artist_slug_for(culture), "#{culture.inspect} should not resolve to a slug"
    end

    # And a real, sparse Mughal/Pahari painter is not swept up by a
    # single-word heuristic the deny-list deliberately does not use.
    assert_equal "govardhan", Painting.artist_slug_for("Govardhan")
  end

  # An OCR-shaped artifact that parameterizes to nothing — the case that
  # would otherwise build `artist_path` with an empty segment.
  test "a name that transliterates to nothing resolves to no slug" do
    assert_nil Painting.artist_slug_for("???")
    assert_nil Painting.artist_slug_for("—")
  end

  test "unicode names parameterize correctly, including this pool's actual Hiroshige fixture" do
    assert_equal "utagawa-hiroshige", Painting.artist_slug_for(paintings(:woodcut).artist)
    assert_equal "paul-cezanne", Painting.artist_slug_for("Paul Cézanne")
  end

  # Regression, found by /code-review: `String#parameterize` keeps a literal
  # underscore rather than collapsing it to the separator, so a slug this
  # produced routing could not match — `artist_path` raised
  # `UrlGenerationError`, a 500 on /feed and /days/:date — until the route
  # constraint in config/routes.rb widened to include it.
  test "an underscore in the artist name produces a slug the route can match" do
    slug = Painting.artist_slug_for("Weird_Name")

    assert_equal "weird_name", slug
    assert_nothing_raised { Rails.application.routes.url_helpers.artist_path(slug) }
  end

  # E2, case-insensitive. Regression, found by /code-review: `.include?` was
  # an exact-case match, so a differently-cased duplicate of an already-known
  # placeholder ("CHINA", "unidentified artist") slipped the deny-list.
  test "the deny-list matches regardless of case" do
    assert_nil Painting.artist_slug_for("china")
    assert_nil Painting.artist_slug_for("CHINA")
    assert_nil Painting.artist_slug_for("unidentified artist")
  end

  # E4. Neither count nor "most frequent" would settle the fixture pair —
  # both appear once — so only the accent rule decides.
  test "the canonical artist name prefers the variant with more accented characters" do
    names = [ paintings(:cezanne_plain).artist, paintings(:cezanne_accented).artist ]

    assert_equal "Paul Cézanne", Painting.canonical_artist_name(names)
  end

  # Regression, found by /code-review: accent_count counted ANY non-ASCII
  # character, so a curly quote or em dash — this pool's own museum-paste-up
  # artifacts (see Painting.plain_text above) — could tip the tie-break on
  # punctuation rather than a genuine diacritic.
  test "the accent tie-break ignores punctuation that happens to be non-ASCII" do
    assert_equal 0, Painting.accent_count("O’Keeffe") # curly apostrophe
    assert_equal 0, Painting.accent_count("Jean—Paul") # em dash
    assert_equal 1, Painting.accent_count("Cézanne")
  end

  # Story 0022 Release 1, eng review A1. String order puts "10th century"
  # before "9th century" — the reason `displayed_facet_values` sorts by the
  # ordinal embedded in the label rather than the label itself.
  test "displayed_facet_values orders period numerically, not lexically" do
    Painting::MIN_FACET_WORKS.times { |i| Painting.create!(source: "met", source_id: 7_100 + i, title: "9th #{i}", period: "9th century") }
    Painting::MIN_FACET_WORKS.times { |i| Painting.create!(source: "met", source_id: 7_200 + i, title: "10th #{i}", period: "10th century") }

    assert_equal [ "9th century", "10th century" ], Painting.displayed_facet_values(:period)
  end

  test "displayed_facet_values orders genre alphabetically" do
    Painting::MIN_FACET_WORKS.times { |i| Painting.create!(source: "met", source_id: 7_300 + i, title: "L #{i}", genre: "Landscape") }
    Painting::MIN_FACET_WORKS.times { |i| Painting.create!(source: "met", source_id: 7_400 + i, title: "P #{i}", genre: "Portrait") }

    assert_equal [ "Landscape", "Portrait" ], Painting.displayed_facet_values(:genre)
  end

  # The provisional floor (plan D3): a value under MIN_FACET_WORKS renders
  # no control, but stays a real, resolvable value — facet_counts sees it,
  # only displayed_facet_values hides it.
  test "a value under the floor is counted but not displayed" do
    4.times { |i| Painting.create!(source: "met", source_id: 7_500 + i, title: "Rare #{i}", period: "1st century") }

    assert_equal 4, Painting.facet_counts(:period)["1st century"]
    assert_not_includes Painting.displayed_facet_values(:period), "1st century"
  end

  test "facet_slug and resolve_facet_slug are one reduction function, round-tripped" do
    5.times { |i| Painting.create!(source: "met", source_id: 7_600 + i, title: "19c #{i}", period: "19th century") }

    slug = Painting.facet_slug("19th century")
    assert_equal "19th-century", slug
    assert_equal "19th century", Painting.resolve_facet_slug(:period, slug)
  end

  test "an unknown or blank slug resolves to nil, never a raise" do
    assert_nil Painting.resolve_facet_slug(:period, "not-a-real-century")
    assert_nil Painting.resolve_facet_slug(:period, nil)
    assert_nil Painting.resolve_facet_slug(:period, "")
  end

  # Story 0027. `scoped_to` is the one AND-builder `#index`, `index_for`, and
  # `plate_for` all share — the exact drift class the `@filter_params` bug
  # (`5d90908`) came from, generalized past one hand-copied loop.
  test "scoped_to ANDs every active facet and ignores nil values" do
    match = Painting.create!(source: "met", source_id: 7_700, title: "Match",
      tradition: "Mughal Painting", period: "18th century")
    Painting.create!(source: "met", source_id: 7_701, title: "Wrong period",
      tradition: "Mughal Painting", period: "17th century")
    Painting.create!(source: "met", source_id: 7_702, title: "Wrong tradition",
      tradition: "Rajput Painting", period: "18th century")

    assert_equal [ match ], Painting.scoped_to(tradition: "Mughal Painting", period: "18th century", genre: nil).to_a
  end

  test "scoped_to with no active facets is the whole table" do
    assert_equal Painting.count, Painting.scoped_to(tradition: nil, genre: nil, period: nil).count
  end

  # `index_for` counts each facet within the scope of the OTHER active
  # facets — switching Mughal to Pahari is a replace, not an AND, so
  # tradition's own counts must not be filtered by tradition.
  test "index_for counts a facet within the OTHER active facets' scope, never its own" do
    create_paintings(Painting::MIN_FACET_WORKS, source_id_start: 7_800,
      tradition: "Mughal Painting", period: "18th century")
    create_paintings(Painting::MIN_FACET_WORKS, source_id_start: 7_820,
      tradition: "Rajput Painting", period: "18th century")

    index = Painting.index_for(tradition: "Mughal Painting", genre: nil, period: nil)

    values = index[:tradition].to_h
    assert_equal Painting::MIN_FACET_WORKS, values["Mughal Painting"]
    assert_equal Painting::MIN_FACET_WORKS, values["Rajput Painting"],
      "the active tradition's own row must list every tradition, not just itself"
  end

  test "index_for floors every facet, and keeps the active value even if it is under the floor" do
    create_paintings(Painting::MIN_FACET_WORKS - 1, source_id_start: 7_850, tradition: "Kalighat Painting")
    create_paintings(Painting::MIN_FACET_WORKS, source_id_start: 7_870, tradition: "Korean Painting")

    unfiltered = Painting.index_for(tradition: nil, genre: nil, period: nil)[:tradition].to_h
    assert_not_includes unfiltered.keys, "Kalighat Painting", "a value under the floor should not be offered"

    active_but_starved = Painting.index_for(tradition: "Kalighat Painting", genre: nil, period: nil)[:tradition].to_h
    assert_equal Painting::MIN_FACET_WORKS - 1, active_but_starved["Kalighat Painting"],
      "the active value stays in its own row even under the floor — it is 'here', not an offer"
  end

  test "index_for orders period numerically and every other facet by count, heaviest first" do
    create_paintings(Painting::MIN_FACET_WORKS, source_id_start: 7_900, period: "9th century")
    create_paintings(Painting::MIN_FACET_WORKS, source_id_start: 7_920, period: "10th century")
    create_paintings(Painting::MIN_FACET_WORKS + 3, source_id_start: 7_940, genre: "Landscape")
    create_paintings(Painting::MIN_FACET_WORKS, source_id_start: 7_970, genre: "Portrait")

    index = Painting.index_for(tradition: nil, genre: nil, period: nil)

    assert_equal [ "9th century", "10th century" ], index[:period].map(&:first)
    assert_equal [ "Landscape", "Portrait" ], index[:genre].map(&:first),
      "heaviest first — Landscape (#{Painting::MIN_FACET_WORKS + 3}) before Portrait (#{Painting::MIN_FACET_WORKS})"
  end

  # `plate_for` — story 0027 eng review 2.2: `image.attached?` alone is not
  # `display_image?`, and every fixture in this suite carries a museum URL,
  # not an attachment, so this attaches a real blob to prove the whole path.
  test "plate_for returns the first work in scope with a real picture, skipping one with none" do
    no_picture = Painting.create!(source: "met", source_id: 8_000, title: "No picture",
      tradition: "Mughal Painting", feed_order: 1)
    has_picture = Painting.create!(source: "met", source_id: 8_001, title: "Has picture",
      tradition: "Mughal Painting", feed_order: 2)
    has_picture.image.attach(io: StringIO.new("gif89a"), filename: "plate.gif", content_type: "image/gif")

    plate = Painting.plate_for(:tradition, "Mughal Painting", scope: Painting.all)

    assert_equal has_picture, plate
    assert_not no_picture.display_image?
  end

  test "plate_for is nil when nothing in scope has a picture, not a raise" do
    Painting.create!(source: "met", source_id: 8_010, title: "No picture at all", tradition: "Mughal Painting")

    assert_nil Painting.plate_for(:tradition, "Mughal Painting", scope: Painting.where(image_url_800: nil))
  end

  # Story 0027 design review: the FacetVoice table has to cover every value
  # the vocabulary can produce, not just the values in the committed pool —
  # a value with zero works today still needs a voice the day a reseed
  # gives it one.
  test "FacetVoice has a short and a sentence form for every canonical tradition and genre value" do
    canonical = {
      tradition: Pool::Tradition::VALUES,
      genre: Pool::GenreTerms::DICTIONARY.values.uniq | Pool::TitleGenre::TABLE.map(&:first)
    }

    canonical.each do |facet, values|
      values.each do |value|
        short = Painting::FacetVoice.short(facet, value)
        sentence = Painting::FacetVoice.sentence(facet, value)

        assert short.length <= 9 || short.include?(" "),
          "#{facet} short form #{short.inspect} for #{value.inspect} is over 9 chars with no space to wrap on"
        assert_not_equal value, sentence, "#{facet} #{value.inspect} has no sentence form of its own"
      end
    end
  end

  test "FacetVoice has a short and a sentence form for every valid century" do
    (1..21).each do |n|
      value = "#{n.ordinalize} century"
      assert_match(/\A\d+(st|nd|rd|th)\z/, Painting::FacetVoice.short(:period, value))
      assert_match(/ century\z/, Painting::FacetVoice.sentence(:period, value))
    end
  end

  test "FacetVoice.label_for composes tradition, subject, then century, capitalised once" do
    assert_equal "The full gallery", Painting::FacetVoice.label_for(tradition: nil, genre: nil, period: nil)
    assert_equal "Mughal painting",
      Painting::FacetVoice.label_for(tradition: "Mughal Painting", genre: nil, period: nil)
    assert_equal "Mughal painting, portraits, the eighteenth century",
      Painting::FacetVoice.label_for(tradition: "Mughal Painting", genre: "Portrait", period: "18th century")
  end

  test "FacetVoice falls back to the canonical value for a form it has never heard, rather than raising" do
    assert_equal "A Brand New Tradition", Painting::FacetVoice.short(:tradition, "A Brand New Tradition")
    assert_equal "A Brand New Tradition", Painting::FacetVoice.sentence(:tradition, "A Brand New Tradition")
  end

  test "the gallery credits the museums actually in the pool, heaviest first" do
    Painting.create!(source: "cma", source_id: 5_001, title: "Cleveland one")
    Painting.create!(source: "cma", source_id: 5_002, title: "Cleveland two")
    Painting.create!(source: "met", source_id: 5_003, title: "A Met one")

    names = Painting.represented_sources.map { |m| m[:name] }

    assert_equal "the Minneapolis Institute of Art", names.first,
      "the fixtures are all Minneapolis, so it should still lead"
    assert_includes names, "the Cleveland Museum of Art"
    assert_equal names.uniq, names
  end
end
