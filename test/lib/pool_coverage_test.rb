require "test_helper"

# The buckets, and why more than one kind of "missing".
#
# "Missing" has several different causes and only one of them is fixable by
# curating better. Collapsing them — the seed spec had four buckets and no
# `absent` at all — reports Michelangelo Buonarroti as copyright-walled when he
# died in 1564 and these four collections simply hold no qualifying painting by
# him. That blames copyright for a collection gap and makes the walled fraction
# look bigger than it is.
#
# `walled` vs `absent` is decided by a hand-set `rights` field on the 0007 row,
# NOT by a death year. All four sources are US institutions already filtered to
# US public domain at fetch, so absence from the mirrors cannot discriminate;
# and life + 70 gets it backwards for Frida Kahlo, who died in 1954 and whom
# every US museum still treats as restricted.
class PoolCoverageTest < ActiveSupport::TestCase
  NAMES = [
    { "rank" => 1, "name" => "Claude Monet",            "rights" => "public_domain" },
    { "rank" => 2, "name" => "Johannes Vermeer",        "rights" => "public_domain" },
    { "rank" => 3, "name" => "Katsushika Hokusai",      "rights" => "public_domain" },
    { "rank" => 4, "name" => "Michelangelo Buonarroti", "rights" => "public_domain" },
    { "rank" => 5, "name" => "Frida Kahlo",             "rights" => "walled" },
    { "rank" => 6, "name" => "Yayoi Kusama" }
  ].freeze

  def candidate(artist, id, title: "Work #{id}")
    Pool::Candidate.new(source: "cma", source_id: id, title: title, artist: artist,
                        region: "europe", year: 1880,
                        image_url_full: "https://example.test/#{id}.jpg",
                        image_width: 3000, image_height: 3000)
  end

  def manifest_row(artist, id) = candidate(artist, id).to_manifest

  # Monet ships. Vermeer is held but unselected. Hokusai is held only as a work
  # that fails a 0013 bar. Michelangelo and Kahlo are in nobody's mirror.
  def coverage
    Pool::Coverage.new(
      manifest: [ manifest_row("Claude Monet", 1) ],
      usable: [ candidate("Claude Monet", 1), candidate("Johannes Vermeer", 2) ],
      raw: [ candidate("Claude Monet", 1), candidate("Johannes Vermeer", 2),
             candidate("Katsushika Hokusai", 3, title: "x" * (Pool::MAX_TITLE + 1)) ]
    )
  end

  def bucket_for(name)
    coverage.rows.find { |row| row.name == name }.bucket
  end

  test "a name in the shipped pool is covered" do
    with_recognizable_names(NAMES) { assert_equal :covered, bucket_for("Claude Monet") }
  end

  test "a name the mirrors hold and the pool does not is fillable" do
    with_recognizable_names(NAMES) { assert_equal :fillable, bucket_for("Johannes Vermeer") }
  end

  test "a name held only as a work that fails a 0013 bar is not reported as absent" do
    with_recognizable_names(NAMES) do
      row = coverage.rows.find { |r| r.name == "Katsushika Hokusai" }

      assert_equal :fails_bars, row.bucket
      assert_match(/rejected by a 0013 bar/, row.note)
    end
  end

  # The correction the seed spec needed. Michelangelo died in 1564; reporting
  # him as walled would blame copyright for a collection gap.
  test "a public-domain name no collection holds is absent, not walled" do
    with_recognizable_names(NAMES) do
      row = coverage.rows.find { |r| r.name == "Michelangelo Buonarroti" }

      assert_equal :absent, row.bucket
      assert_match(/public domain, not held/, row.note)
    end
  end

  # Kahlo is the case a death-year rule gets backwards: died 1954, so life + 70
  # calls her public domain in 2026, while every US museum treats her as
  # restricted under the 95-years-from-publication term. The hand-set field is
  # the whole reason this bucket is right.
  test "a name still in copyright is walled, decided by the row and not by arithmetic" do
    with_recognizable_names(NAMES) do
      row = coverage.rows.find { |r| r.name == "Frida Kahlo" }

      assert_equal :walled, row.bucket
      assert_match(/in copyright/, row.note)
    end
  end

  test "a row with no rights value is not placed, and says so" do
    with_recognizable_names(NAMES) do
      row = coverage.rows.find { |r| r.name == "Yayoi Kusama" }

      assert_equal :absent, row.bucket
      assert_match(/no `rights`/, row.note)
    end
  end

  # The vacuous pass, pinned. With no mirrors nothing can be classified, and
  # claiming "Vermeer: public domain, not held" from an empty directory is a
  # false claim about the exact names the story is judged on.
  test "with no mirrors nothing is classified and no score is reported" do
    with_recognizable_names(NAMES) do
      blind = Pool::Coverage.new(manifest: [], usable: [], raw: [])

      assert_equal [ :unknown ], blind.rows.map(&:bucket).uniq
      assert_not blind.measurable?
      assert_nil blind.reachable_share, "an empty denominator must not score a perfect 1.0"
      assert_match(/not measurable/, blind.to_markdown)
    end
  end

  test "reachable coverage counts only what these collections could supply" do
    with_recognizable_names(NAMES) do
      # covered 1 (Monet), fillable 1 (Vermeer). Walled, absent and fails_bars
      # are excluded: a fill cannot reach them, so counting them would make the
      # number permanently red and un-actionable.
      assert_in_delta 0.5, coverage.reachable_share, 0.001
    end
  end

  test "a list with nothing reachable reports no score rather than a perfect one" do
    with_recognizable_names([ { "rank" => 1, "name" => "Frida Kahlo", "rights" => "walled" } ]) do
      assert_nil coverage.reachable_share
    end
  end

  test "the markdown names the missing works and the public-domain line" do
    with_recognizable_names(NAMES) do
      markdown = coverage.to_markdown

      assert_match(/Johannes Vermeer/, markdown)
      assert_match(/1 qualifying work/, markdown)
      assert_match(/Reachable coverage: 50\.0%/, markdown)
      assert_match(/hand-decided `rights` field/, markdown)
    end
  end
end
