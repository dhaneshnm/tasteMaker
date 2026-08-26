# The gate the shell's native URLSession calls ride through — no DOM, no
# form, no session to carry a CSRF token. Shared by DeviceRegistrationsController
# (story 0015) and PushRegistrationsController (story 0010) so the secret check
# and the rate-limit store exist in exactly one place (eng review finding 3).
# The 0023 DRY-reversal (duplicated NOT-IN-OR-NULL SQL kept apart for
# Brakeman's sake) does not apply here — no interpolated SQL, nothing for the
# scanner to lose track of.
module NativeEndpoint
  extend ActiveSupport::Concern

  # Explicit store, not the Rails default (eng review A1, story 0015): the
  # default is :memory_store in production and :null_store in test, so an
  # unpinned rate_limit test is a silent no-op. One instance, shared by every
  # controller that includes this concern — `rate_limit`'s own
  # controller/action-scoped cache key namespaces the endpoints automatically,
  # so sharing the store costs nothing.
  RATE_LIMIT_STORE = ActiveSupport::Cache::MemoryStore.new

  # Scoped to :create — the convention both including controllers share is
  # that the native, secret-gated door is always named `create`.
  # PushRegistrationsController's `destroy` is a DIFFERENT door: a walled,
  # forgery-protected web Turbo form (the DevicesController idiom), not a
  # native caller, and must not have the wall or CSRF skipped out from
  # under it.
  included do
    skip_before_action :require_reader, only: :create
    skip_forgery_protection only: :create
    rate_limit to: 10, within: 1.minute, store: RATE_LIMIT_STORE, only: :create
  end

  class_methods do
    # Credentials first, ENV for local and CI — the curator idiom. Public and
    # on the class for the same reason Admin::BaseController.expected_password
    # is: the suite must present whatever this machine is configured with, not
    # a string it hard-codes and hopes still wins the `||` (bug, 2026-08-15).
    def expected_app_secret
      Rails.application.credentials.dig(:tondo, :app_secret).presence ||
        ENV["TONDO_APP_SECRET"]
    end
  end

  private
    # Blank secret fails closed rather than open.
    def valid_app_secret?
      expected = self.class.expected_app_secret
      return false if expected.blank?

      ActiveSupport::SecurityUtils.secure_compare(
        request.headers["X-Tondo-App"].to_s, expected
      )
    end
end
