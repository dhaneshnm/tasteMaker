# The reader's own corner (story 0017). One page, four states, no fragment.
#
# This is the second unwalled reader surface after `/`, and it is unwalled for
# a specific reason: it holds the sign-in doors, and `require_reader` sends
# every cookieless visitor here. A wall in front of the door out of the wall is
# a locked room.
#
#   request ──> corners#show ──┬── session[:user_id] → User?      :account
#                              ├── device cookie → Device?        :device
#                              ├── shell UA, no device row        :shell
#                              └── none of the above              :signed_out
#
# WHY FOUR AND NOT THREE. `SessionsController#control` collapsed the middle two
# into one `:device` branch and rendered an EMPTY frame for it, which was safe
# precisely because an empty frame says nothing. As a whole page it has to say
# something, and the two are not the same reader:
#
#   :device  a registered install. "Kept on this phone" is true, it has rows,
#            and Delete this device's data destroys something.
#   :shell   the app before registration landed — first launch in airplane
#            mode, or a failed POST /device/registrations. It has no Device
#            row, so `current_device` is nil, `reader_favorites` would raise on
#            it, and `DevicesController#destroy` answers its delete button with
#            a silent redirect (devices_controller.rb:23-24). It keeps nothing
#            yet and it must not be told it does.
#
# NO SIGN-IN DOORS IN THE SHELL, in this release or any other where the native
# transport is absent. Google answers an embedded web view with
# `403 disallowed_useragent`, so a provider button inside WKWebView is a dead
# control that renders Google's error page in a calm art app. The user-agent
# half of the check is what covers `:shell`, which has no cookie to check.
class CornersController < ApplicationController
  # This is how a reader with no identity GETS one. Walling it would lock the
  # door from the inside — the same reason SessionsController skips it.
  skip_before_action :require_reader

  # Private and uncacheable, always. This page renders `button_to` forms whose
  # CSRF tokens live in the session, so it is the one page in this story allowed
  # to write a cookie — which is exactly why it must never be stored. Class-wide
  # rather than per-action, the FavoritesController idiom, so a second action
  # added here cannot ship a storable per-visitor response by forgetting a line.
  before_action :no_store

  def show
    @state = corner_state

    # Only the two identified states have rows to count. `:shell` has no Device
    # row and `:signed_out` has no identity at all; asking either for a count
    # is the nil dereference this guard exists to prevent, on the page a
    # bounced visitor lands on.
    @kept_count = identified? ? reader_favorites.count : 0
  end

  private
    # The user agent is checked before the cookie, deliberately. A shell that
    # registered successfully matches both, and `:device` is the more specific
    # answer — so the cookie wins when it exists and the UA only decides the
    # unregistered case. Written as one expression rather than nested ifs
    # because the order is the whole contract.
    def corner_state
      return :account if current_user
      return :device if current_device
      return :shell if native_shell?

      :signed_out
    end
end
