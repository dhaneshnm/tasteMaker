# The device key's front desk (story 0015). The shell POSTs its Keychain UUID
# here on launch with the app secret; the answer is a signed permanent cookie
# every later WKWebView request rides through the wall.
#
# Threat model, stated honestly (decisions/0011, Q3): the secret ships inside
# the IPA and is extractable by anyone who unpacks it. This stops open and
# anonymous access — curl without effort, scrapers, accidental indexing — not
# reverse engineering. The named upgrade path is App Attest on this same
# endpoint; the shape (register → cookie) would not change.
class DeviceRegistrationsController < ApplicationController
  # This endpoint is how a device GETS past the wall.
  skip_before_action :require_reader

  # Native URLSession caller: no DOM, no form, no session to carry a token.
  skip_forgery_protection

  # Explicit store (eng review A1): the limiter is backed by the controller
  # cache store, which is the default in-process memory store in production
  # (config/environments/production.rb keeps the "durable alternative" line
  # commented out) and :null_store in test — so without pinning, the limit is
  # per-process in prod and a silent no-op in every test. Per-process is
  # accepted on one box; a no-op test is not.
  RATE_LIMIT_STORE = ActiveSupport::Cache::MemoryStore.new
  rate_limit to: 10, within: 1.minute, store: RATE_LIMIT_STORE

  def create
    head :unauthorized and return unless valid_app_secret?

    token = params.require(:device_token)
    begin
      Device.find_or_create_by!(token_digest: Digest::SHA256.hexdigest(token))
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

  private
    # Credentials first, ENV for local and CI — the curator idiom. Blank
    # secret fails closed rather than open.
    def valid_app_secret?
      expected = Rails.application.credentials.dig(:tondo, :app_secret).presence ||
        ENV["TONDO_APP_SECRET"]
      return false if expected.blank?

      ActiveSupport::SecurityUtils.secure_compare(
        request.headers["X-Tondo-App"].to_s, expected
      )
    end
end
