require "test_helper"

# Story 0029. A synthetic pool with known bucket sizes so each test can pin
# down exactly one property of the round-robin, the same style
# `PoolCuratorTest` uses for the quota table.
class PoolFeedInterleaveTest < ActiveSupport::TestCase
  # `_label` is a test-only tag, not a manifest field — it rides along
  # through `reorder!` unmodified (the module only ever adds `feed_order`),
  # so assertions can identify which synthetic group a row came from without
  # re-deriving genre/tradition/period from its raw fields.
  def rows_for(label, count, genre: nil, culture: nil, dated: nil)
    Array.new(count) do |i|
      {
        "source" => "test", "source_id" => "#{label}-#{i}", "title" => "Work #{label} #{i}",
        "genre" => genre, "culture" => culture, "country" => nil, "department" => nil,
        "artist" => nil, "medium" => nil, "dated" => dated, "_label" => label
      }
    end
  end

  test "every displayed facet value appears within the first round" do
    rows = rows_for("A", 20, genre: "A") +
           rows_for("B", 20, genre: "B") +
           rows_for("Japanese", 20, culture: "Japan") +
           rows_for("19thC", 20, dated: "1850") +
           rows_for("untagged", 20)

    result = Pool::FeedInterleave.reorder!(rows.shuffle)

    first_round = result.rows.sort_by { |r| r["feed_order"] }.first(5).map { |r| r["_label"] }
    assert_equal %w[A B Japanese 19thC untagged], first_round
  end

  test "no work is placed twice and the whole pool is placed" do
    rows = rows_for("A", 20, genre: "A") + rows_for("untagged", 15)

    result = Pool::FeedInterleave.reorder!(rows)

    assert_equal rows.size, result.rows.size
    assert_equal rows.size, result.rows.map { |r| r["source_id"] }.uniq.size
    assert_equal (0...rows.size).to_a, result.rows.map { |r| r["feed_order"] }.sort
  end

  test "a genre below MIN_FACET_WORKS gets no bucket of its own and falls through to untagged" do
    rows = rows_for("A", 20, genre: "A") + rows_for("Rare", 5, genre: "Rare")

    result = Pool::FeedInterleave.reorder!(rows)

    assert_not_includes result.bucket_sizes.keys, [ :genre, "Rare" ]
    assert_equal 5, result.bucket_sizes[:untagged]
  end

  test "equal-size buckets alternate one-for-one, not clustered at the tail" do
    rows = rows_for("A", 16, genre: "A") + rows_for("untagged", 16)

    result = Pool::FeedInterleave.reorder!(rows)

    labels = result.rows.sort_by { |r| r["feed_order"] }.map { |r| r["_label"] }
    assert_equal (%w[A untagged] * 16), labels
  end

  test "a bucket smaller than the largest degrades to skip, reported, pool still fully placed" do
    rows = rows_for("small", 16, genre: "Small") + rows_for("big", 40, genre: "Big")

    result = Pool::FeedInterleave.reorder!(rows)

    assert_equal 56, result.rows.size
    assert_includes result.exhausted_early, [ :genre, "Small" ]
    assert_not_includes result.exhausted_early, [ :genre, "Big" ]
  end

  test "priority: a row matching both genre and tradition is claimed by genre only" do
    both = rows_for("both", 20, genre: "A", culture: "Japan")
    tradition_only = rows_for("tradition_only", 20, culture: "Japan")

    result = Pool::FeedInterleave.reorder!(both + tradition_only)

    assert_equal 20, result.bucket_sizes[[ :genre, "A" ]]
    # Not 40: if the 20 "both" rows leaked into the tradition bucket too
    # (priority claiming broken), this would count them twice.
    assert_equal 20, result.bucket_sizes[[ :tradition, "Japanese Painting" ]]
  end

  test "derive matches the same functions db/seeds.rb calls, same arguments" do
    row = {
      "genre" => nil, "title" => "Portrait of a Woman",
      "culture" => "Japan", "country" => nil, "department" => nil,
      "artist" => "Anonymous", "medium" => "hanging scroll", "dated" => "17th century"
    }

    values = Pool::FeedInterleave.derive(row)

    assert_equal Pool::TitleGenre.infer(row["title"]), values[:genre]
    assert_equal Pool::PeriodBucket.from_dated(row["dated"]), values[:period]
    assert_equal Pool::Tradition.from_strings(
      culture: row["culture"], country: row["country"],
      department: row["department"], artist: row["artist"], medium: row["medium"]
    ), values[:tradition]
  end

  test "LENS_ORDER names exactly the same facets as Painting::FACETS" do
    assert_equal Painting::FACETS.to_set, Pool::FeedInterleave::LENS_ORDER.to_set
  end

  test "reorder! returns rows sorted by the new feed_order, not just carrying the field" do
    rows = rows_for("A", 16, genre: "A") + rows_for("untagged", 16)

    result = Pool::FeedInterleave.reorder!(rows.shuffle)

    assert_equal result.rows.map { |r| r["feed_order"] }.sort, result.rows.map { |r| r["feed_order"] }
  end
end
