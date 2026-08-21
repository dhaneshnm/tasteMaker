# Story 0026 step 3 — the demand stage's target list: theme name -> kind ->
# value(s) -> want. `user-research/0008` §3.1-3.7 measured both sides (demand
# ranking, mirror stock) and named this expansion story's whole reason to
# exist. The pool's actual ceiling turned out to be 2,300, not the 3,000
# decisions/0016 targeted (`Curator::TARGET`'s comment has the falsification)
# — the theme quotas below are `want`ed against whatever pool the curator
# actually produces; a theme short at the achieved size reports its
# shortfall in `pool_report.md` rather than failing silently (see
# `Curator#fill_themes`).
#
# `kind` + `value(s)` — not a precomputed matcher — is the ONE declaration
# both consumers derive from, so they can never disagree about what a theme
# targets (code review, story 0026):
#   - `Curator#fill_themes` (curation time) builds a matcher via
#     `matcher_for` and counts candidates as they're taken.
#   - `Pool::Report.theme_recount_section` (after `pool:genre_fill`) reads
#     this same TABLE to recompute from the committed manifest through the
#     FULL seed ladder (tag > title) — genre_fill's native museum tags can
#     legitimately override a title-inferred value after curation already
#     ran, which a curation-time-only matcher can never see.
#
# Both routes reuse `Pool::Tradition.from_strings` / `Pool::TitleGenre.
# infer` — the SAME pure functions that stamp the facet at seed time — so
# "counted toward this theme's quota" and "lights the /feed facet" cannot
# disagree (the 0023 `queue_healthy?` lesson, applied in advance, plan step
# 3). `want` is an ABSOLUTE floor on the final pool (pinned + new), not a
# delta the expansion must add on top — the pinned 2,000 already carries
# some stock for most of these (0008's own numbers: Persian ~19, thangka
# ~24, marine 1, still life/flowers 15...), and `Curator#take` is idempotent
# against an already-pinned identity, so `fill_themes` only spends new slots
# on the shortfall.
module Pool
  module ThemeTargets
    # [ theme label, kind, value(s), want ] — want values from story 0026's
    # success signal 2 (specs/0026-the-wider-pool/story.md). `kind` is
    # `:tradition` (never touched by genre_fill) or `:genre` (title-inferred
    # at curation time, can be overridden by a native museum tag after).
    TABLE = [
      [ "Persian miniature", :tradition, "Persian & Islamic Painting", 25 ],
      [ "Thangka", :tradition, "Tibetan & Nepalese Painting", 15 ],
      [ "Still life / flowers", :genre, %w[Still\ Life Flowers], 40 ],
      [ "Marine", :genre, "Marine Art", 12 ],
      [ "Mythological", :genre, "Mythological Art", 15 ],
      [ "Ukiyo-e (strict)", :tradition, "Ukiyo-e Painting", 5 ],
      [ "Madhubani", :tradition, "Madhubani Painting", 5 ],
      [ "Vanitas / trompe-l'œil", :genre, "Vanitas", 5 ],
      [ "Icon", :genre, "Icon", 5 ],
      [ "Cityscape", :genre, "Cityscape", 10 ]
    ].freeze

    def self.tradition_matcher(value)
      ->(c) {
        Pool::Tradition.from_strings(
          culture: c.culture, country: c.country, department: c.department,
          artist: c.artist, medium: c.medium
        ) == value
      }
    end

    def self.genre_matcher(*values)
      ->(c) { values.include?(Pool::TitleGenre.infer(c.title)) }
    end

    # A `Candidate`-testing matcher for a TABLE row — title-only for
    # `:genre` (the only signal a fresh mirror candidate carries at
    # curation time; no tag exists yet for a work `pool:genre_fill` hasn't
    # touched). Used by `Curator#fill_themes`.
    def self.matcher_for(kind, values)
      values = Array(values)
      kind == :tradition ? tradition_matcher(values.first) : genre_matcher(*values)
    end

    # The theme's true value(s) checked against the FULL seed ladder (tag >
    # title) for a committed MANIFEST ROW (a Hash with string keys, not a
    # `Candidate`) — the value a reader would actually see. Used by
    # `Pool::Report.theme_recount_section`.
    def self.ladder_value_for(kind, row)
      if kind == :tradition
        Pool::Tradition.from_strings(culture: row["culture"], country: row["country"],
          department: row["department"], artist: row["artist"], medium: row["medium"])
      else
        row["genre"].presence || Pool::TitleGenre.infer(row["title"])
      end
    end
  end
end
