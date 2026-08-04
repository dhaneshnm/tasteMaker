class DailyController < ApplicationController
  # The front door. One artwork, one note, one day.
  #
  # Caching: `public, no-cache` + an ETag means every request revalidates and
  # gets a cheap 304 when nothing changed. A fresh `max-age` would have been
  # wrong here — public caches do not revalidate while fresh, so a typo fix in
  # today's blurb would have stayed invisible until the cache expired.
  def show
    @pick = DailyPick.current
    return render :empty if @pick.nil?

    @chrome = :front_door
    # Counted once, then used twice: for the key and for the decision it covers.
    # The date is only a link once there is more than one published day, so
    # without the count in the key a curator backfilling a *past* day leaves
    # `current` unchanged and every returning visitor keeps a 304 with no way
    # into the archive that just appeared. The painting is in the key because
    # the page renders its title, artist and image.
    @published_count = DailyPick.published.count

    fresh_when(etag: [ @pick, @pick.painting, @published_count ],
      last_modified: @pick.updated_at, public: true)
    response.cache_control[:no_cache] = true
  end
end
