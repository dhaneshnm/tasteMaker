# The dead man's switch (story 0021). The 7-day buffer removes the
# curator's daily reason to open the admin — which removes the only failure
# detector the manual regime had. Error tracking is still unwired (session
# gate 6), so this is the minimal stand-in: an external uptime monitor
# pings this URL, and a dead scheduler alerts days before the front door
# would ever actually go stale.
#
#   request ──> QueueHealthController ──> 200 today scheduled, >=2 days buffer
#                    │                └──> 503 otherwise
#                    │
#                    └── inherits ActionController::Base, NOT
#                        ApplicationController — no wall, no browser gate
#                        (PagesController set this precedent; an uptime
#                        monitor is not a modern browser and has no reader
#                        identity to check).
class QueueHealthController < ActionController::Base
  def show
    response.cache_control.replace(no_store: true)

    today_scheduled = DailyPick.exists?(scheduled_on: Date.current)
    days_ahead = DailyPick.days_scheduled_ahead
    scheduled_through = DailyPick.scheduled_through

    if today_scheduled && days_ahead >= DailyPick::LOW_BUFFER_DAYS
      render plain: "ok — scheduled through #{scheduled_through} (#{days_ahead} days ahead)"
    else
      render plain: "queue low — today #{today_scheduled ? "scheduled" : "NOT scheduled"}, " \
                     "#{days_ahead} day(s) ahead", status: :service_unavailable
    end
  end
end
