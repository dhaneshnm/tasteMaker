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

    raise NotFound unless matches.exists?

    # Aggregates first, then bail — the rule DaysController#index states for
    # the same reason: a 304 must not pay for loading attachments and blobs
    # it is about to discard (eng review E-A2/E-A3). `cache_key_with_version`
    # is that controller's own idiom (`picks.cache_key_with_version`,
    # `days_controller.rb:19`) — one aggregate query covering both count and
    # freshness, not two.
    return unless stale?(etag: matches.cache_key_with_version)

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
