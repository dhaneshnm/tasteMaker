require "test_helper"

# The two normalizations that decide which works survive curation.
#
# Story 0019 (C3) moved both from `downcase.gsub(/[^a-z0-9]/, "")` to
# `parameterize`. The old form DELETED accented characters where parameterize
# transliterates them, and the difference is not cosmetic: it decided that
# "Paul Cézanne" and "Paul Cezanne" were two artists, so each got the full
# per-artist ceiling and the shipped pool carried nine works by one man on one
# artist page. R1 — the fix does not exist without something that fails when it
# regresses.
class PoolTest < ActiveSupport::TestCase
  def candidate(artist:, title: "A Painting", source: "cma", id: 1)
    Pool::Candidate.new(source: source, source_id: id, title: title, artist: artist)
  end

  test "artist_key transliterates accents instead of deleting them" do
    accented = candidate(artist: "Paul Cézanne")
    plain    = candidate(artist: "Paul Cezanne", id: 2)

    assert_equal "paul-cezanne", accented.artist_key
    assert_equal accented.artist_key, plain.artist_key,
      "accented and unaccented spellings must share one per-artist bucket"
  end

  test "artist_key agrees with the slug the artist page groups on" do
    %w[Paul\ Cézanne Édouard\ Vuillard Chaïm\ Soutine Katsushika\ Hokusai].each do |name|
      assert_equal Painting.artist_slug_for(name), candidate(artist: name).artist_key,
        "the ceiling and the artist page must count the same thing (eng review E1)"
    end
  end

  # Anonymous works are not one prolific artist.
  test "a blank artist still falls back to the work's own identity" do
    assert_equal "anon:cma:7", candidate(artist: "", id: 7).artist_key
    assert_equal "anon:cma:7", candidate(artist: nil, id: 7).artist_key
  end

  # The deny-list belongs to linkability, not to the ceiling. If a culture
  # string keyed as nil it would reach the `anon:` branch, every row would
  # become its own bucket, and the per-artist cap would stop capping them.
  test "a deny-listed culture string still groups, and is not scattered as anonymous" do
    china = candidate(artist: "China", id: 1)
    also  = candidate(artist: "China", id: 2)

    assert_nil Painting.artist_slug_for("China"), "still not linkable"
    assert_equal "china", china.artist_key
    assert_equal china.artist_key, also.artist_key
    assert_not china.artist_key.start_with?("anon:")
  end

  test "dedup_key unifies accented and unaccented spellings of one title" do
    a = candidate(artist: "Edgar Degas", title: "Danseuses à la barre")
    b = candidate(artist: "Edgar Degas", title: "Danseuses a la barre", id: 2)

    assert_equal a.dedup_key, b.dedup_key,
      "one painting held by two museums under two spellings is still one painting"
  end

  test "dedup_key still separates different paintings by the same artist" do
    a = candidate(artist: "Claude Monet", title: "Water Lilies")
    b = candidate(artist: "Claude Monet", title: "Haystacks", id: 2)

    assert_not_equal a.dedup_key, b.dedup_key
  end
end
