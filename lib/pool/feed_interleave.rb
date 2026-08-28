# Rotating-lens `feed_order` composer for story 0029 ("one of each"): a fresh
# `/feed` scroll should step through the pool's own named categories — a
# portrait, then a landscape, then a Mughal painting, then a 12th-century
# work, and so on — instead of the fixed shuffle every other pool stage
# already gives it.
#
# Standalone, not `Pool::Curator` (same reasoning `pool:genre_fill` already
# established): ordering is orthogonal to selection, and this module never
# adds or removes a work, only reassigns `feed_order` on rows the manifest
# already committed to.
#
#   manifest rows (genre/tradition/period are NOT literal keys on a row —
#   derived here the same way db/seeds.rb derives them at seed time, so this
#   stays a pure function with no DB read and no dependency on db:seed
#   having run yet)
#           │
#           ▼
#   bucket each row by (genre value | tradition value | period value |
#   "untagged"), one bucket per DISPLAYED value (below-floor values count as
#   absent for that facet). Priority genre > tradition > period > untagged —
#   a row that could match more than one facet is claimed by whichever comes
#   first in LENS_ORDER, never placed twice
#           │
#           ▼
#   round-robin ONE PER BUCKET, fixed order (every genre value, then every
#   tradition value, then every period value, then untagged) — the same
#   idiom `Pool::Curator#fill_remainder` already uses for region, generalized
#   from one grouping to many. A bucket that empties just stops taking a
#   turn for every future round (see `round_robin`)
#           │
#           ▼
#   `feed_order` reassigned in placement order; rows returned SORTED by
#   their new `feed_order`, not just carrying the field — `LIMIT=N bin/rails
#   db:seed` reads array order, and a reorder that leaves the array
#   physically unsorted would silently break that quick-pass
module Pool
  module FeedInterleave
    # Claim priority AND bucket-visit order are the same fact stated once,
    # not two independent choices that happen to agree — a future edit here
    # changes both without risking the two silently disagreeing.
    LENS_ORDER = %i[genre tradition period].freeze
    UNTAGGED = :untagged

    # `LENS_ORDER`'s MEMBERSHIP must always match `Painting::FACETS` (its
    # ORDER is deliberately different — priority, not display order, see
    # above) — a facet added, removed, or renamed on the model with nothing
    # here to notice would silently stop being interleaved, or interleave a
    # facet that no longer exists.
    raise "Pool::FeedInterleave::LENS_ORDER must name the same facets as Painting::FACETS" \
      unless LENS_ORDER.to_set == Painting::FACETS.to_set

    Result = Struct.new(:rows, :bucket_sizes, :exhausted_early, keyword_init: true)

    def self.reorder!(manifest_rows)
      derived = manifest_rows.map { |row| [ row, derive(row) ] }
      buckets = build_buckets(derived)
      # Captured before `round_robin` runs: it drains every queue by
      # `shift`-ing the SAME arrays in place, so reading sizes afterward
      # would report everything as empty.
      sizes = buckets.transform_values(&:size)

      order = round_robin(buckets)
      order.each_with_index { |row, i| row["feed_order"] = i }

      # A bucket "runs out before the pool did" (plan.md) when it holds
      # fewer works than the single largest bucket — round-robin needs
      # exactly `sizes.values.max` rounds to drain everything, so any
      # smaller bucket stops taking a turn before that last round. `order`
      # always includes the `UNTAGGED` bucket, so `sizes` is never empty and
      # `.max` is never nil.
      rounds = sizes.values.max
      Result.new(
        rows: order,
        bucket_sizes: sizes,
        exhausted_early: sizes.select { |_, n| n.positive? && n < rounds }.keys
      )
    end

    # The exact three derivations `db/seeds.rb` performs at seed time —
    # called a second time here, not reimplemented, so the two call sites
    # can never quietly drift apart on what a row's own facet values are.
    def self.derive(row)
      {
        genre: row["genre"] || Pool::TitleGenre.infer(row["title"]),
        tradition: Pool::Tradition.from_strings(
          culture: row["culture"], country: row["country"],
          department: row["department"], artist: row["artist"], medium: row["medium"]
        ),
        period: Pool::PeriodBucket.from_dated(row["dated"])
      }
    end

    # One shuffled queue per DISPLAYED value of each facet (a value that
    # exists but hasn't cleared `Painting::MIN_FACET_WORKS` gets no queue —
    # a row whose only tag is a below-floor value is not a candidate for
    # that facet's lens at all, and falls through to the next one, same as a
    # row with no tag there), plus one `UNTAGGED` queue for whatever matches
    # nothing. `Painting.displayed_facet_values`'s `counts:` kwarg
    # (story 0027) is what makes this a pure function: the default reads the
    # live database, which `pool:interleave` runs before `db:seed` ever
    # touches — passing this run's own manifest tally instead means zero DB
    # access while reusing the exact same floor-and-sort logic.
    def self.build_buckets(derived)
      tallies = LENS_ORDER.index_with { Hash.new(0) }
      derived.each { |_, values| LENS_ORDER.each { |f| tallies[f][values[f]] += 1 if values[f] } }

      displayed = LENS_ORDER.index_with { |f| Painting.displayed_facet_values(f, counts: tallies[f]) }

      buckets = Hash.new { |h, k| h[k] = [] }
      shuffle = Random.new(Pool::Curator::SEED)

      derived.each do |row, values|
        facet = LENS_ORDER.find { |f| values[f] && displayed[f].include?(values[f]) }
        key = facet ? [ facet, values[facet] ] : UNTAGGED
        buckets[key] << row
      end

      order = LENS_ORDER.flat_map { |f| displayed[f].map { |v| [ f, v ] } } + [ UNTAGGED ]
      order.index_with { |key| buckets[key].shuffle(random: shuffle) }
    end

    # `Pool::Curator#fill_remainder`'s own idiom — round-robin by group, one
    # per group per round — generalized from one grouping (region) to every
    # individual bucket here (27+ of them: every genre, tradition and period
    # value, plus untagged), instead of tracking 4 separate per-lens cursors
    # that each cycle their OWN values in turn. One flat round-robin over
    # every bucket is equivalent (a bucket that runs dry simply stops taking
    # a turn, exactly like a per-lens cursor skipping an exhausted value) —
    # it just does it with one mechanism instead of four, and without
    # needing an arbitrary "untagged gets N slots per cycle so it isn't
    # underrepresented" weighting constant: every bucket, tagged or not,
    # gets exactly one turn per round on equal footing.
    def self.round_robin(buckets)
      queues = buckets.values.reject(&:empty?)
      order = []

      until queues.empty?
        queues.each { |q| order << q.shift }
        queues.reject!(&:empty?)
      end

      order
    end
  end
end
