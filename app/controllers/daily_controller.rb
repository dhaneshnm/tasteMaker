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

    # The count is in the key because the page depends on it: the date is only a
    # link once there is more than one published day. Without it, a curator
    # backfilling a *past* day leaves `current` unchanged, and every returning
    # visitor keeps a 304 with no way into the archive that just appeared.
    fresh_when(etag: [ @pick, DailyPick.published.count ],
      last_modified: @pick.updated_at, public: true)
    response.cache_control[:no_cache] = true
  end
end
