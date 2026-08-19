# 0014 — The ceiling and the artist page count the same artist

Date: 2026-08-19

Position: `Pool::Candidate#artist_key` and `#dedup_key` stop normalizing with
`downcase.gsub(/[^a-z0-9]/, "")` and start using `parameterize`, the same
transliteration `Painting.artist_slug_for` has always used. Direction-level
because it changes **which 2,000 paintings ship to readers**, and because it
converts a number story 0018 could only print into a bar `bin/ci` enforces.

## What was actually wrong

Two normalizations, one of them lossy, and nothing that could see the gap.

`parameterize` transliterates an accent; the old `gsub` **deleted** it. So
`"Paul Cézanne"` keyed as `paulcznne` and `"Paul Cezanne"` as `paulcezanne` —
two artists as far as `MAX_PER_ARTIST` was concerned, one artist as far as
`/artists/paul-cezanne` was concerned. Each bucket got the full ceiling of five
and the shipped pool carried **nine works by one man on one page**, against a
rule that says five.

`pool_quota_test` could not catch it: it recounts the manifest with the same
`gsub` the curator uses, so the test and the defect shared an assumption. The
number only became visible when story 0018 built the artist page and grouped by
slug — and eng review E1 found it by measuring rather than by reading the rule.

`dedup_key` carried the identical bug on the title, so an accented and an
unaccented spelling of one painting never deduped and both copies shipped.

Story 0018 Release 1 could not fix either. Unifying the keys changes
`room_for?` bucketing, so `pool:curate` stops reproducing the committed
manifest — an app-only release had no way to regenerate it, and the assertion
would have gone red with no fix available (outside voice X2). It was left as a
**reported** line in `pool:report` and deferred to the re-curation. This is that
re-curation.

## What decided the shape

Measured against the four committed mirrors, 2026-08-19, not reasoned about:

- **Blast radius is small and it is the intended one.** Artist buckets
  4,738 → 4,718: twenty accent-variant pairs merge, which is exactly the set
  the change exists to merge. Dedup collapses one additional work, 9,481 →
  9,480.
- **The ceiling now holds where it is read.** Max works on one artist page
  **9 → 5**, so `pool_quota_test` can assert `Painting.artist_slug_for` counts
  rather than printing them.
- **The deny-list deliberately stays out of `artist_key`.** Tried and rejected:
  if a `NOT_AN_ARTIST` string keyed as nil it would reach the `anon:` fallback,
  every "China" row would become its own bucket, and the per-artist ceiling
  would stop capping culture-as-artist rows altogether — the opposite of what
  the cap is for. The keys unify the *normalization* only.

The same re-curation carries story 0019's recognizable-name fill, because both
change which works survive and shipping them apart would mean re-curating and
reseeding production twice for one outcome.

## Prediction (falsifiable, time-bound)

**By 2026-08-21, with the re-curated manifest committed and seeded to
production, `pool_quota_test`'s slug-based ceiling assertion is green, no
`/artists/:slug` page in production shows more than five works, and every other
0013 bar is still green at an unchanged TARGET of 2,000.**

Falsified if the ceiling has to be raised, if a 0013 bar has to be relaxed to
accommodate the merge, or if TARGET has to grow to keep the bars green.

**Wrong-if, stated separately:** if merging accent variants turns out to have
suppressed works readers wanted — two genuinely different artists whose names
parameterize identically — this was the wrong unification. Checked before
shipping: story 0018 measured **zero cross-artist slug collisions** across all
1,019 distinct artist strings in the pool, and `pool:report` prints every merge
group so a future reseed surfaces new ones instead of hiding them.
