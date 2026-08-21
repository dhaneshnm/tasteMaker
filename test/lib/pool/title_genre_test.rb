require "test_helper"
require "tempfile"

class Pool::TitleGenreTest < ActiveSupport::TestCase
  def infer(title) = Pool::TitleGenre.infer(title)

  # One fixture per pattern (plan D2) — every regex in TABLE has at least
  # one title here that only IT can claim.
  test "one fixture per Portrait pattern" do
    assert_equal "Portrait", infer("Portrait of a Seated Man")
    assert_equal "Portrait", infer("Self-Portrait with a Straw Hat")
    assert_equal "Portrait", infer("Portrait in Gray")
  end

  test "one fixture per Mythological pattern" do
    assert_equal "Mythological Art", infer("Venus and Adonis")
    assert_equal "Mythological Art", infer("Diana the Huntress")
    assert_equal "Mythological Art", infer("A Mythological Scene")
  end

  test "one fixture per Religious pattern" do
    assert_equal "Religious Art", infer("Madonna and Child")
    assert_equal "Religious Art", infer("The Denial of Saint Peter")
    assert_equal "Religious Art", infer("The Holy Family with Saints Anne and Catherine")
    assert_equal "Religious Art", infer("White-Robed Guanyin")
    assert_equal "Religious Art", infer("Krishna Stealing Curds")
    assert_equal "Religious Art", infer("Mandala of Chakrasamvara and Vajravarahi")
    assert_equal "Religious Art", infer("Diptych icon")
  end

  test "one fixture per Still Life pattern" do
    assert_equal "Still Life", infer("Still Life with Rayfish")
  end

  test "one fixture per Flowers pattern" do
    assert_equal "Flowers", infer("A Bouquet in an Earthenware Jug")
    assert_equal "Flowers", infer("Vase of Flowers on a Ledge")
    assert_equal "Flowers", infer("Birds and Flowers of the Four Seasons")
    assert_equal "Flowers", infer("Peonies and Rocks")
    assert_equal "Flowers", infer("Lotus")
  end

  test "one fixture per Landscape pattern" do
    assert_equal "Landscape", infer("Landscape in Pale Red")
    assert_equal "Landscape", infer("A River Landscape with Fishermen")
    assert_equal "Landscape", infer("View of a Lake")
  end

  test "one fixture per Marine pattern" do
    assert_equal "Marine Art", infer("Quiet Seascape")
    assert_equal "Marine Art", infer("The Shipwreck")
    assert_equal "Marine Art", infer("Gloucester Harbor")
    assert_equal "Marine Art", infer("The Harbour at Night")
  end

  test "one fixture per Nude pattern" do
    assert_equal "Nude", infer("Nude on a Couch")
    assert_equal "Nude", infer("Three Bathers")
  end

  # The three measured order traps (plan F3 + implement-time adjudication) —
  # each of these is a REAL title from the committed manifest that an
  # unordered or reordered table mislabels.
  test "order trap: a person named Diana is a portrait, not mythology" do
    assert_equal "Portrait", infer("Portrait of Diana Mary Barker")
  end

  test "order trap: a classical goddess is mythology even though 'goddess' is a religious term" do
    assert_equal "Mythological Art", infer("Diana or Artemis, Goddess of the Hunt")
  end

  test "order trap: the Lotus Sutra is a Buddhist manuscript, not a flower painting" do
    assert_equal "Religious Art", infer("Lotus Sutra with a Frontispiece")
  end

  # The fourth measured trap, caught by the audit itself (plan Deviations):
  # the historical Rani Lakshmi Bai of the 1857 rebellion is not the deity
  # Lakshmi. `\blakshmi\b(?!\s+bai)` must keep firing on the goddess while
  # staying off the historical figure — pinned so neither direction regresses.
  test "order trap: the historical Rani Lakshmi Bai is not the goddess Lakshmi" do
    assert_nil infer("The Mutiny of the Heroine Rani Lakshmi Bai of Jhansi")
  end

  test "the goddess Lakshmi still fires Religious Art outside the Rani Bai title" do
    assert_equal "Religious Art", infer("Gajalakshmi: Lakshmi with Elephants")
  end

  test "order: Still Life with Flowers is a still life — Still Life precedes Flowers" do
    assert_equal "Still Life", infer("Still Life with Flowers and Salmon")
  end

  # The negative zoo (plan step 2) — anchoring means these stay nil or land
  # on the right side of an ambiguity.
  test "a portrait with a view in it is a portrait — view-of only fires at the start of a title" do
    assert_equal "Portrait", infer("Portrait of a Lady with a View of Delft")
    assert_nil infer("Interior with a View of the Sea")
  end

  test "hyphenated saint place names do not fire Religious" do
    assert_nil infer("Two Poplars in the Alpilles near Saint-Rémy")
    assert_nil infer("Mount Sainte-Victoire")
  end

  test "the St.-abbreviation place-name class stays out — dropped pattern regression" do
    # "St. Anthony Falls" and "St. Paul's Cathedral" are places; the /\bst\. /
    # pattern that would catch real St.-titled devotional works was dropped
    # because this class outnumbered it (implement-time adjudication).
    assert_nil infer("Farnham's Mill at St. Anthony Falls, Minneapolis")
    assert_nil infer("London: St. Paul's Cathedral seen from the Thames")
  end

  test "a mid-title flower noun does not fire Flowers — leading position only" do
    assert_nil infer("Divine couple seated in a lotus blossom")
    assert_nil infer("Girl with Roses")
  end

  test "a landscape containing a lotus pool is a landscape" do
    assert_equal "Landscape", infer("Landscape with a lotus pool, from a Tuti-nama")
  end

  test "verso and study titles ride their subject like any other" do
    assert_equal "Landscape", infer("Landscape Study, verso")
  end

  test "blank, nil and whitespace titles are nil" do
    assert_nil infer(nil)
    assert_nil infer("")
    assert_nil infer("   ")
  end

  test "a non-English title is nil — the language-skew risk, pinned honestly" do
    assert_nil infer("山水図")
    assert_nil infer("花鳥図屏風")
  end

  test "matching is case-insensitive" do
    assert_equal "Portrait", infer("PORTRAIT OF A MAN")
    assert_equal "Still Life", infer("still life with fruit")
  end

  test "culled buckets still stay nil: Genre Scene and Animal are museum-tag-only" do
    assert_nil infer("The Bohemian Peasant Girl"), "Genre Scene culled — 2 works can never clear the display floor"
    assert_nil infer("Two Tigers"), "Animal stays museum-tag-only this story (plan D2)"
  end

  test "a generic street scene is not a cityscape — no known city name, no 'view of' prefix either" do
    assert_nil infer("Street Scene in Paris"),
      "Cityscape (story 0026) is anchored on 'View of <city>', not a bare street-scene phrase"
  end

  # ---- story 0026 additions -------------------------------------------------

  test "one fixture per Vanitas pattern" do
    assert_equal "Vanitas", infer("Vanitas Still Life")
    assert_equal "Vanitas", infer("Trompe-l'Oeil Still Life with a Flower Garland and a Curtain")
    assert_equal "Vanitas", infer("Trompe l'oeil with Palettes and Miniature")
  end

  test "order: Vanitas precedes Still Life — 'Vanitas Still Life' is Vanitas, not Still Life" do
    assert_equal "Vanitas", infer("A Vanitas Still Life with a Flag, Candlestick, and Hourglass")
  end

  test "one fixture per Icon pattern" do
    assert_equal "Icon", infer("Icon with the Virgin and Child")
    assert_equal "Icon", infer("Icon of the Mother of God and Infant Christ (Virgin Eleousa)")
  end

  test "order: Icon precedes Religious Art — 'icon' is already a RELIGIOUS_TERMS word" do
    assert_equal "Icon", infer("Icon of the New Testament Trinity")
  end

  test "a mid-title icon does not fire the narrower Icon row, only Religious Art's bare term" do
    assert_equal "Religious Art", infer("Diptych icon")
  end

  test "one fixture per Cityscape pattern — a known city, not a bare 'View of'" do
    assert_equal "Cityscape", infer("View of Genoa")
    assert_equal "Cityscape", infer("View of Rome from Monte Pincio")
    assert_equal "Cityscape", infer("View of the Town of Alkmaar")
    assert_equal "Cityscape", infer("View of the Saône and the Château Pierre-Scize (Lyon, France)")
  end

  test "order: Cityscape precedes Landscape, but only for a known city — a natural view stays Landscape" do
    assert_equal "Cityscape", infer("View of Florence")
    assert_equal "Landscape", infer("View of Cotopaxi"), "a volcano is not a city — Landscape's own catch-all"
    assert_equal "Landscape", infer("View of a Lake")
    assert_equal "Landscape", infer("View of Niagara Falls")
  end

  # ---- backfill! (plan D4/F7) ----------------------------------------------

  def tmp_manifest(entries)
    file = Tempfile.new([ "manifest", ".json" ])
    file.write(JSON.generate(entries))
    file.flush
    Pathname.new(file.path)
  end

  def create_painting(source_id, title:, genre: nil)
    Painting.create!(source: "met", source_id: source_id, title: title,
      image_url_800: paintings(:woodcut).image_url_800, genre: genre)
  end

  test "backfill! recomputes the full ladder: tag route wins, title route fills, unmatched stays nil" do
    tagged = create_painting(991_001, title: "Portrait of Nobody")
    title_route = create_painting(991_002, title: "Quiet Seascape")
    unmatched = create_painting(991_003, title: "Composition VII")

    manifest = tmp_manifest([
      { source: "met", source_id: 991_001, genre: "Landscape" } # museum tag disagrees with the title — tag wins
    ])
    Pool::TitleGenre.backfill!(manifest_path: manifest)

    assert_equal "Landscape", tagged.reload.genre, "manifest tag outranks the title match"
    assert_equal "Marine Art", title_route.reload.genre
    assert_nil unmatched.reload.genre
  end

  test "backfill! retracts a stale title-route value after the dictionary narrows — the correction path" do
    stale = create_painting(991_004, title: "Composition VII", genre: "Genre Scene")

    Pool::TitleGenre.backfill!(manifest_path: tmp_manifest([]))

    assert_nil stale.reload.genre, "a value neither route explains any more must be retractable by rerunning"
  end

  # ---- audit (plan D5/F5/F6) -----------------------------------------------

  test "audit samples only title-route rows and reconciles against the probe ceilings" do
    tag_row = create_painting(991_100, title: "Tagged by museum", genre: "Portrait")
    title_rows = 3.times.map { |i| create_painting(991_101 + i, title: "Quiet Seascape #{i}", genre: "Marine Art") }
    create_painting(991_104, title: "Peonies", genre: "Flowers")

    manifest = tmp_manifest([ { source: "met", source_id: 991_100, genre: "Portrait" } ])
    result = Pool::TitleGenre.audit(sample_size: 10, manifest_path: manifest)

    refute_includes result.sample.map(&:id), tag_row.id, "tag-route rows are the museum's own, not audited here"
    assert_includes result.sample.map(&:id), title_rows.first.id

    marine = result.reconciliation.find { |row| row.value == "Marine Art" }
    assert_equal 3, marine.shipped
    assert_equal 12, marine.ceiling
    assert marine.sub_floor?, "3 Marine works sit under MIN_FACET_WORKS and must be flagged as never rendering"
  end

  test "audit's weighted sample surfaces the smallest bucket" do
    9.times { |i| create_painting(991_200 + i, title: "Portrait of Number #{i}", genre: "Portrait") }
    create_painting(991_210, title: "Lone Bouquet", genre: "Flowers")

    result = Pool::TitleGenre.audit(sample_size: 5, manifest_path: tmp_manifest([]))

    assert_includes result.sample.map(&:title), "Lone Bouquet",
      "the sole member of the smallest bucket must appear in a weighted sample"
  end
end
