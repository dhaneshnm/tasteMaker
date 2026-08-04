# Keeping a work, letting it go, and the room the kept ones live in.
#
# The whole design turns on one constraint: `/` and `/days` are
# `Cache-Control: public`, and production runs behind Thruster's HTTP cache. So
# the public HTML has to be byte-identical for every reader, and everything
# personal lives behind one private fragment:
#
#   GET /                              GET /collection/42/control
#     public, no-cache, ETag             private, no-store, Vary: Cookie
#     identical for everyone             this reader only
#     never touches the cookie           issues the cookie if absent
#          │                                      ▲
#          └── <turbo-frame src=…> ───────────────┘   POST/DELETE reply into
#              (static markup, lazy)                  the same frame
#
class FavoritesController < ApplicationController
  before_action :set_painting, except: :index

  # The reader's own room. Never cached anywhere, by anyone.
  def index
    no_store

    favorites = Favorite.collected_by(collector_digest)
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
    @kept_count = favorites.size
  end

  # The per-visitor fragment, and the only place the cookie is issued.
  def control
    no_store
    render_control
  end

  def create
    no_store
    Favorite.create!(collector_digest: collector_digest, painting: @painting)
    render_control(autofocus: true)
  rescue ActiveRecord::RecordNotUnique, ActiveRecord::RecordInvalid
    # Already kept — two taps that raced, or two tabs. Not an error: the reader
    # asked for it to be kept and it is kept.
    render_control(autofocus: true)
  end

  def destroy
    no_store
    Favorite.collected_by(collector_digest).where(painting: @painting).destroy_all
    render_control(autofocus: true)
  end

  private
    COOKIE = :collector

    def set_painting
      @painting = Painting.find(params[:painting_id])
    end

    def render_control(autofocus: false)
      render partial: "favorites/control",
        locals: { painting: @painting, kept: kept?, count: kept_count, autofocus: autofocus }
    end

    def kept?
      Favorite.collected_by(collector_digest).exists?(painting: @painting)
    end

    def kept_count
      Favorite.collected_by(collector_digest).count
    end

    # Private and uncacheable, always. `Vary: Cookie` is belt to the no-store
    # braces: nothing should store these, and nothing should reuse one reader's
    # copy for another if it does.
    def no_store
      response.cache_control.replace(private: true, no_store: true)
      response.headers["Vary"] = "Cookie"
    end

    # The reader's identity is established when the fragment is READ, not when
    # they first keep something.
    #
    # Minting on the first write looked cheaper and had a hole: two tabs, a
    # brand-new reader, neither holding a cookie, both tapped. Each request mints
    # a different token, each writes a row, the browser keeps whichever
    # Set-Cookie lands last, and one row is orphaned under a token nobody holds.
    # The unique index does not catch it — it is scoped to the digest, and the
    # digests differ. Both tabs would say "Kept" and one work would never appear.
    #
    # Only ever called from this controller. No public page reads or writes this
    # cookie, because a Set-Cookie on a `public` response is one reader's
    # identity sitting in a shared cache waiting for the next one.
    def collector_token
      cookies.signed[COOKIE].presence || mint_collector_token
    end

    def mint_collector_token
      SecureRandom.base58(24).tap do |token|
        cookies.permanent.signed[COOKIE] = {
          value: token, httponly: true, same_site: :lax, secure: Rails.env.production?
        }
      end
    end

    # What the table sees. Never the token.
    def collector_digest
      @collector_digest ||= Digest::SHA256.hexdigest(collector_token)
    end
end
