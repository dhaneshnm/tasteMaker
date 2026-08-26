# The device key's front desk (story 0015). The shell POSTs its Keychain UUID
# here on launch with the app secret; the answer is a signed permanent cookie
# every later WKWebView request rides through the wall.
#
# Threat model, stated honestly (decisions/0011, Q3): the secret ships inside
# the IPA and is extractable by anyone who unpacks it. This stops open and
# anonymous access — curl without effort, scrapers, accidental indexing — not
# reverse engineering. The named upgrade path is App Attest on this same
# endpoint; the shape (register → cookie) would not change.
#
# The gate itself — secret check, forgery skip, rate limit — moved to
# NativeEndpoint (story 0010 eng review): PushRegistrationsController answers
# the same shape of caller and needed the same three lines.
class DeviceRegistrationsController < ApplicationController
  include NativeEndpoint

  def create
    head :unauthorized and return unless valid_app_secret?

    token = params.require(:device_token)
    # A UUID is 36 chars; a nested-hash param or a megabyte of junk is neither
    # (security review F5: `params.require` happily returns a Parameters hash,
    # and hexdigest raising TypeError on it is a 500 where a 400 belongs).
    # No length floor — `params.require` already rejects blank.
    head :bad_request and return unless token.is_a?(String) && token.length <= 64
    begin
      Device.find_or_create_by!(token_digest: Device.digest(token))
    rescue ActiveRecord::RecordNotUnique
      # Two cold launches racing — same idempotent outcome, same idiom
      # favorites#create uses.
    end

    cookies.signed.permanent[:device] = {
      value: token, httponly: true, same_site: :lax,
      secure: Rails.env.production?
    }
    head :no_content
  end
end
