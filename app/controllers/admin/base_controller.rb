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

    # Public and on the class because the suite has to knock with whatever this
    # machine is actually configured with. `test/test_helper.rb` used to type
    # ENV["CURATOR_PASSWORD"] itself, which was right until credentials grew a
    # `curator:` entry (a6dba37) and started winning the `||` — every admin test
    # 401'd from that commit on, and a clone with no master.key still passed,
    # which is why it went unnoticed (bug, 2026-08-15).
    def self.expected_password
      Rails.application.credentials.dig(:curator, :password).presence ||
        ENV["CURATOR_PASSWORD"]
    end

    private

    def authenticate_curator
      authenticate_or_request_with_http_basic("Tondo") do |username, password|
        expected_password = self.class.expected_password
        next false if expected_password.blank?

        ActiveSupport::SecurityUtils.secure_compare(username.to_s, USERNAME) &
          ActiveSupport::SecurityUtils.secure_compare(password.to_s, expected_password)
      end
    end
  end
end
