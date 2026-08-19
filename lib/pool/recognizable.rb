require "set"

# The names a visitor already knows, and the problem of finding them in four
# museums' worth of free-text attribution.
#
# Story 0019. The list itself is research, not code: it is mined, controlled
# against Wikipedia pageviews and committed as
# `user-research/data/0007-recognizable-names.json`. This file is only the
# matcher — and the matcher is the part that is easy to get wrong.
#
# The obvious matcher, `Painting.artist_slug_for(name) == painting.artist_slug`,
# loses most of what it claims to measure. Museums do not spell an artist one
# way. Measured over the committed mirrors, 2026-08-19:
#
#   name                naive  aliased
#   J. M. W. Turner         0      7     "Joseph Mallord William Turner"
#   Francisco Goya          0     29     four spellings, none of them "Francisco Goya"
#   Wassily Kandinsky       0      8     "Vasily" and "Vassily"
#   Rembrandt              17     42     three spellings
#   El Greco                3     12
#
# So a name resolves to a SET of acceptable slugs, built three ways, and every
# one of them is exact-after-reduction. Never substring: substring matching puts
# "Polidoro da Caravaggio" and "Cecco del Caravaggio" — different painters — on
# Caravaggio's page, and "Rembrandt Peale", an American with no relation, on
# Rembrandt's.
module Pool
  module Recognizable
    LIST = Rails.root.join("user-research/data/0007-recognizable-names.json")

    # D17 asked 2-3 works per filled name. `MAX_PER_ARTIST` is 5, so this sits
    # under the ceiling rather than fighting it: a name the mirrors can only
    # supply one work for gets one, and `pool:coverage` shows which.
    DEPTH = 3

    # Attribution qualifiers. These are rejected outright — never matched — and
    # the rejection is the point: "Workshop of Titian" is not Titian, and story
    # 0018 settled that this pipeline does not invent attributions it cannot
    # stand behind. Anchored at the start of the string, because "Rembrandt,
    # after whom..." is not what these look like; the museums put the qualifier
    # first.
    QUALIFIER = /\A\s*(?:
      (?:workshop|follower|imitator|circle|school|manner|studio|style|copy|pupil|
         successor|associate|assistant|group|master|forger)\b[^,;]{0,24}?\bof\b |
      (?:after|attributed\s+to|possibly\s+by|probably\s+by|formerly\s+attributed\s+to|
         in\s+the\s+style\s+of|imitator\s+of|copy\s+after)\b
    )\s*/xi

    Match = Struct.new(:name, :rank, :primary_slug, :by_slug, :works, :collided, keyword_init: true) do
      def total = works.size
      def pages = by_slug.size
    end

    class << self
      # The committed research list, or an empty list with one warning. NOT a
      # boot-time constant: a missing or malformed research file must not stop
      # the app, the test suite, or an unrelated rake task from starting. The
      # curation task is the only caller that cannot proceed without it, and it
      # says so itself.
      def names
        return @names if defined?(@names)

        @names = load_names
      end

      def available? = names.any?

      # `rights` decides the `walled` / `absent` split in `Pool::Coverage`. It
      # is a value ON THE ROW — seeded by the rule in the 0007 build script and
      # correctable by hand — rather than arithmetic inside the classifier, so
      # a wrong call is visible in the data and fixable without a code change.
      # A row missing it cannot be classified at all, so the two commands that
      # need the classification refuse to run rather than reporting a name as
      # "not held" when the truth may be "in copyright". Returned, not raised:
      # `Recognizable` is loaded by the whole app and a research file is not a
      # boot dependency.
      RIGHTS = %w[walled public_domain].freeze

      def rows_missing_rights = names.reject { |entry| RIGHTS.include?(entry["rights"]) }

      def reload!
        remove_instance_variable(:@names) if defined?(@names)
        remove_instance_variable(:@slug_sets) if defined?(@slug_sets)
        self
      end

      # name => Set of acceptable slugs. Built from the canonical spelling plus
      # every English Wikidata alias the 0007 list carries, which is why step 1
      # of the plan collects `altLabel` — "Francisco de Goya" is an alias of
      # Q5432, and it is the entire reason Goya's count is 29 rather than 0.
      def slug_sets
        @slug_sets ||= names.to_h do |entry|
          spellings = [ entry["name"], *Array(entry["aliases"]) ]
          [ entry["name"], spellings.filter_map { |s| Painting.artist_slug_for(s) }.to_set ]
        end
      end

      # Every slug a museum artist string could legitimately be filed under.
      # Empty for a qualified attribution, so those can never match anything.
      #
      #   "Titian (Tiziano Vecellio)" => [titian-tiziano-vecellio, titian, tiziano-vecellio]
      #   "Workshop of Titian"        => []
      def variant_slugs(artist)
        string = artist.to_s.strip
        return [] if string.blank? || string.match?(QUALIFIER)

        variants = [ string ]
        if (whole = string.match(/\A(.+?)\s*\(([^()]+)\)\s*\z/))
          variants << whole[1] << whole[2]
        end
        variants.filter_map { |v| Painting.artist_slug_for(v) }.uniq
      end

      # Match candidates to recognizable names, in the list's rank order and
      # preserving the caller's ordering within each name — the curator hands
      # this its already-ordered queue (text-bearing first, largest plate
      # first), so "the first DEPTH works" means "the best DEPTH works".
      #
      # Each name's works are re-ordered to put its PRIMARY slug first: the
      # acceptable slug holding the most candidates. Goya's 29 works are spread
      # over four artist pages, so filling three works naively would produce
      # three thin pages instead of one good one. Concentrating on the primary
      # slug is the cheap half of that problem; canonicalising the artist
      # string itself is the expensive half and is deferred (IDEAS.md).
      #
      # `claimed` resolves alias collisions in favour of the higher-ranked
      # name — two artists' alias sets can name the same museum slug, and
      # silently splitting it would put one artist's work on another's page.
      # Collisions are returned rather than swallowed so `pool:coverage` can
      # print them.
      def match(candidates)
        pages = Hash.new { |h, k| h[k] = [] }
        accepts = Hash.new { |h, k| h[k] = Set.new }

        candidates.each do |candidate|
          # The slug the work will ACTUALLY be filed under — the same call the
          # artist page makes. A work whose slug is nil (blank artist, a
          # `NOT_AN_ARTIST` string, or a name that transliterates to nothing)
          # has no reachable page at all, so filling it could never answer
          # "I looked for Vermeer and found nothing" and it is skipped here.
          page = Painting.artist_slug_for(candidate.artist)
          next if page.nil?

          pages[page] << candidate
          accepts[page].merge(variant_slugs(candidate.artist))
        end

        claimed = {}
        collisions = []

        matches = names.each_with_index.filter_map do |entry, index|
          name = entry["name"]
          wanted = slug_sets.fetch(name, Set.new)
          mine = pages.keys.select { |page| accepts[page].intersect?(wanted) }

          mine.each do |page|
            claimed.key?(page) ? collisions << { slug: page, kept: claimed[page], dropped: name }
                               : claimed[page] = name
          end
          owned = mine.select { |page| claimed[page] == name }
          # Two different empties, and collapsing them is a lie in one
          # direction. No candidate page at all means the collections do not
          # hold this artist — the caller should hear nothing. Candidate pages
          # that were all claimed by a higher-ranked name means the artist IS
          # held; dropped silently, `Coverage#build_row` would fall through to
          # the `rights` branch and report "none of the four collections holds
          # a qualifying painting". Zero collisions in the current run, so this
          # is a latent lie rather than a live one.
          next if owned.empty? && mine.empty?
          next Match.new(name:, rank: entry["rank"] || index + 1, primary_slug: nil,
                         by_slug: {}, works: [], collided: true) if owned.empty?

          grouped = owned.to_h { |page| [ page, pages[page].uniq ] }
          # The page a reader lands on is the one worth making deep, so the
          # deepest one is filled first: Goya's works are spread over four
          # pages, and taking one from each would make four thin pages where
          # concentrating makes one good one.
          primary = grouped.max_by { |page, works| [ works.size, page ] }.first

          Match.new(
            name: name,
            rank: entry["rank"] || index + 1,
            primary_slug: primary,
            by_slug: grouped.transform_values(&:size),
            works: grouped[primary] + grouped.except(primary).values.flatten
          )
        end

        [ matches, collisions ]
      end

      private

      # Silent on a missing file, loud on a malformed one. A missing list is a
      # legitimate state — every test that does not curate runs in it, and
      # warning there would print once per test — and the two callers that
      # genuinely cannot proceed (`pool:curate`, `pool:coverage`) say so
      # themselves. A file that exists but does not parse is different: that is
      # a broken commit, and staying quiet about it would silently drop the
      # whole fill.
      def load_names
        LIST.exist? ? parse(LIST.read) : []
      end

      public

      # Separate from the file read so it is testable without a fixture file on
      # disk. Accepts either the committed `{"names": [...]}` envelope or a bare
      # array, and drops entries with no usable name — a blank name builds an
      # empty slug set and would match nothing while still occupying a rank.
      def parse(json)
        parsed = JSON.parse(json)
        entries = parsed.is_a?(Hash) ? parsed["names"] : parsed
        Array(entries).select { |e| e.is_a?(Hash) && e["name"].to_s.strip.present? }
      rescue JSON::ParserError => e
        warn "  ⚠ #{LIST.basename} is not valid JSON (#{e.message}) — no recognizable-name fill."
        []
      end
    end
  end
end
