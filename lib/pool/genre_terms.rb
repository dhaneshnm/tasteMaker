# The genre facet's vocabulary (story 0022 Release 2) — Getty AAT terms, not
# an invented taxonomy (the story's own constraint). An allowlist: only a
# string that equals one of these keys can ever produce a genre value.
#
# Deliberately NOT a substring/fuzzy match. AIC's own `subject_titles` mixes
# real genre words with exhibition/provenance noise on the very same object
# ("Century of Progress", "world's fairs", "Chicago World's Fairs" all
# appeared in the Release 2 dry-run's sampled data, next to genuine hits like
# "portrait") — a loose match risks a noise term misfiring as a genre.
#
# ONE exception to plain equality, not a general fuzzy rule: AIC qualifies
# some tags with a colon ("portraits: male subject"), its own documented
# convention, not free text — `Pool::GenreTerms.match` also checks the part
# before the colon, so the qualified and bare forms of the same real word
# both count. That is parsing a museum's own syntax, not approximate
# matching.
module Pool
  module GenreTerms
    # Order is the tie-break (eng review Issue 2): when one work's own
    # source terms match more than one key, the FIRST key in THIS list wins
    # — the dictionary IS the priority list, not a second ranking bolted on
    # top of it.
    DICTIONARY = {
      "portrait" => "Portrait",
      "portraits" => "Portrait",
      "self-portrait" => "Portrait",
      "landscape" => "Landscape",
      "landscapes" => "Landscape",
      "seascape" => "Marine Art",
      "seascapes" => "Marine Art",
      "marine" => "Marine Art",
      "still life" => "Still Life",
      "battles" => "Battle Painting",
      "battle" => "Battle Painting",
      "history painting" => "History Painting",
      "mythology" => "Mythological Art",
      "mythological" => "Mythological Art",
      "religion" => "Religious Art",
      "religious" => "Religious Art",
      "religious figures" => "Religious Art",
      "religious scenes" => "Religious Art",
      "christianity" => "Religious Art",
      "christian subjects" => "Religious Art",
      "biblical" => "Religious Art",
      "bible" => "Religious Art",
      "bibles" => "Religious Art",
      "buddhism" => "Religious Art",
      "buddha" => "Religious Art",
      "bodhisattvas" => "Religious Art",
      "hinduism" => "Religious Art",
      "saints" => "Religious Art",
      "nude" => "Nude",
      "nudes" => "Nude",
      "allegory" => "Allegory",
      "allegories" => "Allegory",
      "cityscape" => "Cityscape",
      "cityscapes" => "Cityscape",
      "animal" => "Animal Painting",
      "animals" => "Animal Painting",
      "domestic" => "Genre Scene",
      "interior scene" => "Genre Scene",
      "interior scenes" => "Genre Scene"
    }.freeze

    # `terms` — an array of raw museum tag strings. Returns the first
    # dictionary value any of them (or their colon-qualified prefix) equals,
    # or nil.
    def self.match(terms)
      candidates = Array(terms).flat_map { |term| variants(term) }
      DICTIONARY.each do |key, value|
        return value if candidates.include?(key)
      end
      nil
    end

    def self.variants(term)
      base = term.to_s.downcase.strip
      prefix = base.split(":").first&.strip
      [ base, prefix ].compact.uniq
    end
  end
end
