# Everything Tondo holds by one hand (story 0018). Reached only from a linked
# artist name on `/feed` or `/days/:date` — see `shared/_artist_line` — never
# from the compass and never self-linking.
class ArtistsController < ApplicationController
  # A different class than `ActiveRecord::RecordNotFound`, on purpose.
  # `ErrorsController::MESSAGES` keys off the exact exception class, and a
  # bare `RecordNotFound` here would answer an unknown slug with "There was no
  # artwork on that day." (eng review D6).
  class NotFound < ActiveRecord::RecordNotFound; end

  def show
    matches = Painting.where(artist_slug: params[:slug])

    # Behind the wall since story 0015: still ETag'd, no longer `public` —
    # see ApplicationController#private_revalidate. Same contract as `/days`.
    private_revalidate

    # One query, not two: `exists?` then `cache_key_with_version` measured at
    # two separate SQL round trips (found by /code-review — the comment here
    # used to claim parity with `DaysController#index`'s single aggregate,
    # which was wrong). `pick` with both aggregates in one SELECT covers
    # existence and freshness together.
    count, latest = matches.pick(Arel.sql("COUNT(*), MAX(updated_at)"))
    raise NotFound if count.zero?

    # Aggregates first, then bail — the rule DaysController#index states for
    # the same reason: a 304 must not pay for loading attachments and blobs
    # it is about to discard (eng review E-A2/E-A3).
    return unless stale?(etag: [ count, latest ])

    @paintings = matches.with_attached_image.feed_ordered.to_a
    # Computed from the rows already loaded above, not a second query —
    # `matches` and `@paintings` are the identical row set.
    @heading = Painting.canonical_artist_name(@paintings.map(&:artist))
    @life_date = uniform_life_date(@paintings)
  end

  private
    # Shown under the heading only when every work agrees — a mix of dates or
    # formats belongs to no single fact worth stating there.
    def uniform_life_date(paintings)
      dates = paintings.filter_map { |painting| painting.life_date.presence }.uniq
      dates.first if dates.one?
    end
end
