require "test_helper"

# Story 0022 Release 2. The dictionary is an allowlist — every case here
# exists to pin that "allowlist" means something concrete, not just "we
# picked good words."
class PoolGenreTermsTest < ActiveSupport::TestCase
  test "a plain genre term matches" do
    assert_equal "Portrait", Pool::GenreTerms.match([ "Portraits" ])
    assert_equal "Landscape", Pool::GenreTerms.match([ "landscape" ])
  end

  test "matching is case-insensitive and whitespace-tolerant" do
    assert_equal "Portrait", Pool::GenreTerms.match([ "  PORTRAIT  " ])
  end

  # The real noise found in the Release 2 dry-run's sampled AIC data — full,
  # discrete tag strings that are exhibition/provenance metadata, sitting
  # right next to genuine genre tags on the same object.
  test "real noise terms never match, even sitting next to a genuine hit" do
    assert_nil Pool::GenreTerms.match([ "Century of Progress" ])
    assert_nil Pool::GenreTerms.match([ "world's fairs" ])
    assert_nil Pool::GenreTerms.match([ "Chicago World's Fairs" ])

    # Noise alongside a real hit: the real hit still wins, the noise is inert.
    assert_equal "Portrait",
      Pool::GenreTerms.match([ "Century of Progress", "world's fairs", "portrait" ])
  end

  # AIC's own qualifier convention — not a general substring rule. Confirmed
  # against real sampled data (2026-08-19): "portraits: male subject" is a
  # real AIC tag that never equals the bare word "portrait".
  test "a colon-qualified tag matches on its prefix" do
    assert_equal "Portrait", Pool::GenreTerms.match([ "portraits: male subject" ])
    assert_equal "Portrait", Pool::GenreTerms.match([ "portraits: female subject" ])
  end

  test "an arbitrary word that merely contains a dictionary key does not match" do
    # "portraitist" contains "portrait" as a substring but is not the word —
    # the allowlist is exact-after-normalization, never substring.
    assert_nil Pool::GenreTerms.match([ "portraitist's studio" ])
  end

  # Eng review Issue 2: within one work's own terms, dictionary ORDER is the
  # tie-break — not term order, not alphabetical, not "first added". Portrait
  # is listed before Landscape in DICTIONARY, so it wins regardless of which
  # order the SOURCE happened to list its own tags in.
  test "within-work multi-match resolves by dictionary order, not source order" do
    assert_equal "Portrait", Pool::GenreTerms.match([ "Landscape", "Portrait" ])
    assert_equal "Portrait", Pool::GenreTerms.match([ "Portrait", "Landscape" ])
  end

  test "no match anywhere returns nil, not a guess" do
    assert_nil Pool::GenreTerms.match([ "Armor", "Men", "Horses" ])
  end

  test "blank or empty input is nil, not a raise" do
    assert_nil Pool::GenreTerms.match([])
    assert_nil Pool::GenreTerms.match(nil)
    assert_nil Pool::GenreTerms.match([ "", nil ])
  end

  # Buddhist-subject works were the Release 2 dry-run's own measured miss
  # (undercounted MET coverage) — grown into the dictionary rather than left
  # as a footnote (plan Step 2).
  test "the Buddhist-subject gap the dry-run found is closed" do
    assert_equal "Religious Art", Pool::GenreTerms.match([ "buddhism", "bodhisattvas" ])
  end
end
