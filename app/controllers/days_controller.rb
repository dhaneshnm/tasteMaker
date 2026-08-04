class DaysController < ApplicationController
  # The days behind you.
  #
  # Everything here keys on the pick the front door is showing, never on the
  # calendar: `DailyPick.current` holds the previous day over when today has no
  # pick, so on a gap day "today" and "the page at /" are different things.
  def index
    @picks = DailyPick.published.with_artwork.order(scheduled_on: :desc)
    @current = DailyPick.current

    # The key covers the picks AND the paintings the rows render — title, artist
    # and image live on another table with their own timestamps, so a re-seed
    # that corrects a title would otherwise keep serving the old one.
    # `to_f`, not the Time: interpolating a Time into an ETag renders it at second
    # precision, so a title edited in the same second as the last request would
    # produce an identical key and a stale 304.
    fresh_when(etag: [ @picks.cache_key_with_version,
      Painting.where(id: @picks.map(&:painting_id)).maximum(:updated_at)&.to_f ], public: true)
    response.cache_control[:no_cache] = true

    @months = @picks.group_by { |pick| pick.scheduled_on.beginning_of_month }
  end

  # A queued day, a skipped day, and a date that is not a date all 404 alike:
  # telling them apart would tell a guesser which dates are in the queue.
  def show
    date = Date.iso8601(params[:date])
    return redirect_to(root_path) if date == DailyPick.current&.scheduled_on

    @pick = DailyPick.published.with_artwork.find_by!(scheduled_on: date)
    @chrome = :archive

    # `stale?`, not `fresh_when`: this action renders explicitly, and fresh_when
    # already sends the 304 itself, so the render would be a second response.
    response.cache_control[:no_cache] = true
    render template: "daily/show" if stale?(@pick, public: true)
  rescue Date::Error
    raise ActiveRecord::RecordNotFound
  end
end
