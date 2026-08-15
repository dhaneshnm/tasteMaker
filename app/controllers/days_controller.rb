class DaysController < ApplicationController
  # The days behind you.
  #
  # Everything here keys on the pick the front door is showing, never on the
  # calendar: `DailyPick.current` holds the previous day over when today has no
  # pick, so on a gap day "today" and "the page at /" are different things.
  def index
    picks = DailyPick.published

    # Behind the wall since story 0015: still ETag'd, no longer `public` —
    # see ApplicationController#private_revalidate.
    private_revalidate

    # Aggregates first, then bail: the page revalidates on every visit, and
    # loading every pick, painting, attachment and blob only to discard them on
    # a 304 is the bulk of the work. The key covers the picks AND the paintings
    # the rows render — title, artist and image live on another table with their
    # own timestamps, so a re-seed that corrects a title must break the key.
    return unless stale?(etag: [ picks.cache_key_with_version, paintings_touched_at(picks) ])

    @picks = picks.with_artwork.order(scheduled_on: :desc).load
    @current = @picks.first
    @months = @picks.group_by { |pick| pick.scheduled_on.beginning_of_month }
  end

  # A queued day, a skipped day, and a date that is not a date all 404 alike:
  # telling them apart would tell a guesser which dates are in the queue.
  def show
    date = begin
      Date.iso8601(params[:date])
    rescue Date::Error
      raise ActiveRecord::RecordNotFound
    end

    @current = DailyPick.current
    return redirect_to(root_path) if date == @current&.scheduled_on

    @pick = DailyPick.published.find_by!(scheduled_on: date)
    @chrome = :archive

    # `stale?`, not `fresh_when`: this action renders explicitly, and fresh_when
    # already sends the 304 itself, so the render would be a second response.
    # The painting is in the key for the same reason it is on the list.
    private_revalidate
    render template: "daily/show" if stale?(etag: [ @pick, @pick.painting ],
      last_modified: @pick.updated_at)
  end

  private
    # One aggregate over the paintings these picks point at, without loading
    # either side. `.to_f` because interpolating a Time into an ETag renders it
    # at second precision, and a title edited in the same second as the previous
    # request would produce an identical key.
    def paintings_touched_at(picks)
      Painting.where(id: picks.select(:painting_id)).maximum(:updated_at)&.to_f
    end
end
