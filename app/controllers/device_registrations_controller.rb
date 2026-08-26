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
# The gate itself — secret check, forgery skip, rate limit, the device-token
# shape guard — moved to NativeEndpoint (story 0010 eng review + /code-review):
# PushRegistrationsController answers the same shape of caller and needed the
# exact same lines.
class DeviceRegistrationsController < ApplicationController
  include NativeEndpoint

  def create
    head :unauthorized and return unless valid_app_secret?

    token = params.require(:device_token)
    head :bad_request and return unless valid_device_token?(token)

    Device.find_or_create_by_digest!(token)

    cookies.signed.permanent[:device] = {
      value: token, httponly: true, same_site: :lax,
      secure: Rails.env.production?
    }
    head :no_content
  end
end
