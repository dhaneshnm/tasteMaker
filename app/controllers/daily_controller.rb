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

    fresh_when(@pick, public: true)
    response.cache_control[:no_cache] = true
  end
end
