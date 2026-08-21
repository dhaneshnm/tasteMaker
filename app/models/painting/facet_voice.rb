# The hand-written half of the facet machinery (story 0027 design review,
# outside voice #8). `Painting.displayed_facet_values`/`index_for` are
# generic over any string a museum or a derivation writes into a facet
# column; nothing there decides how that string is SPOKEN — a plate caption
# in the index ("Mughal", "17th") or a sentence in the masthead label
# ("Mughal painting, eighteenth century"). That is editorial voice, and
# CLAUDE.md reserves it for the person, not a generator.
#
# Two tables, one per form, covering the full offered vocabulary — every
# `Pool::Tradition::VALUES` entry, every canonical genre
# (`Pool::GenreTerms::DICTIONARY.values | Pool::TitleGenre::TABLE.map(&:first)`),
# and every century `Pool::PeriodBucket::VALID_CENTURIES` can produce — not
# just the values the committed pool happens to carry today. A value with
# zero works still needs a voice the day a reseed gives it one.
#
# `short` renders in an 80px plate caption at the `.masthead__aside` type
# setting (0.72rem/0.18em caps): design review Pass 5 measured that an
# unbroken word over 9 characters overflows the cell, so every entry here is
# either <= 9 characters or carries a space the caption can wrap on
# ("Still life", not "Stilllife"). `facet_voice_test.rb` asserts this over
# the whole table, not just the values in use.
#
# `sentence` renders in the masthead label and has no such constraint — it
# reads as prose ("Mughal painting, eighteenth century"), lowercase except
# where the value itself is a proper noun, because `label_for` capitalises
# only the first character of the composed string.
class Painting::FacetVoice
  SHORT = {
    tradition: {
      "Mughal Painting" => "Mughal",
      "Pahari Painting" => "Pahari",
      "Rajput Painting" => "Rajput",
      "Kalighat Painting" => "Kalighat",
      "Jain Manuscript Painting" => "Jain",
      "Madhubani Painting" => "Madhubani",
      "Korean Painting" => "Korean",
      "Chinese Painting" => "Chinese",
      "Japanese Painting" => "Japanese",
      "Persian & Islamic Painting" => "Persian",
      "Tibetan & Nepalese Painting" => "Tibetan",
      "Ukiyo-e Painting" => "Ukiyo-e"
    },
    genre: {
      "Portrait" => "Portraits",
      "Mythological Art" => "Myth",
      "Vanitas" => "Vanitas",
      "Icon" => "Icons",
      "Religious Art" => "Religious",
      "Still Life" => "Still life",
      "Flowers" => "Flowers",
      "Cityscape" => "Cityscape",
      "Landscape" => "Landscape",
      "Marine Art" => "Marine",
      "Nude" => "Nudes",
      "Allegory" => "Allegory",
      "Animal Painting" => "Animals",
      "Battle Painting" => "Battles",
      "Genre Scene" => "Genre",
      "History Painting" => "History"
    }
  }.freeze

  SENTENCE = {
    tradition: {
      "Mughal Painting" => "Mughal painting",
      "Pahari Painting" => "Pahari painting",
      "Rajput Painting" => "Rajput painting",
      "Kalighat Painting" => "Kalighat painting",
      "Jain Manuscript Painting" => "Jain manuscript painting",
      "Madhubani Painting" => "Madhubani painting",
      "Korean Painting" => "Korean painting",
      "Chinese Painting" => "Chinese painting",
      "Japanese Painting" => "Japanese painting",
      "Persian & Islamic Painting" => "Persian & Islamic painting",
      "Tibetan & Nepalese Painting" => "Tibetan & Nepalese painting",
      "Ukiyo-e Painting" => "ukiyo-e"
    },
    genre: {
      "Portrait" => "portraits",
      "Mythological Art" => "mythological scenes",
      "Vanitas" => "vanitas",
      "Icon" => "icons",
      "Religious Art" => "religious art",
      "Still Life" => "still lifes",
      "Flowers" => "flowers",
      "Cityscape" => "cityscapes",
      "Landscape" => "landscapes",
      "Marine Art" => "marine painting",
      "Nude" => "nudes",
      "Allegory" => "allegorical scenes",
      "Animal Painting" => "animal painting",
      "Battle Painting" => "battle painting",
      "Genre Scene" => "genre scenes",
      "History Painting" => "history painting"
    }
  }.freeze

  # Spelled out, not "17th" — the masthead label is prose ("the seventeenth
  # century"), and a numeral in the middle of a sentence reads as a form
  # field, not a written line. Covers `Pool::PeriodBucket::VALID_CENTURIES`
  # (1..21) in full.
  ORDINAL_WORDS = %w[
    zeroth first second third fourth fifth sixth seventh eighth ninth tenth
    eleventh twelfth thirteenth fourteenth fifteenth sixteenth seventeenth
    eighteenth nineteenth twentieth twenty-first
  ].freeze

  # `label_for` composes in this order — tradition names the wing, subject
  # narrows it, century dates it — which is the index's own section order
  # (design review Pass 1) and not `Painting::FACETS`' order (period, genre,
  # tradition — that array governs the `/feed` URL/display order and stays
  # as it is; the two orderings are allowed to differ because they answer
  # different questions).
  LABEL_ORDER = %i[tradition genre period].freeze

  # The word a reader asked for, per facet — "Subject" (persona 3's own
  # word, `specs/personas.md`; also what `user-research/0008` measures
  # demand against), not the column name. One home for this (`/simplify`,
  # altitude): it used to live on `PaintingsController`, with the view
  # reaching into a controller constant to read it — the facet vocabulary
  # belongs beside the rest of the facet vocabulary.
  FACET_LABEL = { tradition: "Tradition", genre: "Subject", period: "Century" }.freeze

  # Which facets the index shows as plates versus a caps-link row — a
  # century has no face. This used to be two independent encodings (a
  # controller constant driving `@plates`, a view-side `facet == :period`
  # check driving the section markup) that happened to agree; one
  # declaration, read by both.
  PLATE_FACETS = %i[tradition genre].freeze

  # `value` may be a value this table has no entry for (a reseed can write a
  # tradition or genre this list has not caught up to yet) — the fallback is
  # the canonical value itself, logged once, so a new value degrades to
  # slightly-wrong voice rather than a 500 on the feed.
  def self.short(facet, value)
    return period_short(value) if facet == :period

    SHORT.dig(facet, value) || unheard(facet, value)
  end

  def self.sentence(facet, value)
    return period_sentence(value) if facet == :period

    SENTENCE.dig(facet, value) || unheard(facet, value)
  end

  # "The full gallery" unfiltered; otherwise the active facets' sentence
  # forms, joined and capitalised once at the front — "Mughal painting,
  # eighteenth century", never "Mughal Painting, Eighteenth Century".
  def self.label_for(active)
    parts = LABEL_ORDER.filter_map { |facet| sentence(facet, active[facet]) if active[facet] }
    return "The full gallery" if parts.empty?

    joined = parts.join(", ")
    joined[0].upcase + joined[1..]
  end

  def self.period_short(value)
    n = value.to_s[/\d+/]
    n ? "#{n}#{ordinal_suffix(n.to_i)}" : unheard(:period, value)
  end

  def self.period_sentence(value)
    n = value.to_s[/\d+/]&.to_i
    word = n && ORDINAL_WORDS[n]
    word ? "the #{word} century" : unheard(:period, value)
  end

  def self.ordinal_suffix(n)
    return "th" if (11..13).cover?(n % 100)

    { 1 => "st", 2 => "nd", 3 => "rd" }.fetch(n % 10, "th")
  end
  private_class_method :ordinal_suffix

  def self.unheard(facet, value)
    Rails.logger.warn("[facet_voice] no #{facet} form for #{value.inspect}")
    value.to_s
  end
  private_class_method :unheard
end
