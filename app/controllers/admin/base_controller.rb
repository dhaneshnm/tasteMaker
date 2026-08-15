module Admin
  # Everything under /admin is the curator's desk: one human, HTTP basic auth.
  #
  # The password comes from Rails credentials (`curator: password:`) and falls
  # back to CURATOR_PASSWORD for local and CI runs. When neither is set the
  # check fails closed rather than erroring.
  class BaseController < ApplicationController
    USERNAME = "curator"

    # The whole namespace, not one controller: the admin layout is where the CSRF
    # meta tag lives now, and a controller added here later must inherit it rather
    # than fall back to the reader layout that deliberately has none.
    layout "admin"

    # The curator's key is basic auth, not a Google account (story 0015).
    # Anonymous /admin answers 401 with a challenge, never a redirect to the
    # sign-in fragment — the skip must come before authenticate_curator runs.
    skip_before_action :require_reader

    before_action :authenticate_curator

    private

    def authenticate_curator
      authenticate_or_request_with_http_basic("Tondo") do |username, password|
        expected_password = curator_password
        next false if expected_password.blank?

        ActiveSupport::SecurityUtils.secure_compare(username.to_s, USERNAME) &
          ActiveSupport::SecurityUtils.secure_compare(password.to_s, expected_password)
      end
    end

    def curator_password
      Rails.application.credentials.dig(:curator, :password).presence ||
        ENV["CURATOR_PASSWORD"]
    end
  end
end
