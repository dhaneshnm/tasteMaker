class Painting < ApplicationRecord
  has_one_attached :image

  # The four collections the pool is drawn from (story 0013). Names carry their
  # own article because they are read mid-sentence — "From the Cleveland Museum
  # of Art" — and two of the four want one while two do not.
  SOURCES = {
    "mia" => { name: "the Minneapolis Institute of Art", url: "https://collections.artsmia.org" },
    "met" => { name: "The Metropolitan Museum of Art",   url: "https://www.metmuseum.org/art/collection" },
    "aic" => { name: "the Art Institute of Chicago",     url: "https://www.artic.edu/collection" },
    "cma" => { name: "the Cleveland Museum of Art",      url: "https://www.clevelandart.org/art/collection" }
  }.freeze

  # Story 0018. Names that show up as a literal `artist` value but are a
  # curator field, not a hand that painted anything — the four museums put the
  # culture, country, or a placeholder in the same column when no artist is
  # credited.
  #
  # Deny-listed by exact string, not by shape. Single-word suppression was
  # tried and rejected (eng review E2): it also silences Govardhan, Chokha,
  # Fayzullah, Basavana and Purkhu, real Mughal and Pahari painters with 2-4
  # works each in this pool.
  #
  # The five placeholder strings below (found by /qa, 2026-08-19, browsing
  # /feed) are the second shape of the same defect: E2's review query asked
  # only "is `artist` a literal country/culture name", so `Painting.where(
  # artist: "Unidentified artist")` — a museum's own "we don't know" marker —
  # was never checked and rendered as a live, tappable artist page. Exhaustive
  # for the pool as measured: `Painting.where.not(artist: [nil, ""]).distinct.
  # pluck(:artist).select { |a| a =~ /unidentified|unknown|anonymous|various|
  # not identified|maker unknown/i }` returns exactly these five, 9 works
  # total, none previously in this list.
  # Third recurrence of one defect, and the first time it was measured rather
  # than sampled (story 0019, eng review finding 3). E2 found culture strings by
  # asking "is `artist` a literal country name"; `/qa` found museum placeholders
  # the same way; both were spot checks. Sweeping the manifest and all four
  # mirrors with `Pool.place_shaped?` — the same `PLACES` vocabulary
  # `Pool.region_for` uses — returns **102 distinct strings over 580 rows**, of
  # which 49 works over 31 strings were already live `/artists/:slug` pages in
  # production: `/artists/india-calcutta` with 5 works, `/artists/probably-mexico`
  # with 5, `/artists/persia-iran` with 5.
  #
  # Still an EXACT-string list, not a shape rule. E2 settled that and the sweep
  # confirms it: "Mewar Stipple Master" and "Ugolino da Siena" are painters named
  # for places, and any rule that suppressed the strings below would suppress
  # them too. `pool:report` now prints both the single-word slugs and every
  # place-shaped string so the next one surfaces for a human pass before seeding
  # instead of after — which is the forcing function the first two rounds lacked.
  NOT_AN_ARTIST = [
    # Museum placeholders: "we don't know" in the artist column.
    #
    # "Anonymous" is the sixth, and it is the FOURTH time this defect has been
    # found by hand rather than by a check (0018 E2 → /qa ISSUE-001 → 0019's
    # eng review → 0019's code review, which caught `/artists/anonymous` live
    # in the re-curated manifest). The placeholder shape is a closed set of
    # English words, so it is now an assertion in `pool_quota_test` rather
    # than a list somebody has to remember to read.
    "Unidentified", "Unknown", "Anonymous", "Artist unknown", "Unidentified artist",
    "Various artists",
    # A country or culture standing in for a hand.
    #
    # Teotihuacan, Chancay and Gujarati came in with the re-curation and are
    # not in `Pool::PLACES` — that vocabulary maps works to REGIONS, so
    # widening it to catch culture names would change `region_for` and the
    # range bars with it. They are caught the way every other one is: the
    # report lists them, a human reads it.
    "China", "Japan", "Islamic", "Tibet", "India", "Korea", "Nepal", "Egypt",
    "Teotihuacan", "Chancay", "Gujarati",
    # Story 0026 audit: AIC's own convention for many Native American works
    # is a tribal-nation attribution, not an individual maker — "Cheyenne"
    # (aic/182617, a painted tipi curtain) and "Lakota" (aic/122887, a Sun
    # Dance scene) are the nation credited as maker, same shape as "China"
    # or "Japan" above, not a person named Cheyenne or Lakota.
    "Cheyenne", "Lakota",
    "Italy", "Ethiopia", "Sweden", "United States", "Mughal",
    "Italian", "French", "German", "Spanish", "Dutch", "Flemish", "British", "English", "Austrian",
    "Ancient Egyptian", "Probably Mexico", "Mewar school", "Painter: Mughal school",
    "Northern Europe (active England)", "Egypt; or Mesopotamia (Iraq)",
    "Workshop: Mewar (Udaipur) workshop", "Possibly Persia (Iran); or Turkey",
    # The Met's form for an anonymous work of a known school.
    "French Painter", "Russian Painter", "British Painter", "German Painter", "Spanish Painter",
    "North Italian Painter", "Northern French Painter", "Italian (Florentine) Painter",
    "Spanish (Catalan) Painter", "British School", "French School",
    # Region-with-subregion, the Cleveland and Minneapolis form.
    "Persia (Iran)", "Mexico (Mexico City)", "Italy (Pompeii)", "Austria (Tyrol)",
    "India (Calcutta)", "India (Rajasthan)", "India (Madhya Pradesh)", "India (Kishangarh)",
    "India (Jaipur, Rajasthan)", "India (Bikaner)", "India (Kangra)", "India (Marwar)",
    "India (Deccan)", "India (Mewar)", "India (Gujarat)", "India (Thanjavur, Tamil Nadu)",
    "India (Chambra)"
  ].freeze

  # Museum copy arrives as HTML from half the collections — Cleveland ships
  # <em>/<i> title italics, Minneapolis ships whole Google Docs paste-ups
  # (<span style>, <font face>, <b id="docs-internal-guid-…">) — and the page
  # renders `description` as one escaped paragraph, so anything that survives
  # ingest is read by the visitor as a literal "<em>" (bug, 2026-08-15).
  #
  # Stripped, not sanitized: keeping <em> for one italic would mean calling
  # html_safe on third-party copy, and <p>/<br> cannot legally nest inside the
  # single clamped <p> the wall label already is.
  #
  # Block tags become a space FIRST — strip_tags alone closes the gap and gives
  # "prosperity.Waldo sold", which is worse than the tag it removed.
  NBSP = /&nbsp;|\u00A0/
  BLOCK_TAG = %r{</?(?:p|br|div|li|tr|h[1-6]|blockquote)\b[^>]*>}i

  # Two passes, because the copy carries both live tags and tags the museum
  # escaped before storing them — AIC ships a literal "&lt;BIG&gt;" — and one
  # pass leaves behind whichever kind it did not start with. Stable at two:
  # `plain_text(plain_text(x)) == plain_text(x)` for every row in the pool, and
  # the model test pins that.
  def self.plain_text(html)
    return nil if html.blank?

    text = html.to_s
    2.times do
      text = ActionView::Base.full_sanitizer.sanitize(text.gsub(NBSP, " ").gsub(BLOCK_TAG, " "))
      text = CGI.unescapeHTML(text.to_s)
    end
    text.squish.presence
  end

  # On the model, not in each source adapter: every write path goes through
  # here — four adapters, `db/seeds.rb`, and whatever the fifth museum turns out
  # to be — and a source added later cannot reintroduce this by forgetting a
  # call (R1).
  normalizes :description, with: ->(html) { plain_text(html) }

  # Museum object ids collide across museums, so identity is the pair.
  validates :source, presence: true, inclusion: { in: SOURCES.keys }
  validates :source_id, presence: true, uniqueness: { scope: :source }
  validates :title, presence: true

  scope :feed_ordered, -> { order(:feed_order, :id) }

  # Story 0022 Release 1 (genre, period), extended by story 0024 (tradition).
  # Each is a nullable string column carrying the canonical DISPLAY value
  # ("19th century", "Portrait", "Mughal Painting") — never a slug. `genre`
  # has no data source until Release 2; `period` and `tradition` are written
  # at seed time by `Pool::PeriodBucket` and `Pool::Tradition`. This is the
  # canonical URL/query-param order — `resolve_active` and every `feed_path`
  # call read it — not a display order any more: story 0027 moved the filter
  # off `/feed` onto `/feed/index`, whose own section order is
  # `Painting::FacetVoice::LABEL_ORDER` (tradition, subject, century), a
  # deliberately different array answering a different question.
  FACETS = %i[period genre tradition].freeze

  # A value with fewer works than this renders no wing at all — the
  # story's own rule ("a facet with 1 work behind it is a dead end dressed
  # as a feature") applied to real numbers, twice: 0022 shipped 5 as a
  # placeholder ("provisional; Release 2 re-decides") and never re-decided
  # it; six values with 6-15 works rendered as wings under it (story 0027,
  # `decisions/0017`). 16 is a measured threshold, not a round number — it
  # is the smallest floor that both drops every one of those six AND keeps
  # Persian & Islamic Painting (19 works, the pool's second-most-searched
  # tradition, `user-research/0008`); 20 would have dropped it by accident.
  # `pool_quota_test.rb` pins the exact set of canonical values this leaves
  # below the floor, by name — a value that starves or recovers without
  # that list changing is exactly the drift this constant existing as a
  # provisional guess for two stories let happen once already.
  MIN_FACET_WORKS = 16

  # Every distinct value a facet carries, with its work count. Resolution
  # (`resolve_facet_slug`) works against every value here, not just the ones
  # that clear the display floor — a deep link a reader already has (or a
  # value that later drops below the floor) never silently 500s, it just
  # stops being offered as a button.
  #
  # `scope:` (story 0027) — a passed relation to count within, instead of the
  # whole table. Existing callers (`lib/pool/report.rb`, `lib/pool/
  # title_genre.rb`) pass nothing and get today's pool-wide behaviour; the
  # index's `index_for` below is the only caller that passes one, and it is
  # what lets a facet be counted "within the scope of the OTHER active
  # facets" without a second query method.
  def self.facet_counts(facet, scope: all)
    raise ArgumentError, "unknown facet: #{facet}" unless FACETS.include?(facet)

    scope.where.not(facet => nil).group(facet).count
  end

  # The subset of `facet_counts` that clears `MIN_FACET_WORKS`, ordered for
  # display: numeric for period ("10th century" must sort before "9th
  # century", which string order gets backwards), alphabetical for every
  # other facet (genre, tradition). `counts:` lets a caller pass an
  # already-fetched `facet_counts(facet)` result (0024 code review: the
  # controller resolves a slug AND lists display values for the same facet
  # in one request — without this, that was two independent `GROUP BY`
  # queries per facet, the exact duplicate-`COUNT(*)` shape story 0020
  # already fixed once for `Painting.count`, just not here).
  def self.displayed_facet_values(facet, counts: facet_counts(facet))
    values = counts.select { |_, count| count >= MIN_FACET_WORKS }.keys
    facet == :period ? values.sort_by { |value| value[/\d+/].to_i } : values.sort
  end

  # The URL half of the one reduction function this facet system has (the
  # `artist_slug_for` lesson: one function, used by both the writer and the
  # reader, so the two can never disagree).
  def self.facet_slug(value)
    value.to_s.parameterize
  end

  # A URL slug back to the canonical value it names, or nil for a blank,
  # unknown, or stale slug — never a 500, and never a guess. Reads distinct
  # values directly rather than through `facet_counts` (story 0027 eng
  # review): resolution needs every value that exists, floor or no floor,
  # and a plain `SELECT DISTINCT` is one query cheaper per facet than a
  # `GROUP BY … COUNT` when nothing downstream wants the count.
  def self.resolve_facet_slug(facet, slug)
    return nil if slug.blank?

    where.not(facet => nil).distinct.pluck(facet).find { |value| facet_slug(value) == slug }
  end

  # The AND-scope for a hash of `facet => value-or-nil` (story 0027). One
  # builder, used by `PaintingsController#index`, `index_for`, and
  # `plate_for` below — three independent copies of `active.each { |f, v|
  # scope = scope.where(f => v) if v }` is exactly the kind of drift 0022's
  # own `@filter_params` bug (`5d90908`) came from.
  def self.scoped_to(active)
    where(active.compact)
  end

  # The index's own facet listing (story 0027): for every facet, every value
  # that co-occurs with the OTHER active facets, counted within THAT scope —
  # switching Mughal to Pahari is a replace, not an AND, so tradition's own
  # counts are never filtered by tradition. Floored at `MIN_FACET_WORKS`,
  # except the active value itself, which stays in its own row even if a
  # stale deep link left it under the floor — down to and including zero
  # (a two-facet URL that itself ANDs to no matches, e.g. `?tradition=
  # korean-painting&genre=nude`): `counts[active[facet]]` is simply absent
  # from that facet's own GROUP BY then, and `.to_i` on nil is 0. Left as a
  # real "here, 0 works" row rather than special-cased into `/feed`'s
  # `.page--empty` treatment (`/code-review`, considered) — the index
  # degrades gracefully around it: sections for facets that are NOT the
  # zero-count one stay populated (scoped by the working facets only), and
  # `wings.html.erb`'s summary line already prints the true "· 0 works"
  # count at the top of the page before a reader reaches any section, so
  # nothing is hidden and nothing needs a second empty-state idiom. Ordered
  # for display: numeric for period, heaviest wing first for everything
  # else — the index is a map, not an alphabet.
  def self.index_for(active)
    FACETS.index_with do |facet|
      counts = facet_counts(facet, scope: scoped_to(active.except(facet)))
      rows = counts.select { |_, count| count >= MIN_FACET_WORKS }
      rows = rows.merge(active[facet] => counts[active[facet]].to_i) if active[facet] && !rows.key?(active[facet])

      facet == :period ? rows.sort_by { |value, _| value[/\d+/].to_i } : rows.sort_by { |_, count| -count }
    end
  end

  # The work whose picture stands for one value of the index (story 0027) —
  # the first work, AMONG THE FIRST FIVE in curation order (not an unbounded
  # scan — `/code-review` flagged the doc claiming otherwise), within the
  # SAME scope `index_for` counted that value in (the other active facets),
  # that actually has a picture to show. `display_image?`, not `image.
  # attached?` alone (eng review 2.2): every test-created and fixture
  # painting in this suite carries `image_url_800` and no attachment, so
  # the narrower predicate made every plate in the test suite the "no face"
  # case. `with_attached_image` avoids a second query per candidate for the
  # attachment check `display_image?` and `artwork_src` both make. Five
  # candidates without a picture in a row is not observed in the committed
  # pool (measured 2026-08-21); if a reseed ever makes it common, the fix is
  # a wider limit, not a redesign.
  def self.plate_for(facet, value, scope:)
    scope.where(facet => value).with_attached_image.feed_ordered.limit(5).find(&:display_image?)
  end

  # The museums actually in the pool, heaviest first. The gallery's closing line
  # credits these rather than a hard-coded list, so it stays true after a reseed
  # changes the mix (story 0013).
  def self.represented_sources
    group(:source).order(count_all: :desc).count.keys.filter_map { |key| SOURCES[key] }
  end

  # Serve the locally stored copy when present; fall back to the museum CDN
  # so the feed still works before `db:seed` finishes downloading images.
  def display_image?
    image.attached? || image_url_800.present?
  end

  def source_name = SOURCES.dig(source, :name)
  def source_url  = SOURCES.dig(source, :url)

  # Stable across reseeds, unique across museums — the feed anchors on it.
  def dom_key = "#{source}_#{source_id}"

  def artist_display
    artist.presence || culture.presence || "Unknown artist"
  end

  # The slug an artist string resolves to, or nil when it must never carry a
  # link: blank, a `NOT_AN_ARTIST` culture string, or a name that
  # transliterates to nothing at all (an OCR-shaped artifact — `parameterize`
  # on punctuation alone returns ""). One function, so `artist_path` is never
  # built with an empty segment (`UrlGenerationError`), and the migration
  # backfill and this row's own write path read the same implementation
  # (eng review E1/T12).
  def self.artist_slug_for(artist)
    name = artist.to_s.strip
    # `casecmp?`, not `.include?` — found by /code-review: a differently-cased
    # duplicate of an already-known placeholder ("CHINA", "unidentified
    # artist") would otherwise slip the deny-list on a future reseed. The
    # list itself stays as-written case (it is also the display fallback
    # elsewhere); only the comparison folds case.
    return nil if name.blank? || NOT_AN_ARTIST.any? { |denied| denied.casecmp?(name) }

    name.parameterize.presence
  end

  before_save { self.artist_slug = self.class.artist_slug_for(artist) }

  # The heading for an artist page, computed over the artist strings the page
  # is already holding (never re-queried — the caller has the rows loaded).
  # Among every distinct string, the one with the most accented characters
  # wins — an accent is information and its absence is loss — then the more
  # frequent spelling, then alphabetical, for a result with no ties in the
  # pool as measured (eng review E4). "Most frequent" alone titled the
  # 9-work flagship page "Paul Cezanne" over "Paul Cézanne".
  def self.canonical_artist_name(names)
    names.tally.min_by { |name, count| [ -accent_count(name), -count, name ] }&.first
  end

  # Counts diacritic letters, not any non-ASCII character — found by
  # /code-review: a curly quote or em dash (this pool's own museum-paste-up
  # artifacts, see `plain_text` above) is non-ASCII but not an accent, and
  # counting it could tip the tie-break on punctuation rather than the
  # genuine diacritic the rule is about.
  def self.accent_count(string)
    string.to_s.each_char.count { |char| char.ord > 127 && char.match?(/\p{L}/) }
  end

  def meta_line
    [ dated.presence, medium.presence ].compact.join(" — ")
  end

  def credit_line
    [ creditline.presence, accession_number.presence ].compact.join(" · ")
  end

  def alt_text
    "#{title} — #{artist_display}"
  end

  # Museum titles run long. Past this the daily page steps the type down
  # rather than truncating — a title is never cut. A class method too: the
  # artist page's heading is a bare string, not a Painting, and needs the
  # same threshold (story 0018) — one comparison, not two copies of it.
  LONG_TITLE = 60

  def self.long_title?(string)
    string.to_s.length > LONG_TITLE
  end

  def long_title?
    self.class.long_title?(title)
  end
end
