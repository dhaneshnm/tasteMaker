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
