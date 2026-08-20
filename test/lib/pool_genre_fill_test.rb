require "test_helper"
require "tempfile"

# Story 0022 Release 2. No real network calls — `Pool::Sources.get_json` is
# the one external boundary, stubbed the same way `Pool::Recognizable::LIST`
# gets swapped in test_helper.rb (Minitest 6 ships no mocking library; a
# real method swap exercises the genuine call-and-parse path rather than a
# double standing in for it).
class PoolGenreFillTest < ActiveSupport::TestCase
  def with_stubbed_get_json(responder)
    original = Pool::Sources.method(:get_json)
    Pool::Sources.define_singleton_method(:get_json) { |url, params = nil, attempts: 3| responder.call(url, params) }
    yield
  ensure
    Pool::Sources.define_singleton_method(:get_json, original)
  end

  def manifest_with(*rows)
    file = Tempfile.new([ "genre_fill_test", ".json" ])
    file.write(JSON.generate(rows))
    file.flush
    (@tempfiles ||= []) << file
    Pathname.new(file.path)
  end

  teardown { Array(@tempfiles).each(&:close!) }

  test "AIC subject_titles resolve to a genre, written back into the manifest" do
    path = manifest_with({ "source" => "aic", "source_id" => 1, "genre" => nil })

    with_stubbed_get_json(->(url, _params) {
      assert_match "artworks/1", url
      { "data" => { "subject_titles" => [ "portraits: male subject", "men" ] } }
    }) do
      result = Pool::GenreFill.run!(manifest_path: path)
      assert_equal 1, result.total
      assert_equal 1, result.fetched
      assert_equal 1, result.matched
      assert_equal 0, result.skipped
    end

    assert_equal "Portrait", JSON.parse(path.read).first["genre"]
  end

  test "MET tags resolve to a genre through the nested term structure" do
    path = manifest_with({ "source" => "met", "source_id" => 2, "genre" => nil })

    with_stubbed_get_json(->(url, _params) {
      assert_match "objects/2", url
      { "tags" => [ { "term" => "Landscapes" }, { "term" => "Boats" } ] }
    }) do
      Pool::GenreFill.run!(manifest_path: path)
    end

    assert_equal "Landscape", JSON.parse(path.read).first["genre"]
  end

  # Eng review Issue 1 / outside voice #1: CMA and MIA have no reachable
  # genre field at all — this proves it's structural (nothing ever tries),
  # not just "the dictionary happens not to match."
  test "CMA and MIA rows are never fetched at all" do
    path = manifest_with(
      { "source" => "cma", "source_id" => 3, "genre" => nil },
      { "source" => "mia", "source_id" => 4, "genre" => nil }
    )

    called = false
    with_stubbed_get_json(->(_url, _params) { called = true; nil }) do
      result = Pool::GenreFill.run!(manifest_path: path)
      assert_equal 0, result.total
    end

    refute called, "CMA/MIA rows must never trigger a fetch — neither source has a genre field to fetch"
  end

  test "a work with no matching tag stays genre: nil, not an empty string" do
    path = manifest_with({ "source" => "aic", "source_id" => 5, "genre" => nil })

    with_stubbed_get_json(->(*) { { "data" => { "subject_titles" => [ "Armor", "Men" ] } } }) do
      Pool::GenreFill.run!(manifest_path: path)
    end

    assert_nil JSON.parse(path.read).first["genre"]
  end

  # The critical gap eng review flagged (Failure modes): one malformed
  # record must not abort the run for the others.
  test "a fetch failure on one record is skipped, and the rest of the run continues" do
    path = manifest_with(
      { "source" => "aic", "source_id" => 6, "genre" => nil },
      { "source" => "aic", "source_id" => 7, "genre" => nil }
    )

    with_stubbed_get_json(->(url, _params) {
      raise "boom — malformed response" if url.include?("artworks/6")

      { "data" => { "subject_titles" => [ "portrait" ] } }
    }) do
      result = Pool::GenreFill.run!(manifest_path: path)
      assert_equal 2, result.total
      assert_equal 1, result.fetched
      assert_equal 1, result.skipped
      assert_includes result.skipped_ids, "aic:6"
    end

    by_id = JSON.parse(path.read).index_by { |w| w["source_id"] }
    assert_nil by_id[6]["genre"]
    assert_equal "Portrait", by_id[7]["genre"]
  end

  test "a 404 (nil body) counts as skipped, not as zero tags fetched" do
    path = manifest_with({ "source" => "met", "source_id" => 8, "genre" => nil })

    with_stubbed_get_json(->(*) { nil }) do
      result = Pool::GenreFill.run!(manifest_path: path)
      assert_equal 0, result.fetched
      assert_equal 1, result.skipped
    end
  end

  test "dry_run fetches and matches but never writes the manifest" do
    path = manifest_with({ "source" => "aic", "source_id" => 9, "genre" => nil })
    original = path.read

    with_stubbed_get_json(->(*) { { "data" => { "subject_titles" => [ "portrait" ] } } }) do
      result = Pool::GenreFill.run!(manifest_path: path, dry_run: true)
      assert_equal 1, result.matched
    end

    assert_equal original, path.read
  end
end
