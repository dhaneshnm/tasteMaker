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

    # The key is the pick and its painting, and nothing else. It used to carry
    # `DailyPick.published.count` as well, because the masthead date was only a
    # link once a second day existed — so a curator backfilling a past day
    # changed this page without changing this pick, and returning visitors would
    # have kept a 304 with no way into the archive that had just appeared.
    #
    # Story 0012 deleted that condition. The compass links to the archive from
    # every screen, always, so nothing on this page depends on how many days
    # exist and the count in the key would only be invalidation with no reader
    # behind it. The painting stays in the key because the page renders its
    # title, artist and image.
    fresh_when(etag: [ @pick, @pick.painting ],
      last_modified: @pick.updated_at, public: true)
    response.cache_control[:no_cache] = true
  end
end
