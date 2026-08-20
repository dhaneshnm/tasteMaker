require "test_helper"

# R1: the quota table from story 0013 is only a rule if something enforces it.
#
# This reads the committed manifest and recounts every bar from scratch —
# deliberately not by asking Pool::Curator, which is the thing that could be
# wrong. If a future reseed regresses the pool's range, its era spread, or its
# supply of readable museum text, `bin/ci` goes red here.
class PoolQuotaTest < ActiveSupport::TestCase
  POOL = JSON.parse(Pool::MANIFEST.read).freeze

  # Built once for the whole file: it reads all four mirrors, which is slow
  # enough that doing it per test would be felt.
  #
  # `tmp/pool` is gitignored, so GitHub CI has no mirrors. The first draft
  # degraded to an empty candidate list here, which made every name fall out of
  # `fillable`, which made `reachable_share` return a perfect 1.0 — this
  # story's central forcing function passing by measuring nothing, in the only
  # place it ever runs unattended (eng review finding 1). The mirrors are now
  # either present or the test says so out loud.
  MIRRORS = Pool::Sources.all.keys.map { |name| Pool::MIRROR_DIR.join("#{name}.json") }.freeze

  POOL_COVERAGE = begin
    if MIRRORS.all?(&:exist?)
      raw = MIRRORS.flat_map { |path| JSON.parse(path.read).map { |row| Pool::Candidate.new(**row.symbolize_keys) } }
      scratch = Pool::Curator.new(raw)
      Pool::Coverage.new(manifest: POOL, usable: scratch.dedup(scratch.reject_unusable(raw)), raw: raw)
    end
  end

  def share(count) = count.to_f / POOL.size

  # Story 0026, Jordan's contract. A snapshot of the manifest as committed
  # BEFORE this story's expansion — (source, source_id, feed_order, genre)
  # only, not the full 13 MB manifest (plan step 2). Regenerated deliberately
  # at any future expansion, never silently.
  PRIOR_MANIFEST = JSON.parse(Rails.root.join("test/fixtures/files/0026-prior-manifest-snapshot.json").read).freeze

  test "every work in the prior committed manifest is still in the pool (the pin)" do
    current_ids = POOL.map { |w| [ w["source"], w["source_id"] ] }.to_set
    missing = PRIOR_MANIFEST.reject { |w| current_ids.include?([ w["source"], w["source_id"] ]) }

    assert_empty missing.map { |w| "#{w['source']}/#{w['source_id']}" },
      "a work from the prior manifest vanished from the pool — Jordan's contract is broken"
  end

  # MANDATORY regression (review rule): pinned rows keep their exact
  # `feed_order` — a bookmarked `/feed` offset must never reshuffle.
  test "REGRESSION: pinned feed_order is preserved byte-for-byte across the expansion" do
    current_by_id = POOL.index_by { |w| [ w["source"], w["source_id"] ] }

    wrong = PRIOR_MANIFEST.filter_map do |prior|
      current = current_by_id[[ prior["source"], prior["source_id"] ]]
      next if current.nil? # covered by the pin test above

      "#{prior['source']}/#{prior['source_id']}: was #{prior['feed_order']}, now #{current['feed_order']}" \
        unless current["feed_order"] == prior["feed_order"]
    end

    assert_empty wrong, "pinned feed_order values must never change — every reader's bookmarked page depends on it"
  end

  # MANDATORY regression (review rule): every pre-existing `genre` value
  # (248 at expansion time, museum-tag route, story 0022) survives the
  # manifest rewrite — the bug the eng review's critical finding caught: a
  # `Candidate#to_manifest` round-trip would silently drop this field.
  test "REGRESSION: every pre-existing genre value survives the manifest rewrite" do
    current_by_id = POOL.index_by { |w| [ w["source"], w["source_id"] ] }
    had_genre = PRIOR_MANIFEST.select { |w| w["genre"].present? }
    assert_operator had_genre.size, :>=, 200, "fixture sanity: expected ~248 pre-tagged rows"

    wrong = had_genre.filter_map do |prior|
      current = current_by_id[[ prior["source"], prior["source_id"] ]]
      next if current.nil? # covered by the pin test above

      "#{prior['source']}/#{prior['source_id']}: was #{prior['genre'].inspect}, now #{current['genre'].inspect}" \
        unless current["genre"] == prior["genre"]
    end

    assert_empty wrong, "a pre-existing genre value was dropped or changed by re-curation"
  end

  test "the manifest is the pool the story asked for" do
    assert_operator POOL.size, :>=, Pool::Curator::TARGET,
      "pool has shrunk below the target"
  end

  test "no museum owns the pool, and at least four are in it" do
    by_source = POOL.group_by { |w| w["source"] }

    assert_operator by_source.size, :>=, 4, "expected at least four museums"
    assert_equal [], by_source.keys - Painting::SOURCES.keys, "unknown source in the manifest"

    biggest, works = by_source.max_by { |_, w| w.size }
    assert_operator share(works.size), :<=, Pool::Curator::MAX_SOURCE_SHARE,
      "#{biggest} holds #{works.size} of #{POOL.size}"
  end

  # Persona 3: "repeated tired old Van Goghs which are already super famous."
  test "no artist holds more than the ceiling" do
    # `parameterize`, matching `Pool::Candidate#artist_key` after story 0019's
    # C3. The old `downcase.gsub(/[^a-z0-9]/, "")` here no longer corresponded
    # to anything in the codebase: it split MORE buckets than the enforced key
    # does, so it could not fail when the real ceiling was breached.
    counts = POOL.group_by { |w| w["artist"].to_s.parameterize }
                 .reject { |name, _| name.empty? } # anonymous works are not one artist
                 .transform_values(&:size)
    worst, count = counts.max_by { |_, c| c }

    assert_operator count, :<=, Pool::Curator::MAX_PER_ARTIST,
      "#{worst} appears #{count} times"
  end

  # Persona 3: "almost a complete disregard for works outside of the western canon."
  test "range beyond Europe and North America holds" do
    outside = POOL.count { |w| !Pool::WESTERN.include?(w["region"]) }

    assert_operator share(outside), :>=, Pool::Curator::MIN_NON_WESTERN,
      "only #{outside} of #{POOL.size} are from outside Europe and North America"
  end

  # Persona 5: "all I get are paintings from before 1900AD and I just don't like them."
  test "the pool reaches past 1900" do
    modern = POOL.count { |w| w["year"].to_i >= 1900 }

    assert_operator share(modern), :>=, Pool::Curator::MIN_POST_1900,
      "only #{modern} of #{POOL.size} are dated 1900 or later"
  end

  test "famous works anchor the pool without dominating it" do
    highlights = POOL.count { |w| w["highlight"] }

    assert_operator share(highlights), :<=, Pool::Curator::HIGHLIGHT_SHARE,
      "#{highlights} of #{POOL.size} are museum highlights"
  end

  # Story 0005: a pick with neither a hand-written note nor museum text is
  # invalid. Below this line the pool is a backlog of unpublishable paintings.
  test "most of the pool carries museum text a reader could actually read" do
    readable = POOL.count { |w| w["description"].to_s.strip.length >= Pool::MIN_TEXT }

    assert_operator share(readable), :>=, Pool::Curator::MIN_TEXT_SHARE,
      "only #{readable} of #{POOL.size} carry museum text"
  end

  # Story 0008's fold budget: at the accessibility type cap the day's first
  # written line has to stay on screen, and a museum catalogue entry that names
  # both sides of a folio pushes it 193px off. Enforced here because the pool is
  # what decides which titles ever reach the front door.
  test "no title is long enough to push the day's first line off the screen" do
    overlong = POOL.select { |w| w["title"].to_s.length > Pool::MAX_TITLE }

    assert_empty overlong.first(3).map { |w| w["title"] },
      "#{overlong.size} titles exceed #{Pool::MAX_TITLE} characters"
  end

  # Better bar 7: zoomable, high-quality images. Count is never traded for it.
  test "every plate clears the resolution floor" do
    small = POOL.select { |w| [ w["image_width"].to_i, w["image_height"].to_i ].max < Pool::MIN_EDGE }

    assert_empty small.first(5).map { |w| "#{w['source']}/#{w['source_id']}" },
      "#{small.size} plates are under #{Pool::MIN_EDGE}px"
  end

  test "every work is seedable" do
    POOL.first(50).each do |work|
      assert work["title"].present?, "a work has no title"
      assert work["image_url_full"].present?, "#{work['title']} has no image"
      assert Painting::SOURCES.key?(work["source"]), "#{work['source']} is not a known museum"
    end
    assert_equal POOL.size, POOL.map { |w| [ w["source"], w["source_id"] ] }.uniq.size,
      "the manifest contains the same work twice"
  end

  test "the committed report describes the committed manifest" do
    assert Pool::REPORT.exist?, "pool_report.md is missing — run bin/rails pool:curate"
    assert_includes Pool::REPORT.read, "#{POOL.size} paintings",
      "the report is stale against the manifest"
  end

  # Story 0019, success signal 3. `MAX_PER_ARTIST` was enforced on `artist_key`
  # while the artist page grouped on `Painting.artist_slug_for`, and the two
  # normalizations disagreed: "Paul Cézanne" and "Paul Cezanne" keyed apart and
  # kept the full ceiling each, so the shipped pool carried NINE works by one
  # man on one page. Story 0018 could only report that number (eng review X2)
  # because unifying the keys changes which works survive curation. This story
  # re-curates, so it becomes an assertion.
  test "no artist page holds more than the ceiling, counted the way the page counts" do
    counts = POOL.filter_map { |w| Painting.artist_slug_for(w["artist"]) }
                 .tally
    worst, count = counts.max_by { |_, c| c }

    assert_operator count, :<=, Pool::Curator::MAX_PER_ARTIST,
      "/artists/#{worst} would show #{count} works"
  end

  # The fill is only real if a later reseed cannot silently drop it. Stated
  # against the same code `bin/rails pool:coverage` prints, so the number in
  # the report and the number in the suite cannot drift.
  test "the pool holds the recognizable names these collections can actually supply" do
    skip "no mirrors on disk — run bin/rails pool:mirror" if POOL_COVERAGE.nil?
    skip "no recognizable-name list committed yet" unless Pool::Recognizable.available?

    missing = POOL_COVERAGE.rows.select { |row| row.bucket == :fillable }
    share = POOL_COVERAGE.reachable_share

    assert_not_nil share, "no recognizable name is reachable at all — the matcher or the list is broken"
    assert_operator share, :>=, 0.90,
      "#{missing.size} recognizable name(s) the mirrors hold are absent from the pool: " +
      missing.first(10).map(&:name).join(", ") +
      " (a Met-only name is provisional — its plate is only knowable at selection time)"
  end

  # Story 0018's E2 found culture-as-artist by sampling, `/qa` found museum
  # placeholders the same way, and both missed the rest: 49 works over 31
  # strings were shipping as live `/artists/:slug` pages — `/artists/india-calcutta`
  # with 5 of them. This is the assertion those two rounds lacked. Narrow on
  # purpose: only a string that IS a place word, so it can be made green by
  # extending the deny-list and cannot fire on a painter named for a place.
  # FOURTH recurrence of one defect: 0018's E2 found culture-as-artist by
  # sampling, `/qa` ISSUE-001 found five museum placeholders the same way,
  # 0019's eng review found 49 works over 31 place strings, and 0019's code
  # review found `/artists/anonymous` live in the re-curated manifest. Every
  # round was a human reading a list. Unlike a place name, the placeholder
  # vocabulary is a small closed set of English words, so this one can be an
  # assertion — and an assertion is the only thing that has not been tried.
  test "no museum placeholder for an unknown maker resolves to an artist page" do
    placeholder = /\A(anonymous|unknown|unidentified|various|not identified|maker unknown|no artist)\b/i
    live = POOL.map { |w| w["artist"] }.compact
               .select { |name| name.match?(placeholder) }
               .select { |name| Painting.artist_slug_for(name).present? }
               .tally

    assert_empty live,
      "a museum's \"we don't know\" marker is shipping as a tappable artist page — " \
      "add it to Painting::NOT_AN_ARTIST"
  end

  test "no artist string that is simply a place name resolves to an artist page" do
    live = POOL.map { |w| w["artist"] }.compact
               .select { |name| Pool::PLACE_WORDS.include?(name.downcase.strip) }
               .select { |name| Painting.artist_slug_for(name).present? }
               .tally

    assert_empty live,
      "these are places, not painters, and each one ships as a live artist page — " \
      "add them to Painting::NOT_AN_ARTIST"
  end

  # Story 0022 Release 2, eng review (outside voice #1). Neither museum's
  # public API carries a subject/genre field — measured live, not assumed —
  # so the only way a CMA or MIA work could carry a genre is a future change
  # accidentally matching on a field those sources don't populate. Reads the
  # committed manifest, the same source Pool::GenreFill writes into, so this
  # is the manifest's own invariant, not a live-DB proxy for it.
  test "no CMA or MIA work carries a genre — neither source's API has one to give it" do
    stray = POOL.select { |w| %w[cma mia].include?(w["source"]) && w["genre"].present? }

    assert_empty stray.map { |w| "#{w['source']}:#{w['source_id']}" },
      "CMA/MIA has no native genre field — a non-nil genre here means something matched " \
      "on a field that was never populated for these sources"
  end

  # Story 0024. `tradition` is a seed-time derivation, not a manifest field
  # (same shape as `period`), so this recomputes it directly from each row's
  # own culture/country/department/artist strings — the manifest's own
  # invariant, not a live-DB proxy for it. One pass over `POOL` feeds both
  # assertions below (simplify: the vocabulary check and the floor check
  # were two independent loops over the same derivation).
  POOL_TRADITIONS = POOL.filter_map do |w|
    value = Pool::Tradition.from_strings(
      culture: w["culture"], country: w["country"], department: w["department"],
      artist: w["artist"], medium: w["medium"]
    )
    [ w, value ] if value
  end.freeze

  # No free-text ever leaks into the facet: every non-nil output must be one
  # of `Pool::Tradition::VALUES`' canonical values (TABLE's rows plus
  # "Ukiyo-e Painting", matched outside TABLE — story 0026).
  test "every derived tradition value is in the canonical vocabulary" do
    canonical = Pool::Tradition::VALUES

    stray = POOL_TRADITIONS.filter_map do |w, value|
      "#{w['source']}:#{w['source_id']} => #{value.inspect}" unless canonical.include?(value)
    end

    assert_empty stray, "every stamped tradition must be a canonical value, never free text"
  end

  # Every canonical value clears the display floor on the committed pool —
  # a value that never renders is a facet in name only (the Jain-bucket
  # regression this story's eng review caught at plan time, before the
  # `gujarat` pattern was restored).
  test "every canonical tradition value clears MIN_FACET_WORKS on the committed pool" do
    counts = POOL_TRADITIONS.each_with_object(Hash.new(0)) { |(_, value), h| h[value] += 1 }
    starved = Pool::Tradition::VALUES.select { |value| counts[value].to_i < Painting::MIN_FACET_WORKS }

    assert_empty starved,
      "these tradition values are in the table but never clear the display floor: #{starved}"
  end

  # Story 0025. Genre's SECOND route: `TitleGenre.infer(title)` fills what
  # museum tags left nil, at seed time — it never writes the manifest, which
  # is why the CMA/MIA invariant above stays true and stays load-bearing.
  # This recomputes the full ladder (manifest tag || title inference) per
  # manifest row, one pass feeding every assertion below — the same shape
  # as POOL_TRADITIONS.
  POOL_GENRES = POOL.filter_map do |w|
    value = w["genre"].presence || Pool::TitleGenre.infer(w["title"])
    [ w, value ] if value
  end.freeze

  # No free-text ever leaks into the facet: both routes map into one
  # canonical vocabulary (plan risk: double-labeling drift — one vocabulary,
  # two routes, so tag "portraits" and title "Portrait of" cannot diverge).
  test "every derived genre value is in the canonical vocabulary, whichever route produced it" do
    canonical = Pool::GenreTerms::DICTIONARY.values | Pool::TitleGenre::TABLE.map(&:first)

    stray = POOL_GENRES.filter_map do |w, value|
      "#{w['source']}:#{w['source_id']} => #{value.inspect}" unless canonical.include?(value)
    end

    assert_empty stray, "every derived genre must be a dictionary value, never free text"
  end

  # The story's coverage claim, pinned so a reseed or a dictionary edit
  # cannot silently regress it. Measured 730 at ship time; pinned at 600 —
  # headroom for audit-driven narrowing, still comfortably above the
  # story's 500 success signal. A red here means the title route lost
  # meaningful reach: re-measure, then either fix the regression or move
  # this pin WITH a Deviations note (0022's falsification idiom).
  test "the genre facet's derived coverage holds the story 0025 floor" do
    assert_operator POOL_GENRES.size, :>=, 600,
      "derived genre coverage fell below the 0025 pin (measured 730 at ship)"
  end

  # Success signal 3 as a test: the one vocabulary addition demand made
  # (0008 N5) actually renders — a value under the display floor is a facet
  # in name only (the Jain-bucket lesson, genre edition).
  test "Flowers clears MIN_FACET_WORKS on the committed pool" do
    flowers = POOL_GENRES.count { |_, value| value == "Flowers" }

    assert_operator flowers, :>=, Painting::MIN_FACET_WORKS,
      "Flowers ships #{flowers} works — below the display floor, it never renders"
  end

  # Story 0026 success signal 3: each new theme value the expansion targeted
  # actually lights on /feed, pinned as data assertions so a future
  # re-curation can't silently unlight a facet (plan step 6).
  #
  # Vanitas is excluded from the hard assertion: measured against the
  # mirrors, only 5 usable candidates exist in all four museums combined
  # (2 of the raw 7 exceed MAX_TITLE) — zero margin for even one dead
  # plate at selection time. A per-theme shortfall here is the plan's own
  # named, accepted outcome ("stock fails adjudication... logged in the
  # pool report, not papered over"), not a bug to gate `bin/ci` on.
  NEW_GENRE_VALUES = %w[Icon Cityscape].freeze
  NEW_TRADITION_VALUES = [ "Ukiyo-e Painting", "Madhubani Painting" ].freeze

  test "every story 0026 genre value clears MIN_FACET_WORKS on the committed pool" do
    counts = POOL_GENRES.each_with_object(Hash.new(0)) { |(_, value), h| h[value] += 1 }
    starved = NEW_GENRE_VALUES.select { |value| counts[value].to_i < Painting::MIN_FACET_WORKS }

    assert_empty starved, "these story 0026 genre values never clear the display floor: #{starved} (#{counts})"
  end

  test "every story 0026 tradition value clears MIN_FACET_WORKS on the committed pool" do
    counts = POOL_TRADITIONS.each_with_object(Hash.new(0)) { |(_, value), h| h[value] += 1 }
    starved = NEW_TRADITION_VALUES.select { |value| counts[value].to_i < Painting::MIN_FACET_WORKS }

    assert_empty starved, "these story 0026 tradition values never clear the display floor: #{starved} (#{counts})"
  end
end
