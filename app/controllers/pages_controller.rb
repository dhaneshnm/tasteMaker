# The two pages Apple opens without an account (story 0016).
#
# App Store Connect has a mandatory privacy policy URL and a mandatory support
# URL. Both are fetched by strangers — App Review, Apple's crawler, a reader
# tapping through from the listing — none of whom has a session or a device
# cookie, and a legal page behind a login is a 5.1.1 rejection.
#
#   request ──> PagesController ──> render ──> 200, always, for everyone
#                    │
#                    └── inherits ActionController::Base, NOT
#                        ApplicationController, so there is no wall to pass
#                        and no browser gate to satisfy
#
# WHY NOT `skip_before_action`. That was the plan and half of it cannot work.
# `require_reader` skips cleanly; `allow_browser` does not. Rails installs it as
# an ANONYMOUS lambda (actionpack, allow_browser.rb):
#
#     before_action -> { allow_browser(versions: versions, block: block) }
#
# A lambda has no filter name, so `skip_before_action :allow_browser` raises
# ArgumentError at class definition — and `raise: false`, the thing you reach
# for next, is a silent no-op that leaves the gate armed while reading as though
# it were disarmed. Measured against production before this class existed:
# Safari 14 got 406, curl and an empty UA and AppleBot all got 200. Rails only
# blocks agents it can IDENTIFY as old, so Apple's crawler was never the victim
# here — a reader on old hardware was, which is persona 2 exactly.
#
# Inheriting outside the chain makes both exemptions structural. There is
# nothing to skip, so there is nothing for a later edit to delete by accident.
#
# WHAT IS GIVEN UP, and why it is free: ApplicationController's `etag` blocks.
# Those exist for pages that key a conditional GET on model rows via
# `fresh_when` (`/` and `/days`), which is the hole commit ae742dc fell into —
# body changed, ETag did not. These pages have no `fresh_when`, so Rails'
# automatic body-digest ETag is computed from the thing that actually varies.
class PagesController < ActionController::Base
  layout "application"

  # `here: nil` in both views is load-bearing: ApplicationHelper#
  # compass_destinations raises on any key outside COMPASS_KEYS, and these two
  # pages are not compass destinations. They are reached from the App Store
  # listing and from the coda on the collection and archive screens.

  def privacy
    @updated_on = POLICY_UPDATED_ON
  end

  def support
  end

  # The date the policy last changed, shown at its head. A hand-maintained
  # constant rather than a file mtime: a whitespace commit is not a policy
  # change, and a reader deciding whether to re-read needs the date the WORDS
  # changed. Bump it when the text does.
  #
  # `test/integration/privacy_claims_test.rb` is the other half of this — it
  # fails the build when the policy's "nothing is watching you" claim stops
  # being true, which is the day this date needs bumping and the App Store
  # privacy labels need refiling.
  POLICY_UPDATED_ON = Date.new(2026, 8, 21)
end
