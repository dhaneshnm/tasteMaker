# The push opt-in's front desk (story 0010). Two callers, two auth models,
# one controller because both concern the same row's apns_token:
#
#   shell (native URLSession) ──▶ POST create  ──▶ NativeEndpoint-gated,
#                                                    same shape as
#                                                    DeviceRegistrationsController
#   web (Turbo form on /you)  ──▶ DELETE destroy ──▶ walled, forgery-protected,
#                                                     the DevicesController idiom
#
# `create` carries a `mode` because the shell calls this same endpoint from
# two different moments that must NOT behave the same way:
#
#   mode=enroll   the opt-in tap. find_or_create on the digest (a
#                 revoked/wiped Device row must not 500 — same idempotent
#                 philosophy as DeviceRegistrationsController) and sets the
#                 token unconditionally.
#   mode=refresh  launch healing. iOS authorization stays `.authorized`
#                 forever once granted — nothing client-side learns that the
#                 reader opted out on the web — so refresh updates a token
#                 ONLY where one is already present. Without this split, the
#                 very next cold launch silently re-enrolls every web
#                 opt-out (eng review, outside voice #1 — the single most
#                 load-bearing fix in this story).
#   refresh with enabled=false clears the token: the shell learned from iOS
#   Settings that the reader denied notifications, so the toggle on /you
#   stops lying (outside voice #8). No apns_token is required on this branch
#   — the shell sends none.
class PushRegistrationsController < ApplicationController
  include NativeEndpoint

  APNS_TOKEN_FORMAT = /\A\h{16,200}\z/

  def create
    head :unauthorized and return unless valid_app_secret?

    device_token = params.require(:device_token)
    head :bad_request and return unless valid_device_token?(device_token)

    mode = params[:mode]
    head :bad_request and return unless %w[enroll refresh].include?(mode)
    enrolling = mode == "enroll"

    disabling = !enrolling && ActiveModel::Type::Boolean.new.cast(params[:enabled]) == false

    apns_token = params[:apns_token]
    unless disabling
      head :bad_request and return unless apns_token.is_a?(String) && apns_token.match?(APNS_TOKEN_FORMAT)
    end

    device = enrolling ? Device.find_or_create_by_digest!(device_token) : Device.find_by(token_digest: Device.digest(device_token))
    head :no_content and return if device.nil?

    if disabling
      Device.clear_apns_token!(device.apns_token) if device.apns_token.present?
    elsif (enrolling || device.apns_token.present?) && device.apns_token != apns_token
      device.update_column(:apns_token, apns_token)
    end
    # else: mode == "refresh", no existing token, not disabling — leave nil.
    # This is the opt-out-reversal guard (outside voice #1): a device that
    # left on the web must stay left through every later cold launch.

    head :no_content
  end

  # Redirects rather than `head :no_content` (found by /qa, real bug: a
  # 204 is Turbo Drive's own "nothing to render" signal, so a Turbo-
  # intercepted `button_to` submit left the stale ON button on screen even
  # though the DELETE had already cleared the token server-side). The
  # DevicesController idiom, not reinvented — see its own `redirect_to`.
  def destroy
    Device.clear_apns_token!(current_device.apns_token) if current_device&.apns_token.present?

    redirect_to corner_path, status: :see_other
  end
end
