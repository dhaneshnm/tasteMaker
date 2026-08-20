require "set"

# The quota table IS the curation.
#
# At 110 works a person picks each one. At 2,000 nobody does, so the persona
# argument has to be executable: every bar below traces to a success signal in
# specs/0013-a-deeper-pool/story.md, and a run that cannot meet one fails loudly
# and writes nothing. A quota table that degrades silently is not a quota table.
module Pool
  class Curator
    class Unmeetable < StandardError; end

    # decisions/0016: 2,000 -> 3,000, additive. The first 2,000 are pinned
    # (story 0026 step 2) — every bar below is a share, so it scales with the
    # constant rather than needing its own edit.
    TARGET = 3_000
    SEED = 1889 # the house shuffle seed, from db/seeds.rb

    MAX_PER_ARTIST   = 5     # 0.17% at 3,000. Today's ceiling is 3 of 110 = 2.7%.
    MAX_SOURCE_SHARE = 0.50  # no museum owns the pool
    # No tradition owns it either. Without this the range floor is met by
    # draining whichever non-Western collection is deepest — the first run came
    # out 46% South Asian, which answers persona 3's complaint with a different
    # monoculture rather than with range.
    MAX_REGION_SHARE = 0.25
    MIN_NON_WESTERN  = 0.45  # holds today's measured 43.6%
    MIN_POST_1900    = 0.15  # holds today's measured 15.5%; persona 5
    HIGHLIGHT_SHARE  = 0.10  # famous works anchor the pool, never dominate it
    MIN_TEXT_SHARE   = 0.70  # story 0005's fallback needs something to fall back to

    attr_reader :selected, :rejected
    # Story 0019: what the recognizable-name stage actually managed, per name,
    # and any museum slug two names' alias sets both claimed.
    attr_reader :recognizable, :collisions
    # Story 0026: per-theme want/took/shortfall, keyed by theme label.
    attr_reader :themes

    # `resolver` is called on a candidate the moment it is about to be taken,
    # and may veto it. The Met needs this: its CSV carries no image URL and no
    # dimensions, so whether a plate exists at all is only knowable per work.
    # Resolving lazily means a missing photograph costs one API call and the
    # next candidate takes its place — no backfill pass, no silent shortfall.
    #
    # `pinned`: story 0026. Candidates built from the PREVIOUS committed
    # manifest's own rows (verbatim field values, not a mirror re-lookup) —
    # taken first, unconditionally, never through the resolver. See `pin!`.
    def initialize(candidates, target: TARGET, resolver: nil, pinned: [])
      @candidates = candidates
      @pinned = pinned
      @pinned_identities = Set.new(pinned.map(&:identity))
      @target = target
      @resolver = resolver
      @unresolvable = Set.new
      @selected = []
      @taken = Set.new
      @artists = Hash.new(0)
      @sources = Hash.new(0)
      @regions = Hash.new(0)
      @highlights = 0
      @rejected = Hash.new(0)
      @recognizable = {}
      @collisions = []
      @themes = {}
    end

    def curate!
      pool = dedup(@pinned + reject_unusable(@candidates))
      raise Unmeetable, "only #{pool.size} usable candidates for a target of #{@target}" if pool.size < @target

      pin!
      queue = ordered(pool)

      fill_themes(queue)
      fill_recognizable(queue)
      fill_scarce_regions(queue)
      fill(queue, floor(MIN_POST_1900)) { |c| c.year.to_i >= 1900 }
      fill(queue, highlight_target, &:highlight?)
      fill(queue, floor(MIN_TEXT_SHARE), &:text?)
      fill_remainder(queue)

      verify!
      @selected
    end

    # --- filters --------------------------------------------------------

    def reject_unusable(candidates)
      candidates.select do |c|
        if c.title.blank?
          @rejected[:no_title] += 1
        elsif c.title.length > MAX_TITLE
          @rejected[:title_too_long] += 1
        elsif c.artist.blank? && c.culture.blank?
          @rejected[:anonymous] += 1
        # The Met publishes neither image URL nor dimensions in its CSV, so its
        # plates are measured at selection time over a ranged request instead.
        elsif c.source == "met"
          next true
        elsif c.image_url_full.blank?
          @rejected[:no_image] += 1
        elsif c.longest_edge < MIN_EDGE
          @rejected[:too_small] += 1
        else
          next true
        end
        false
      end
    end

    # Two museums holding the same painting is one painting. The copy carrying
    # museum text wins, then the larger plate: a mute duplicate is worth less
    # than one a reader can read. A pinned copy wins outright, before either
    # tiebreak — otherwise another museum's copy of a pinned painting (a
    # different `identity`, same `dedup_key`) can win the group and the same
    # painting ships twice, once under each identity (story 0026 eng review).
    def dedup(candidates)
      candidates.group_by(&:dedup_key).map do |_, group|
        next group.first if group.one?

        @rejected[:duplicate] += group.size - 1
        group.max_by { |c| [ pinned?(c) ? 1 : 0, c.text? ? 1 : 0, c.longest_edge ] }
      end
    end

    def pinned?(candidate) = @pinned_identities.include?(candidate.identity)

    # Text-bearing first, then the bigger plate, over a stable shuffle so the
    # pool is reproducible run to run.
    def ordered(pool)
      pool.shuffle(random: Random.new(SEED))
          .sort_by { |c| [ c.text? ? 0 : 1, -c.longest_edge ] }
    end

    # --- selection ------------------------------------------------------

    # `resolve: false` (pins only): the plate is already cached in Active
    # Storage locally and on the prod volume, so an upstream URL dying now is
    # not evidence the work should drop — skipping the resolver call also
    # deletes ~2,000 HEAD requests + 167 Met API calls per curate run.
    def take(candidate, resolve: true)
      return false unless room_for?(candidate)
      return false if resolve && !resolved?(candidate)

      @selected << candidate
      @taken << candidate.identity
      @artists[candidate.artist_key] += 1
      @sources[candidate.source] += 1
      @regions[candidate.region] += 1
      @highlights += 1 if candidate.highlight?
      true
    end

    # Asked once per candidate that has already cleared every cap, so the cost
    # is one request per work that actually enters the pool. A well-formed URL
    # is not a reachable one — this is the only place that difference is found
    # before a reader meets a blank plate.
    def resolved?(candidate)
      return true if @resolver.nil?
      return false if @unresolvable.include?(candidate.identity)
      return true if @resolver.call(candidate)

      @unresolvable << candidate.identity
      @rejected[:no_plate] += 1
      false
    end

    def room_for?(candidate)
      @selected.size < @target &&
        !@taken.include?(candidate.identity) &&
        !@unresolvable.include?(candidate.identity) &&
        @artists[candidate.artist_key] < MAX_PER_ARTIST &&
        @sources[candidate.source] < (@target * MAX_SOURCE_SHARE).to_i &&
        @regions[candidate.region] < (@target * MAX_REGION_SHARE).to_i &&
        (!candidate.highlight? || @highlights < highlight_target)
    end

    # Story 0026 step 2 — Jordan's contract: every published day and every
    # favorite points at one of these, so none may vanish in a re-curation.
    # Taken first, unconditionally, before any fill stage claims a cap slot —
    # at TARGET=3,000 no cap can bind against candidates that already lived
    # inside the OLD 2,000-work caps, so this should never raise in practice.
    # If it ever does, that is a structural break in the contract, not a
    # shortfall to report and move past: this codebase carries no deny-list
    # carve-out for a pinned work, so every failure here is fatal, named.
    def pin!
      failed = @pinned.reject { |candidate| take(candidate, resolve: false) }
      return if failed.empty?

      raise Unmeetable, "#{failed.size} pinned work(s) could not be placed: " +
        failed.first(10).map { |c| "#{c.source}/#{c.source_id}" }.join(", ")
    end

    # Story 0026 step 3 — the demand stage. `queue` is already ordered
    # description-bearing-first (`ordered`), so iterating it in place gives
    # each theme the same "text-bearing before blurbless" priority the plan
    # asks for, with no extra sort. `want` is an absolute floor on the whole
    # pool (see `Pool::ThemeTargets`), so a pinned identity already matching
    # the theme counts toward it without spending a `take` — same fix as
    # `fill_recognizable`'s receipt (eng review), for the same reason.
    def fill_themes(queue)
      @themes = {}
      Pool::ThemeTargets::TABLE.each do |name, matcher, want|
        took = 0
        queue.each do |c|
          break if took >= want
          next unless matcher.call(c)

          took += 1 if @taken.include?(c.identity) || take(c)
        end
        @themes[name] = { want: want, took: took, shortfall: [ want - took, 0 ].max }
      end
    end

    # Story 0019. The names a visitor already knows, taken FIRST — before
    # anything else claims a slot.
    #
    # Order is the whole mechanism. The quota table optimises range, era and
    # readable text, and is blind to whether anybody has heard of the artist,
    # so a pool it curates can hold 2,000 paintings and no Vermeer, no Hokusai
    # and no Hiroshige while all three sit unused in the mirrors — which is
    # exactly what shipped. Running this stage first spends the caps on
    # recognizable work; the existing stages then restore every floor over
    # what is left.
    #
    # It cannot break a bar. Every take goes through `room_for?` like every
    # other stage, so the fill can only come out INCOMPLETE, never invalid —
    # and `pool:coverage` prints by how much. That is also why no TARGET growth
    # is needed: this substitutes recognizable Europeans for arbitrary ones
    # inside Europe's existing 25% budget rather than adding to it.
    #
    # Story 0026: `queue` now includes pinned works, so `match.works`/`total`/
    # `pages` correctly count them. `take(candidate)` no-ops for an
    # already-pinned identity (room_for? sees it in `@taken`) — counted via
    # `@taken.include?` instead, so a name's coverage receipt reflects what is
    # actually in the pool, not just what this stage newly added (eng review:
    # under pinning, `taken` read ~0 for every name without this).
    def fill_recognizable(queue)
      @recognizable = {}
      @collisions = []
      return unless Recognizable.available?

      matches, @collisions = Recognizable.match(queue)
      matches.each do |match|
        taken = 0
        match.works.each do |candidate|
          break if taken >= Recognizable::DEPTH

          taken += 1 if @taken.include?(candidate.identity) || take(candidate)
        end
        @recognizable[match.name] = { taken:, available: match.total, pages: match.pages,
                                      primary_slug: match.primary_slug }
      end
    end

    # Scarce regions first, because a floor met by luck is not met. Africa,
    # Latin America and Southeast Asia are the buckets that run out; spending
    # them before Europe is what makes the range bar hold by construction.
    # Stops the moment the floor is met, mid-region. Draining a whole region
    # first overshoots into the target and starves every later floor of room —
    # the pool came out five text-bearing works short that way.
    def fill_scarce_regions(queue)
      want = floor(MIN_NON_WESTERN)
      by_region = queue.group_by(&:region)
      regions = by_region.keys.reject { |r| Pool::WESTERN.include?(r) || r == "unknown" }

      regions.sort_by { |r| by_region[r].size }.each do |region|
        by_region[region].each do |candidate|
          break if non_western_count >= want

          take(candidate)
        end
        break if non_western_count >= want
      end
    end

    def fill(queue, want, &test)
      have = @selected.count(&test)
      queue.each do |c|
        break if have >= want
        next unless test.call(c)

        have += 1 if take(c)
      end
    end

    # Round-robin by region, one work per region per round, so the tail of the
    # pool is not whichever museum happens to sort first.
    def fill_remainder(queue)
      queues = queue.group_by(&:region).values.map(&:dup)

      while @selected.size < @target
        progressed = false
        queues.each do |q|
          break if @selected.size >= @target

          while (candidate = q.shift)
            next unless take(candidate)

            progressed = true
            break
          end
        end
        break unless progressed
      end
    end

    # --- counters -------------------------------------------------------

    def floor(share) = (@target * share).ceil
    def highlight_target = (@target * HIGHLIGHT_SHARE).to_i
    # A work we could not place is not evidence of range. Counting "unknown"
    # toward the range floor would let a mapping gap look like reach — 156 of
    # the first pool's "non-Western" works turned out to be Dutch and Flemish.
    def non_western_count = @selected.count { |c| !c.western? && c.region != "unknown" }
    def text_count = @selected.count(&:text?)
    def post_1900_count = @selected.count { |c| c.year.to_i >= 1900 }

    # --- bars -----------------------------------------------------------

    def bars
      max_source = @sources.values.max.to_i
      max_artist = @artists.values.max.to_i
      smallest = @selected.map(&:longest_edge).min.to_i

      {
        "pool size" => [ @selected.size, @target, @selected.size >= @target ],
        "sources represented" => [ @sources.size, 4, @sources.size >= 4 ],
        "largest source share" => [ max_source, (@target * MAX_SOURCE_SHARE).to_i, max_source <= @target * MAX_SOURCE_SHARE ],
        "most works by one artist" => [ max_artist, MAX_PER_ARTIST, max_artist <= MAX_PER_ARTIST ],
        "largest region share" => [ @regions.values.max.to_i, (@target * MAX_REGION_SHARE).to_i,
                                    @regions.values.max.to_i <= @target * MAX_REGION_SHARE ],
        "outside Europe and North America" => [ non_western_count, floor(MIN_NON_WESTERN), non_western_count >= floor(MIN_NON_WESTERN) ],
        "dated 1900 or later" => [ post_1900_count, floor(MIN_POST_1900), post_1900_count >= floor(MIN_POST_1900) ],
        "highlights (cap)" => [ @highlights, highlight_target, @highlights <= highlight_target ],
        "carrying museum text" => [ text_count, floor(MIN_TEXT_SHARE), text_count >= floor(MIN_TEXT_SHARE) ],
        "smallest image edge" => [ smallest, MIN_EDGE, smallest >= MIN_EDGE ]
      }
    end

    def verify!
      failures = bars.reject { |_, (_, _, ok)| ok }
      return if failures.empty?

      raise Unmeetable, "quota bars not met:\n" +
        failures.map { |name, (have, want, _)| "  #{name}: have #{have}, want #{want}" }.join("\n")
    end
  end
end
