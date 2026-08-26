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
    head :bad_request and return unless device_token.is_a?(String) && device_token.length <= 64

    mode = params[:mode]
    head :bad_request and return unless %w[enroll refresh].include?(mode)

    disabling = mode == "refresh" &&
      ActiveModel::Type::Boolean.new.cast(params[:enabled]) == false

    apns_token = params[:apns_token]
    unless disabling
      head :bad_request and return unless apns_token.is_a?(String) && apns_token.match?(APNS_TOKEN_FORMAT)
    end

    digest = Device.digest(device_token)
    device = mode == "enroll" ? find_or_create_device(digest) : Device.find_by(token_digest: digest)
    head :no_content and return if device.nil?

    if disabling
      device.update_column(:apns_token, nil)
    elsif mode == "enroll" || device.apns_token.present?
      device.update_column(:apns_token, apns_token)
    end
    # else: mode == "refresh", no existing token, not disabling — leave nil.
    # This is the opt-out-reversal guard (outside voice #1): a device that
    # left on the web must stay left through every later cold launch.

    head :no_content
  end

  # Clears by TOKEN VALUE, not by row: a device wipe re-mints the Keychain
  # UUID and can leave a stale second Device row holding the same
  # apns_token, and row-scoped opt-out would keep knocking that phone
  # (eng review, outside voice #6).
  def destroy
    device = current_device
    head :no_content and return if device&.apns_token.blank?

    Device.where(apns_token: device.apns_token).update_all(apns_token: nil)
    head :no_content
  end

  private
    def find_or_create_device(digest)
      Device.find_or_create_by!(token_digest: digest)
    rescue ActiveRecord::RecordNotUnique
      Device.find_by!(token_digest: digest)
    end
end
