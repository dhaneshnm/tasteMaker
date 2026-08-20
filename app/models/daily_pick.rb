# One painting, one calendar day, one note.
#
# `blurb` is the curator's own writing and is deliberately separate from
# `paintings.description`, which is museum copy. It is optional: a day with no
# note falls back to the museum's text, attributed as the museum's, rather than
# holding the day hostage to a blank field (decisions/0004).
#
#   Aug 1 ✓        Aug 2 ✓        Aug 3 (none)      Aug 4 ✓ queued
#   ├─ pick        ├─ pick        ├─ nothing        ├─ exists in the table
#   └─ shown,      └─ shown,      └─ Aug 2 stays    └─ invisible until the
#      dated Aug 1    dated Aug 2     up, still         Eastern clock reaches
#                                     dated Aug 2       Aug 4
#
# `current` never reaches past today, so the queue can be filled weeks ahead
# without leaking tomorrow's artwork.
class DailyPick < ApplicationRecord
  BLURB_WORDS = (60..180) # calibration target; the admin nudges, never blocks

  belongs_to :painting

  # The admin textarea posts "" when a curator clears it, and a record created
  # without the key stores NULL. One empty is enough — otherwise "how many days
  # ran museum text" has two answers depending on how the day was made.
  normalizes :blurb, with: ->(blurb) { blurb&.strip.presence }

  validates :painting_id, uniqueness: { message: "has already had its day" }
  validates :scheduled_on, presence: true,
    uniqueness: { message: "already has an artwork scheduled" }
  validate :painting_must_have_an_image
  validate :day_must_have_something_to_read

  # A swapped painting or a moved date is a human re-pick — the spacing
  # guarantees `auto_tier` vouches for no longer hold at the new painting or
  # the new date, so the row stops claiming the machine placed it. A blurb
  # edit is not a re-pick: it changes who *speaks* (`hand_written?`), not who
  # *picked* (story 0023 eng review, finding 4 + outside voice O4).
  before_update { self.auto_tier = nil if painting_id_changed? || scheduled_on_changed? }

  scope :published, -> { where(scheduled_on: ..Date.current) }
  scope :from_today, -> { where(scheduled_on: Date.current..) }
  scope :with_artwork, -> { includes(painting: { image_attachment: :blob }) }

  # Below this many days of buffer, both the curator's own queue-depth hint
  # and `/queue-health`'s external monitor call it low — one number, so the
  # two readings of "how many days ahead" can never drift apart (story 0023
  # simplify pass).
  LOW_BUFFER_DAYS = 2

  # The artwork of the day: the most recent pick that has actually arrived.
  # Falls back to the last published day when today was never scheduled.
  #
  # Deliberately not eager-loaded: `includes` is a no-op for a single record,
  # and the daily page revalidates on every visit, so preloading the painting
  # would cost three throwaway queries on each 304.
  def self.current
    published.order(scheduled_on: :desc).first
  end

  # The neighbours a reader walks to. Bounded by `published`, so the walk never
  # steps into the queue and never lands on a day that was skipped: a gap is
  # simply not there, and the next published day is the next step.
  #
  #   Aug 1 ✓ ── Aug 2 ✓ ── (Aug 3 none) ── Aug 4 ✓
  #     └─ next ────┘             next ────────┘
  #
  def previous_published
    self.class.published.where(scheduled_on: ...scheduled_on).order(scheduled_on: :desc).first
  end

  def next_published
    self.class.published.where(scheduled_on: (scheduled_on + 1)..).order(:scheduled_on).first
  end

  # The first day from today forward that has no artwork yet — never a
  # historical gap, never a date that is already taken.
  def self.first_open_date
    taken = from_today.pluck(:scheduled_on)
    date = Date.current
    date += 1 while taken.include?(date)
    date
  end

  # How full the buffer is, from today forward — shared by the admin
  # queue-depth hint and `/queue-health` (story 0023) so "how many days
  # ahead" means the same number in both places the curator and an outside
  # monitor read it.
  def self.days_scheduled_ahead
    from_today.count
  end

  def self.scheduled_through
    from_today.maximum(:scheduled_on)
  end

  # The one predicate "is the queue okay" answers to — both the admin hint
  # and `/queue-health` call this rather than each re-deriving it, so a
  # shared LOW_BUFFER_DAYS number can't paper over two different questions.
  # A prior draft only compared `days_ahead` and let the admin page read
  # "healthy" the moment TODAY itself dropped off the schedule while later
  # days stayed buffered — exactly the state this story exists to catch
  # (code review, adversarial finding #1). `today_scheduled` and
  # `days_ahead` are parameters, not queries, so a caller already holding
  # the data (the admin controller, from its own loaded `@picks`) never
  # pays for a second round trip to ask the question.
  def self.queue_healthy?(today_scheduled:, days_ahead:)
    today_scheduled && days_ahead >= LOW_BUFFER_DAYS
  end

  # Every painting that already has a day, or will once `pick` (if given)
  # saves. `pick&.id` excludes the pick's own existing row so editing it never
  # makes its own painting disappear from its own dropdown. One home for this
  # rule — `selectable_paintings` and `auto_fill!`'s candidate scope both
  # read it, so the day the one-day-per-painting constraint relaxes, it
  # relaxes in one place (story 0023 eng review, finding 5).
  def self.spoken_for(pick = nil)
    where.not(id: pick&.id).select(:painting_id)
  end

  # The paintings a curator can still choose. This mirrors the "one day per
  # painting" rule above, plus whichever painting `pick` already holds so a
  # record never vanishes from its own edit form.
  def self.selectable_paintings(pick = nil)
    Painting.with_attached_image
            .select(:id, :title, :artist, :culture, :dated, :image_url_800, :description)
            .where.not(id: spoken_for(pick))
            .order(:title)
  end

  # The scheduled day immediately before/after `date` — any pick, hand or
  # machine, published or still in the buffer. Distinct from
  # `previous_published`/`next_published` above, which only ever walk
  # published days for the reader-facing archive; these two are the
  # curator's own upcoming schedule, used by `auto_fill!` to keep the
  # culture rule reading the buffer as it fills, not just the public past.
  def self.nearest_scheduled_before(date)
    where(scheduled_on: ...date).order(scheduled_on: :desc).first
  end

  def self.nearest_scheduled_after(date)
    where(scheduled_on: (date + 1)..).order(:scheduled_on).first
  end

  # Machine-picked days are stamped with the tier that filled them — the
  # audit instrument for the spacing prediction (story 0023 decisions/0015).
  # A day always fills: each tier gives up one guarantee the tier before it
  # held, in order, and never invents a rule beyond "any eligible painting".
  #
  #   tier 1: artist ±30d  + culture adjacency     ← the intended policy
  #   tier 2: artist ±30d                          ← culture rule dropped
  #   tier 3: artist ±7d                           ← window shrunk
  #   tier 4: any eligible painting                ← pool nearly spent
  #   (empty at tier 4: pool exhausted → error logged, fill stops; `current`'s
  #    last-published-day fallback is the graceful floor underneath this)
  #
  # `auto_tier` living on the row rather than in a log line is deliberate:
  # Kamal replaces the container on every deploy, so a log-only audit would
  # not survive to the kill review that reads it.
  RELAXATION_TIERS = {
    1 => { artist_window: 30, culture_rule: true },
    2 => { artist_window: 30, culture_rule: false },
    3 => { artist_window: 7,  culture_rule: false },
    4 => { artist_window: nil, culture_rule: false }
  }.freeze

  # Tops the queue up to `horizon` days ahead of today, never touching a day
  # that already has a pick, hand or machine. Idempotent: called again the
  # same day, `first_open_date` already sits at or past the horizon and the
  # loop does nothing.
  def self.auto_fill!(horizon: 7)
    while first_open_date < Date.current + horizon
      break unless fill_one!(first_open_date)
    end
  end

  # Fills a single date, relaxing tier by tier until something validates.
  # Candidates are tried through the model's own validations — the same
  # authority a hand pick answers to — so an unusable candidate is skipped,
  # never force-inserted.
  #
  # `RecordNotUnique` is treated as "already handled", not an error: Solid
  # Queue's recurring executor is enqueue-once, not run-once, so two
  # overlapping runs racing to fill the same date is an expected shape, not
  # a bug to raise on.
  #
  # `daily_picks` carries two unique indexes, not one — `scheduled_on` AND
  # `painting_id` — and a bare rescue can't tell which one just fired. If a
  # concurrent run claimed this *painting* for a *different* date, `date`
  # itself is still open, and returning `true` on the assumption alone would
  # tell the caller this date is filled when nothing was actually saved for
  # it (code review, adversarial finding #2). The `exists?` check is the
  # cheap way to ask which constraint fired: only stop trying this date if
  # something is now actually scheduled on it; otherwise this candidate
  # collided on its painting, and the next one in the tier still might not.
  def self.fill_one!(date)
    RELAXATION_TIERS.each do |tier, rules|
      candidates_for(date, rules).each do |painting|
        pick = new(painting: painting, scheduled_on: date, auto_tier: tier)
        begin
          pick.save!
          Rails.logger.info("DailyPick.auto_fill!: #{date} filled at tier #{tier}") if tier > 1
          return true
        rescue ActiveRecord::RecordNotUnique
          return true if exists?(scheduled_on: date)
          next
        rescue ActiveRecord::RecordInvalid
          next
        end
      end
    end

    Rails.logger.error("DailyPick.auto_fill!: pool exhausted for #{date}")
    false
  end
  private_class_method :fill_one!

  # Every painting `date` could take at this tier, random order. Spoken-for,
  # museum-text-less, and previously-excluded-by-validation paintings never
  # reach `fill_one!`'s save attempt — the cheap SQL filters here exist to
  # narrow the field, not to replace the model's own validations as the
  # authority on what a publishable day is.
  #
  # Artist key: `artist_slug`, falling back to the raw `artist` string when
  # the slug is nil. A slug is nil for every deny-listed placeholder
  # ("China", "Unidentified artist", …, see `Painting::NOT_AN_ARTIST`) — keying
  # on slug alone would silently exempt every placeholder-attributed work
  # from the artist window and let that whole cohort clump (story 0023 eng
  # review, outside voice O3). Only a painting with no artist at all, in
  # either form, is exempt from the rule.
  #
  # Both exclusions below need an explicit `OR <expr> IS NULL`: Rails'
  # `where.not(column: list)` compiles to a bare `NOT IN`, and SQL's NULL
  # semantics make a bare `NOT IN` silently drop every NULL row from the
  # result — which here would wrongly exclude every blank-artist or
  # blank-culture candidate instead of exempting it.
  #
  # Written out at each call site rather than behind a shared helper taking
  # the column expression as a parameter: passing it through a method
  # argument is exactly the shape Brakeman's SQL-injection check can no
  # longer prove is a hardcoded constant, even though both call sites below
  # only ever pass `ARTIST_KEY_SQL` or the literal `"paintings.culture"" —
  # never anything derived from user input (code review). The scanner
  # staying able to verify that by reading the call site, not by trusting a
  # comment, is worth the six duplicated lines.
  ARTIST_KEY_SQL = "COALESCE(NULLIF(paintings.artist_slug, ''), NULLIF(paintings.artist, ''))"

  def self.candidates_for(date, rules)
    scope = Painting.where.not(id: spoken_for).where.not(description: [ nil, "" ])

    if rules[:artist_window]
      window = rules[:artist_window]
      used_keys = joins(:painting)
        .where(scheduled_on: (date - window)..(date + window))
        .pluck(Arel.sql(ARTIST_KEY_SQL))
        .compact
      if used_keys.present?
        scope = scope.where("#{ARTIST_KEY_SQL} NOT IN (?) OR #{ARTIST_KEY_SQL} IS NULL", used_keys)
      end
    end

    if rules[:culture_rule]
      neighbour_cultures = [ nearest_scheduled_before(date), nearest_scheduled_after(date) ]
        .compact.filter_map { |pick| pick.painting.culture.presence }
      if neighbour_cultures.present?
        scope = scope.where("paintings.culture NOT IN (?) OR paintings.culture IS NULL", neighbour_cultures)
      end
    end

    scope.order(Arel.sql("RANDOM()"))
  end
  private_class_method :candidates_for

  def blurb_word_count
    blurb.to_s.split.size
  end

  def published?
    scheduled_on <= Date.current
  end

  # What the day says: the curator's note when there is one, the museum's own
  # copy when there is not. Ask `hand_written?` for whose voice it is — the page
  # attributes museum text rather than passing it off as the editorial voice,
  # and museum copy is clamped where a hand-written note never is.
  def note
    hand_written? ? blurb : painting&.description
  end

  def hand_written?
    blurb.present?
  end

  # Deleting this pick is a re-roll, not a veto: the date is still in the
  # future and the machine placed it, so `auto_fill!` refills it at the next
  # run rather than leaving a gap (story 0023, outside voice O7).
  def reroll_on_delete?
    !published? && auto_tier.present?
  end

  private

  # The note is optional, but a day with nothing to read at all is not a day.
  # If the curator writes nothing, the painting has to bring its own words.
  def day_must_have_something_to_read
    return if blurb.present? || painting&.description.present?

    errors.add(:blurb, "is needed — this painting has no museum text to fall back on")
  end

  # A day with no picture is not a day worth publishing. Catching it here keeps
  # the broken-image state on the public page nearly unreachable.
  def painting_must_have_an_image
    return if painting.blank?
    errors.add(:painting, "has no usable image") unless painting.display_image?
  end
end
