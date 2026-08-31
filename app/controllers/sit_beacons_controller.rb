# The gate's tally mark (story 0032, eng OV6). `sendBeacon` from the front
# door: `shown` when a gate is displayed, `completed` when a minute runs out.
#
# Identity-free on purpose: no reader key, no session read or write, no
# cookie in the response — the success signal (completed/shown ≥ 20%) must
# never cost the calm page a tracking conversation. CSRF protection is
# skipped because there is nothing to forge: the only effect any caller can
# have is adding 1 to a public aggregate, and the event name is constrained
# to two values at the routing layer before it gets here.
class SitBeaconsController < ApplicationController
  skip_before_action :require_reader
  skip_forgery_protection
  before_action :no_store

  def create
    SitCounter.bump!(params[:event])
    head :no_content
  end
end
