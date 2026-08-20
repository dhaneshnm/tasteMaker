# Story 0026 step 3 — the demand stage's target list: theme name -> matcher
# -> want. `user-research/0008` §3.1-3.7 measured both sides (demand ranking,
# mirror stock) and named this the 3,000-work story's whole reason to exist.
#
# Each matcher reuses `Pool::Tradition.from_strings` or `Pool::TitleGenre.
# infer` — the SAME pure functions that stamp the facet at seed time — so
# "counted toward this theme's quota" and "lights the /feed facet" cannot
# disagree (the 0023 `queue_healthy?` lesson, applied in advance, plan step
# 3). `want` is an ABSOLUTE floor on the final 3,000-work pool (pinned +
# new), not a delta the expansion must add on top — the pinned 2,000
# already carries some stock for most of these (0008's own numbers: Persian
# ~19, thangka ~24, marine 1, still life/flowers 15...), and `Curator#take`
# is idempotent against an already-pinned identity, so `fill_themes` only
# spends new slots on the shortfall.
module Pool
  module ThemeTargets
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

    # [ theme label, matcher, want ] — want values from story 0026's success
    # signal 2 (specs/0026-the-wider-pool/story.md).
    TABLE = [
      [ "Persian miniature", tradition_matcher("Persian & Islamic Painting"), 25 ],
      [ "Thangka", tradition_matcher("Tibetan & Nepalese Painting"), 15 ],
      [ "Still life / flowers", genre_matcher("Still Life", "Flowers"), 40 ],
      [ "Marine", genre_matcher("Marine Art"), 12 ],
      [ "Mythological", genre_matcher("Mythological Art"), 15 ],
      [ "Ukiyo-e (strict)", tradition_matcher("Ukiyo-e Painting"), 5 ],
      [ "Madhubani", tradition_matcher("Madhubani Painting"), 5 ],
      [ "Vanitas / trompe-l'œil", genre_matcher("Vanitas"), 5 ],
      [ "Icon", genre_matcher("Icon"), 5 ],
      [ "Cityscape", genre_matcher("Cityscape"), 10 ]
    ].freeze
  end
end
