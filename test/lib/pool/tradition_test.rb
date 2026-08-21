require "test_helper"

class Pool::TraditionTest < ActiveSupport::TestCase
  def match(culture: nil, country: nil, department: nil, artist: nil, medium: nil)
    Pool::Tradition.from_strings(culture: culture, country: country, department: department,
      artist: artist, medium: medium)
  end

  test "one fixture per canonical value" do
    assert_equal "Mughal Painting", match(culture: "Mughal India, court of Akbar (reigned 1556–1605)")
    assert_equal "Pahari Painting", match(culture: "Northern India, Pahari kingdoms")
    assert_equal "Rajput Painting", match(culture: "Northwestern India, Rajasthan, Rajput Kingdom of Mewar")
    assert_equal "Kalighat Painting", match(culture: "Eastern India, Bengal, Kolkata, Kalighat")
    assert_equal "Jain Manuscript Painting", match(culture: "Western India, Gujarat")
    assert_equal "Korean Painting", match(culture: "Korea, Joseon dynasty (1392–1910)")
    assert_equal "Chinese Painting", match(country: "China")
    assert_equal "Japanese Painting", match(country: "Japan")
    assert_equal "Persian & Islamic Painting", match(culture: "Iran")
    assert_equal "Tibetan & Nepalese Painting", match(culture: "Tibet")
  end

  test "precedence: Mughal fires before Persian even when both patterns are present" do
    assert_equal "Mughal Painting", match(culture: "Mughal India, court of Akbar (reigned 1556–1605)")
  end

  test "precedence: Korea fires before Japan on the verbatim colonial-era culture string" do
    assert_equal "Korean Painting",
      match(culture: "Korea, Japanese colonial period (1910−1945)")
    assert_equal "Korean Painting",
      match(culture: "Korea, Joseon dynasty (1392−1910) or Japanese colonial period (1910−1945)")
  end

  test "nil on blank" do
    assert_nil match
    assert_nil match(culture: "", country: "", department: "")
  end

  test "nil on unmatched" do
    assert_nil match(culture: "France", country: "France")
    assert_nil match(culture: "United States")
  end

  test "the dropped-pattern regression: bare Rajasthan does not fire the Rajput row" do
    assert_nil match(culture: "Rajasthan, 19th century")
  end

  test "word-boundary negatives: substrings inside unrelated words do not fire" do
    assert_nil match(country: "Indochina"), "china substring inside Indochina must not fire Chinese Painting"
    assert_nil match(culture: "Normandie, France"), "mandi substring inside Normandie must not fire Pahari Painting"
  end

  test "matching is case-insensitive" do
    assert_equal "Chinese Painting", match(country: "CHINA")
    assert_equal "Mughal Painting", match(culture: "mughal india")
  end

  test "placeholder-artist union: a NOT_AN_ARTIST placeholder string with blank culture still matches" do
    assert_equal "Rajput Painting", match(artist: "Mewar school")
    assert_equal "Mughal Painting", match(artist: "Painter: Mughal school")
    assert_equal "Persian & Islamic Painting", match(artist: "Persia (Iran)")
  end

  test "a NOT_AN_ARTIST string that happens to share a table term with no deny-list match stays nil" do
    # "Baysunghur school" is a real (if uncredited) painter attribution in
    # this pool, NOT in Painting::NOT_AN_ARTIST — artist_slug_for returns a
    # real slug for it, so it never enters the tradition match as culture
    # data, even though "baysunghur" is a Persian & Islamic table term.
    assert_nil match(artist: "Baysunghur school")
  end

  test "a real artist's name never participates in the match, even if it contains a term" do
    assert_nil match(artist: "Kota Ezawa")
  end

  test "department participates in the match when culture and country are blank" do
    assert_equal "Persian & Islamic Painting", match(department: "Islamic Art")
  end

  test "PATTERNS precompiles TABLE into whole-word case-insensitive regexes, same shape and order" do
    assert_equal Pool::Tradition::TABLE.map(&:first), Pool::Tradition::PATTERNS.map(&:first)
    Pool::Tradition::PATTERNS.each do |_, patterns|
      assert patterns.all? { |re| re.is_a?(Regexp) && re.casefold? }
    end
  end

  # Story 0024 simplify: backfill!/audit moved off the rake task onto the
  # module (eng review altitude finding) so they get Minitest coverage
  # instead of only being exercisable by shelling out.
  test "backfill! stamps tradition on existing rows without touching an already-correct value" do
    mughal = Painting.create!(source: "met", source_id: 990_001, title: "Test Mughal",
      image_url_800: paintings(:woodcut).image_url_800, culture: "Mughal India, court of Akbar")
    already_correct = Painting.create!(source: "met", source_id: 990_002, title: "Already stamped",
      image_url_800: paintings(:woodcut).image_url_800, culture: "China", tradition: "Chinese Painting")
    unrelated = Painting.create!(source: "met", source_id: 990_003, title: "No tradition",
      image_url_800: paintings(:woodcut).image_url_800, culture: "France")

    result = Pool::Tradition.backfill!

    assert_equal "Mughal Painting", mughal.reload.tradition
    assert_nil unrelated.reload.tradition
    assert_equal "Chinese Painting", already_correct.reload.tradition
    assert_operator result.updated, :>=, 1, "at least the freshly-stamped Mughal row should count as updated"
    assert_equal Painting.count, result.total
  end

  test "backfill! clears a stale tradition when the underlying culture no longer matches" do
    stale = Painting.create!(source: "met", source_id: 990_004, title: "Stale stamp",
      image_url_800: paintings(:woodcut).image_url_800, culture: "France", tradition: "Chinese Painting")

    Pool::Tradition.backfill!

    assert_nil stale.reload.tradition
  end

  test "audit reconciles shipped counts against RESEARCH_COUNTS and flags a starved bucket" do
    4.times do |i|
      Painting.create!(source: "met", source_id: 990_100 + i, title: "Sparse Mughal #{i}",
        image_url_800: paintings(:woodcut).image_url_800, tradition: "Mughal Painting")
    end

    result = Pool::Tradition.audit

    mughal_row = result.reconciliation.find { |row| row.value == "Mughal Painting" }
    assert_equal 4, mughal_row.shipped
    assert mughal_row.starved?, "4 shipped against a researched count of 102 is well under 50%"
  end

  test "audit's sample only returns tradition-stamped rows, weighted toward the smallest bucket" do
    Painting.create!(source: "met", source_id: 990_200, title: "Only Korean",
      image_url_800: paintings(:woodcut).image_url_800, tradition: "Korean Painting")
    Painting.create!(source: "met", source_id: 990_201, title: "No tradition here",
      image_url_800: paintings(:woodcut).image_url_800)

    result = Pool::Tradition.audit(sample_size: 10)

    assert result.sample.all? { |p| p.tradition.present? }
    assert_includes result.sample.map(&:title), "Only Korean",
      "the sole member of the smallest bucket must appear in a weighted sample"
  end

  # --- story 0026 additions -----------------------------------------------

  test "Madhubani Painting matches culture strings" do
    assert_equal "Madhubani Painting", match(culture: "Eastern India, Bihar, Mithila region")
    assert_equal "Madhubani Painting",
      match(culture: "Eastern India, Bihar State, Mithila or Madhubani School, 20th century")
  end

  test "precedence: Madhubani fires before Tibetan & Nepalese on a border-adjacent culture string" do
    assert_equal "Madhubani Painting", match(culture: "Mithila region, near Nepal border")
  end

  test "Ukiyo-e Painting matches an allowlisted artist on a hand-painted hanging scroll, never a print" do
    assert_equal "Ukiyo-e Painting",
      match(artist: "Katsushika Hokusai", medium: "Hanging scroll; ink and color on silk")
    assert_equal "Ukiyo-e Painting",
      match(artist: "Utagawa Toyohiro", medium: "Hanging scroll (nikuhitsu), ink and color on paper")
    assert_nil match(artist: "Katsushika Hokusai", medium: "Woodblock print; ink and color on paper"),
      "a woodblock print is ukiyo-e in the broad sense but not this pool's genuine-painting facet"
    assert_nil match(artist: "Katsushika Hokusai", medium: "Ink on paper; woodblock-printed books")
  end

  test "Ukiyo-e Painting requires both the allowlisted artist AND a painting-format medium" do
    assert_nil match(artist: "Katsushika Hokusai", medium: nil), "no medium, no match"
    assert_nil match(artist: "Rembrandt van Rijn", medium: "Hanging scroll; ink and color on silk"),
      "a real artist not on the allowlist never matches, regardless of medium"
  end

  test "precedence: Ukiyo-e fires before Japanese Painting's bare `japan` term" do
    assert_equal "Ukiyo-e Painting",
      match(artist: "Katsushika Hokusai", country: "Japan", medium: "Hanging scroll; ink and color on silk")
  end

  test "an unlisted Japanese painter on the same medium still falls through to Japanese Painting" do
    assert_equal "Japanese Painting",
      match(artist: "Matsumura Goshun", country: "Japan", medium: "Hanging scroll; ink and color on silk")
  end
end
