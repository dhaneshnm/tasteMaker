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
  test "a culture string in the artist column resolves to no slug" do
    Painting::NOT_AN_ARTIST.each do |culture|
      assert_nil Painting.artist_slug_for(culture), "#{culture.inspect} should not resolve to a slug"
    end

    # And a real, sparse Mughal/Pahari painter is not swept up by a
    # single-word heuristic the deny-list deliberately does not use.
    assert_equal "govardhan", Painting.artist_slug_for("Govardhan")
  end

  # Regression: a museum's own "we don't know" marker rendered as a live,
  # tappable artist page — the same E2 defect the review's query missed
  # because it only checked literal country/culture names, not attribution
  # placeholders.
  # Found by /qa on 2026-08-19 — browsing /feed, "Unidentified artist" (5
  # works) linked to a page. Report: .gstack/qa-reports/qa-report-*.md
  test "museum attribution placeholders are not artist pages" do
    [ "Unidentified", "Unknown", "Artist unknown", "Unidentified artist", "Various artists" ].each do |placeholder|
      assert_nil Painting.artist_slug_for(placeholder), "#{placeholder.inspect} should not resolve to a slug"
    end
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

  # E4. Neither count nor "most frequent" would settle the fixture pair —
  # both appear once — so only the accent rule decides.
  test "the canonical artist name prefers the variant with more accented characters" do
    assert_equal "Paul Cézanne", Painting.canonical_artist_name("paul-cezanne")
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
