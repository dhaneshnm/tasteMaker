require "test_helper"

# Region is the field the range bar is counted from, so a mis-mapping does not
# fail loudly — it inflates the pool's claimed reach. Both cases below were real
# defects found while curating: the first counted ~290 American paintings as
# range, the second is the substring trap that would have followed it.
class PoolRegionTest < ActiveSupport::TestCase
  def region(country: nil, culture: nil, department: nil, continent: nil)
    Pool.region_for(country: country, culture: culture, department: department, continent: continent)
  end

  test "Arts of the Americas does not make an American painting Latin American" do
    assert_equal "north_america",
      region(country: "United States", department: "Arts of the Americas")
  end

  test "Arts of the Americas still yields to a place that names itself" do
    assert_equal "latin_america",
      region(country: "Mexico", department: "Arts of the Americas")
  end

  test "an American city with no country still lands in North America" do
    assert_equal "north_america", region(country: "Philadelphia", department: "Arts of the Americas")
  end

  test "Indiana is not India" do
    assert_equal "north_america", region(country: "Indiana", department: "American Art")
    assert_equal "south_asia", region(country: "India", department: "Asian Art")
  end

  # The Art Institute names a city where Minneapolis names a country. Left
  # unmapped these fell to "unknown" and were counted toward the range floor —
  # 156 works, most of them Dutch and Flemish.
  test "a European city is Europe, not an unplaced work" do
    assert_equal "europe", region(country: "Holland", department: "Painting and Sculpture of Europe")
    assert_equal "europe", region(country: "Venice", department: "Painting and Sculpture of Europe")
    assert_equal "europe", region(country: "Flanders", department: "Painting and Sculpture of Europe")
  end

  test "Arts of Asia is split by the place, not lumped" do
    assert_equal "south_asia", region(country: "Rajasthan", department: "Arts of Asia")
    assert_equal "east_asia", region(country: "Guangdong", department: "Arts of Asia")
  end

  # In four American collections the word is the state far more often than the
  # country, so it is deliberately not a West Asian term.
  test "Georgia reads as the state" do
    assert_equal "north_america", region(country: "Georgia", department: "American Art")
  end

  test "an unambiguous department decides before the place text" do
    assert_equal "west_asia_islamic", region(country: nil, department: "Islamic Art")
    assert_equal "east_asia", region(country: nil, department: "Korean Art")
  end

  test "a place decides when the department names several regions" do
    assert_equal "africa",
      region(country: "Ethiopia", department: "Arts of Africa, Oceania, and the Americas")
    assert_equal "east_asia", region(country: "Japan", department: "Asian Art")
  end

  test "continent is the last resort, never the first" do
    assert_equal "south_asia", region(country: "India", continent: "Asia")
    assert_equal "east_asia", region(country: nil, culture: nil, department: nil, continent: "Asia")
    assert_equal "unknown", region(country: nil, culture: nil, department: nil)
  end

  test "the year is the latest one the museum's prose mentions" do
    assert_equal 1575, Pool.year_from("c. 1570–75"), "an abbreviated end year is still an end year"
    assert_equal 1868, Pool.year_from("Edo period (1615–1868)")
    assert_equal 1932, Pool.year_from("anything", 1932), "a structured date wins over the prose"
    assert_nil Pool.year_from("undated")
  end

  # The case that decides which side of the 1900 bar a work lands on.
  test "an abbreviated range that crosses a century rolls forward, not back" do
    assert_equal 1902, Pool.year_from("1898–02")
    assert_equal 1875, Pool.year_from("1870-75")
  end
end
