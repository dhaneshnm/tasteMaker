# How much of what a visitor would look for is actually in the pool.
#
# Story 0019. Runnable before AND after a re-curation, which is what makes the
# story's first success signal falsifiable: the "before" number is the baseline
# the "after" number has to beat, and both come from the same code reading the
# same committed files.
#
# The five buckets exist because "missing" has five different causes and only
# one of them is fixable by curating better. Blaming copyright for a collection
# gap — reporting Michelangelo Buonarroti as "walled" when he died in 1564 and
# simply is not held by these four collections as a painting — would be false,
# and would make the walled fraction look larger than it is.
#
# (The first draft of this file used J. M. W. Turner as that example. He is in
# the mirrors, seven works, and in the shipped manifest. The exemplar was wrong
# for the same reason the story's first coverage number was: exact-slug
# matching could not see "Joseph Mallord William Turner". Kept as a note
# because it is the mistake this class exists to stop making.)
module Pool
  class Coverage
    BUCKETS = {
      covered: "in the shipped pool",
      fillable: "not shipped, but the mirrors hold a qualifying work",
      fails_bars: "held, public domain, but every candidate fails a 0013 bar",
      absent: "public domain, and none of the four collections holds a qualifying painting",
      walled: "in copyright — unreachable from CC0 sources at any effort",
      unknown: "the mirrors were not on disk, so nothing could be classified"
    }.freeze

    Row = Struct.new(:name, :rank, :bucket, :in_pool, :in_mirror, :raw_mirror,
                     :pages, :primary_slug, :note, keyword_init: true)

    # `manifest` is the parsed db/seeds/paintings.json. `usable` and `raw` are
    # mirror candidates after and before `reject_unusable`/`dedup` — the
    # difference between them is the whole `fails_bars` bucket.
    def initialize(manifest:, usable:, raw:)
      @manifest = manifest
      @usable = usable
      @raw = raw
    end

    def rows
      @rows ||= begin
        pool_matches, = Recognizable.match(@manifest.map { |row| candidate_for(row) })
        mirror_matches, @collisions = Recognizable.match(@usable)
        raw_matches, = Recognizable.match(@raw)

        by_name = ->(matches) { matches.to_h { |m| [ m.name, m ] } }
        in_pool, in_mirror, in_raw = by_name[pool_matches], by_name[mirror_matches], by_name[raw_matches]

        Recognizable.names.each_with_index.map do |entry, index|
          name = entry["name"]
          pool, mirror, raw = in_pool[name], in_mirror[name], in_raw[name]
          build_row(entry, index, pool, mirror, raw)
        end
      end
    end

    def collisions
      rows # populates @collisions
      @collisions
    end

    def counts = rows.group_by(&:bucket).transform_values(&:size)

    # The number the success signal is stated against: of the names this
    # collection COULD supply, how many does it. Walled and absent names are
    # excluded from the denominator on purpose — a fill cannot reach them, so
    # counting them would make the metric un-actionable and permanently red.
    #
    # `nil`, not 1.0, when nothing is reachable. Returning a perfect score for
    # an empty denominator is how the eng review found this whole report going
    # vacuously green in CI: `tmp/pool` is gitignored, GitHub CI has no
    # mirrors, every name fell out of `fillable`, and the assertion that is
    # supposed to be this story's forcing function passed by measuring nothing.
    def reachable_share
      c = counts
      reachable = c.fetch(:covered, 0) + c.fetch(:fillable, 0)
      return nil if reachable.zero?

      c.fetch(:covered, 0).to_f / reachable
    end

    # Whether the mirrors were on disk at all. Without them nothing can be
    # classified and the caller must say so rather than report zeros.
    def measurable? = @raw.any?

    def to_markdown
      c = counts
      lines = []
      lines << "## Recognizable-name coverage (story 0019)"
      lines << ""
      lines << "#{Recognizable.names.size} names from `user-research/data/0007-recognizable-names.json`, " \
               "matched through Wikidata aliases and museum parentheticals (never by substring)."
      lines << ""
      lines << "| Bucket | Names | Meaning |"
      lines << "|---|---:|---|"
      BUCKETS.each { |key, meaning| lines << "| `#{key}` | #{c.fetch(key, 0)} | #{meaning} |" }
      lines << ""
      if reachable_share.nil?
        lines << "**Reachable coverage: not measurable.** No name is reachable — with no mirrors on disk " \
                 "(`bin/rails pool:mirror`) there is nothing to measure, and a score would be an artifact."
      else
        lines << "**Reachable coverage: #{(reachable_share * 100).round(1)}%** " \
                 "(#{c.fetch(:covered, 0)} of #{c.fetch(:covered, 0) + c.fetch(:fillable, 0)} names these four " \
                 "collections can actually supply)."
      end
      lines << ""
      if (provisional = met_only_provisional).positive?
        lines << "#{provisional} `fillable` name(s) are **provisional**: their only candidates are Met rows, " \
                 "which carry no plate URL and no dimensions in the CSV (`Pool::Curator#reject_unusable` passes " \
                 "them through unchecked). Whether a plate exists at all is knowable only at selection time, so " \
                 "these may resolve to `fails_bars` during curation."
        lines << ""
      end

      missing = rows.select { |r| r.bucket == :fillable }
      if missing.any?
        lines << "#{missing.size} name(s) the mirrors could supply and the pool does not hold:"
        lines << ""
        missing.first(40).each { |r| lines << "- **#{r.name}** — #{r.in_mirror} qualifying work(s) available" }
        lines << ""
      end

      spread = rows.select { |r| r.bucket == :covered && r.pages.to_i > 1 }.sort_by { |r| -r.pages }
      if spread.any?
        lines << "#{spread.size} covered name(s) are **spread over more than one artist page** — the museums " \
                 "spell them several ways, and canonicalising the artist string is deferred (`IDEAS.md`):"
        lines << ""
        spread.first(15).each { |r| lines << "- **#{r.name}** — #{r.in_pool} work(s) over #{r.pages} pages" }
        lines << ""
      end

      if collisions.any?
        lines << "**#{collisions.size} alias collision(s)** — one museum slug claimed by two names; the " \
                 "higher-ranked name kept it:"
        lines << ""
        collisions.each { |x| lines << "- `#{x[:slug]}` → kept **#{x[:kept]}**, dropped #{x[:dropped]}" }
        lines << ""
      end

      lines << "`walled` vs `absent` comes from each 0007 row's hand-decided `rights` field, not from a " \
               "death-year rule: all four sources are US institutions already filtered to US public domain at " \
               "fetch, so absence from the mirrors cannot tell copyright from a collection gap."
      lines.join("\n")
    end

    private

    # A `fillable` name whose every qualifying candidate is a Met row is only
    # provisionally fillable — see the note this feeds in `to_markdown`.
    def met_only_provisional
      mirror_matches, = Recognizable.match(@usable)
      by_name = mirror_matches.to_h { |m| [ m.name, m ] }
      rows.count do |row|
        row.bucket == :fillable &&
          (works = by_name[row.name]&.works).present? && works.all? { |c| c.source == "met" }
      end
    end

    def candidate_for(row)
      Candidate.new(**row.symbolize_keys.slice(*FIELDS))
    end

    def build_row(entry, index, pool, mirror, raw)
      base = {
        name: entry["name"], rank: entry["rank"] || index + 1,
        in_pool: pool&.total.to_i, in_mirror: mirror&.total.to_i, raw_mirror: raw&.total.to_i,
        pages: pool&.pages.to_i, primary_slug: (pool || mirror)&.primary_slug
      }

      if pool
        Row.new(**base, bucket: :covered)
      elsif mirror
        Row.new(**base, bucket: :fillable)
      elsif raw
        Row.new(**base, bucket: :fails_bars,
                note: "#{raw.total} candidate(s) held, all rejected by a 0013 bar")
      elsif !measurable?
        # No mirrors on disk. "Absent from four collections" is a claim about
        # data that was never read, and it is a claim about the exact names
        # this story is judged on — the first draft happily reported "Vermeer:
        # public domain, not held" from an empty directory.
        Row.new(**base, bucket: :unknown, note: "no mirrors on disk — nothing was measured")
      else
        # `rights` is decided once, by hand, on the 0007 row. NOT a death-year
        # heuristic: all four sources are US institutions already filtered to
        # US public domain at fetch (`Pool::Sources`), so absence from the
        # mirrors cannot discriminate copyright from a collection gap, and
        # life + 70 is the wrong frame besides — it calls Frida Kahlo (died
        # 1954) public domain while every US museum treats her as restricted
        # under the 95-years-from-publication term.
        case entry["rights"]
        when "walled" then Row.new(**base, bucket: :walled, note: "in copyright (0007 `rights`)")
        when "public_domain" then Row.new(**base, bucket: :absent, note: "public domain, not held by these four")
        else Row.new(**base, bucket: :absent, note: "0007 row carries no `rights` — not placed")
        end
      end
    end
  end
end
