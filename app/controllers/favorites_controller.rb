# Keeping a work, letting it go, and the room the kept ones live in.
#
# The whole design turns on one constraint: `/` is `Cache-Control: public`,
# and production runs behind Thruster's HTTP cache. So the public HTML has to
# be byte-identical for every reader, and everything personal lives behind one
# private fragment. Identity comes from ApplicationController since story 0015
# — a signed-in web reader (favorites.user_id) or a registered device
# (collector_digest); the wall runs first, so a signed-out web visitor never
# reaches these actions, and their lazy frame request bounces while the
# default glyph simply stays on screen:
#
#   GET /                              GET /collection/42/control
#     public, no-cache, ETag             private, no-store, Vary: Cookie
#     identical for everyone             this reader only
#     never touches the cookie           renders this reader's state
#          │                                      ▲
#          └── <turbo-frame src=…> ───────────────┘   POST/DELETE reply into
#              (static markup + the                   the same frame
#
class FavoritesController < ApplicationController
  # `#control` answers an unidentified caller too (story 0017), and it has to.
  #
  # The keep frame on `/` is EAGER — `daily/_day.html.erb` explains why — and
  # its default content is the resting keep mark that stops the rail from being
  # a 44px hole while the fetch lands. Turbo replaces a frame's children with
  # whatever matching frame it finds in the response, so bouncing this GET to a
  # page that has no `keep_<id>` frame writes "Content missing" over that
  # placeholder and the mark vanishes from the cached page.
  #
  # It used to bounce to `/`, which happens to carry a `keep_<id>` frame for
  # today's painting, so Turbo found one and swapped in that page's identical
  # placeholder. That was an accident, not a design, and story 0017's retarget
  # to `/you` stopped it paying. `dynamic_type_test.rb:75` caught it.
  #
  # Answering directly leaks nothing: with no identity there is no `kept` and no
  # count, so the response is the outline glyph and nothing else — byte-for-byte
  # what the publicly cached page already carries. The wall exists to stop the
  # collection being an anonymous public utility, and a constant is not one.
  # Writes stay walled; this is the read of a null state.
  skip_before_action :require_reader, only: :control

  # Never cached anywhere, by anyone — a class-wide rule rather than a line at the
  # top of each action, so a fifth action cannot ship a storable per-visitor
  # response by forgetting it.
  before_action :no_store
  before_action :set_painting, except: :index

  # The reader's own room.
  def index
    favorites = reader_favorites
                        .includes(painting: { image_attachment: :blob })
                        .order(created_at: :desc).to_a

    # index_by, not a find inside the loop: the template would otherwise grow an
    # O(n²) scan that reads like reuse.
    picks = DailyPick.published
                     .where(painting_id: favorites.map(&:painting_id))
                     .index_by(&:painting_id)

    # The pick the front door is showing. Without it every row takes the dated
    # branch of day_link_path and the row for today's work 301s on every tap —
    # the exact wart story 0003 removed. Gap days come free: DailyPick.current
    # holds the previous pick over, and the helper keys on the pick, not the date.
    @current = DailyPick.current
    @rows = favorites.map { |favorite| [ favorite.painting, picks[favorite.painting_id] ] }
  end

  # The per-visitor fragment. It used to be where the browser cookie got
  # minted; since story 0015 identity arrives before this controller does
  # (session or device cookie), so this only reads.
  def control
    render_control
  end

  def create
    Favorite.create!(reader_identity_attributes.merge(painting: @painting))
    render_control(kept: true, autofocus: true)
  rescue ActiveRecord::RecordNotUnique, ActiveRecord::RecordInvalid
    # Already kept — two taps that raced, or two tabs. Not an error: the reader
    # asked for it to be kept and it is kept. Both classes are live: the model's
    # uniqueness validation raises RecordInvalid on an ordinary second tap, and
    # only a genuine race past that read reaches the index and raises NotUnique.
    #
    # No `kept:` here, unlike the success path. Uniqueness is the only reachable
    # failure today, so `true` would be right — but it would be an assumption
    # about which validation fired, and the whole point of this branch is that a
    # write did NOT happen. Let the database say what is stored. `autofocus`
    # stays: the reader still pressed a button, and focus still has to come back.
    render_control(autofocus: true)
  end

  def destroy
    # destroy_all, not delete_all: it costs one indexed row read, and it keeps
    # this path inside the callback chain. The saving was a single SELECT on at
    # most one row; the cost of the faster version is that the day it grows an
    # `after_destroy` — a counter, a tombstone — both unkeep paths skip it with
    # no test failing.
    reader_favorites.where(painting: @painting).destroy_all

    # Two callers, two right answers.
    #
    # The day page's toggle submits from inside the keep frame and wants the
    # fragment back. The collection's orphan Remove is a page-level form — a row
    # cannot nest a form inside its own <a>, so that button sits outside any
    # frame — and Turbo Drive refuses a plain 200 for those ("Form responses must
    # redirect to another location"). Answering both with a fragment left the row
    # on screen and the count unchanged while the row was already gone from the
    # table, and a second tap deleted nothing and errored again.
    #
    # It is the only control an orphaned work has, so it gets the redirect.
    if turbo_frame_request?
      render_control(kept: false, autofocus: true)
    else
      redirect_to collection_path, status: :see_other
    end
  end

  private
    def set_painting
      @painting = Painting.find(params[:painting_id])
    end

    # `kept:` is passed by a write that already knows the answer, so it does not
    # re-ask; every other caller reads it.
    #
    # Both reads are index-only aggregates against `collector_digest`, which is
    # the leading column of the unique index — constant cost whatever the size of
    # the collection. An earlier version pulled the whole id set with one `pluck`
    # to save a round trip; that traded two constant probes for transferring and
    # allocating every painting_id the reader has ever kept, on the endpoint the
    # keep frame hits on every single day-page view.
    def render_control(kept: nil, autofocus: false)
      # No identity, no collection — the null state, which is the same mark the
      # cached page already drew. Only `#control` can reach this; every write
      # still runs behind the wall, so `reader_favorites` below always has one
      # of the two keys.
      unless identified?
        return render partial: "favorites/control", locals: {
          painting: @painting, autofocus: false, kept: false, count: 0
        }
      end

      collection = reader_favorites

      render partial: "favorites/control", locals: {
        painting: @painting, autofocus: autofocus,
        kept: kept.nil? ? collection.exists?(painting: @painting) : kept,
        count: collection.count
      }
    end

  # `reader_favorites` and `reader_identity_attributes` moved to
  # ApplicationController in story 0017, when `/you` became the second caller.
  # The wall still runs before every action in THIS controller, so one of the
  # two keys always exists here — the `identified?` guard those methods now
  # carry is for `CornersController`, which skips the wall.
end
