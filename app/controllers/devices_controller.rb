# The exit door for the identity that had none (story 0016).
#
# `AccountsController#destroy` returns early `unless current_user`, so before
# this class the DEFAULT state of the iOS shell — a registered device whose
# reader never signed in — could not delete its row or the works it had kept.
# The privacy policy promises in-app deletion; that promise was false for the
# majority of readers, and a false promise in a filed policy is the failure this
# controller exists to prevent.
#
#   signed-in user  ──> already served by accounts#destroy, redirected here-out
#   registered device ──> destroy Device + its favorites, forget the cookie
#   neither ──────────> home, same as the account door
#
# Symmetric with the account door on purpose: no soft delete, no grace period,
# no email — there is still no mailer. The confirm dialog on the collection page
# names what it destroys before it runs.
class DevicesController < ApplicationController
  def destroy
    # An account holder hitting this has an account door of their own, and
    # deleting the device out from under a signed-in session would strand a
    # reader whose keeps live somewhere else entirely. Mirror of the guard in
    # accounts#destroy, pointing the other way.
    device = current_device unless current_user
    return redirect_to(root_path, status: :see_other) unless device

    # Favorites are keyed by digest, not by a foreign key with a dependent
    # option, so the rows do not follow the Device row on their own. Through the
    # same `collected_by` scope favorites#index reads, so "this device's keeps"
    # has one definition rather than two that can drift apart.
    Favorite.collected_by(device.token_digest).delete_all
    device.destroy

    # The cookie outlives the row it pointed at. Left in place, the next request
    # looks up a digest with no Device behind it, `current_device` returns nil,
    # and the reader is bounced to sign-in with no explanation — deleted, then
    # locked out. Deleting it lands them on the public landing page instead,
    # which is where a reader with no identity belongs.
    cookies.delete(:device)
    redirect_to root_path, status: :see_other
  end
end
