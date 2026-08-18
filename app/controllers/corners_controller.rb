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

    # Which compass doors are shut, asked of the WALL and not of `@state`.
    #
    # The first version derived this from `@state == :signed_out`, which is a
    # second spelling of "signed in" — and the two disagreed inside one commit.
    # `:shell` is equally unidentified, so `require_reader` bounces Days, Kept
    # and Gallery straight back here; it was rendering four live links that all
    # returned to this page, which is precisely the dead-control loop `locked:`
    # exists to prevent. Measured: 4 links, 0 locked spans.
    #
    # `identified?` is the wall's own predicate, so there is now one definition
    # and any future identity answers it for free.
    @locked = identified? ? [] : helpers.walled_compass_keys

    # Whether the sign-in doors render at all (story 0017 Release 2).
    #
    # A web visitor with no identity always gets them. A registered device gets
    # them only from a shell that carries a VERSION in its user agent, because
    # the version and the auth bridge ship in the same binary — an older shell
    # has no `ASWebAuthenticationSession` behind the button, and a tap would
    # navigate the web view to Google, which answers an embedded view with
    # `403 disallowed_useragent`.
    #
    # This is the whole reason `native_shell_version` exists. Rails deploys in
    # seconds and binaries do not, so the server has to assume every shell in
    # the wild is the old one until it says otherwise.
    #
    # `:shell` — registered nothing yet — gets no doors either. It has no row to
    # claim into and registration retries on the next foreground; "not ready"
    # is a truer thing to show than a door.
    @doors = @state == :signed_out || (@state == :device && bridge_capable_shell?)
  end

  private
    # The cookie is checked before the user agent, deliberately. A shell that
    # registered successfully matches both, and `:device` is the more specific
    # answer — so the cookie wins when it exists and the UA only decides the
    # unregistered case. Written as guard clauses rather than nested ifs
    # because the order is the whole contract.
    def corner_state
      return :account if current_user
      return :device if current_device
      return :shell if native_shell?

      :signed_out
    end
end
