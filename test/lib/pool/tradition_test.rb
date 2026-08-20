require "test_helper"

class Pool::TraditionTest < ActiveSupport::TestCase
  def match(culture: nil, country: nil, department: nil, artist: nil)
    Pool::Tradition.from_strings(culture: culture, country: country, department: department, artist: artist)
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
end
