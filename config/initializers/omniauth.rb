# The account key's two doors (story 0015, decisions/0011). OAuth only — no
# password strategy exists here and none will.
#
# Secrets follow the curator idiom (admin/base_controller.rb): Rails
# credentials first, ENV fallback for local and CI. Absent both, the provider
# is configured with blanks and the first real request fails at Google/Apple's
# door rather than ours — acceptable, because the sign-in fragment is the only
# thing that links here and local dev exercises mocked auth (test mode) or
# Google with real dev credentials.
#
# The Apple flow's fragility is documented in specs/0015-the-two-keys/plan.md
# (eng review A2): Apple returns the callback as a cross-site POST, the gem is
# pinned exactly in the Gemfile, and the flow is verified on the deployed
# domain — a green local suite cannot exercise that failure.
Rails.application.config.middleware.use OmniAuth::Builder do
  provider :google_oauth2,
    Rails.application.credentials.dig(:google, :client_id) || ENV["GOOGLE_CLIENT_ID"],
    Rails.application.credentials.dig(:google, :client_secret) || ENV["GOOGLE_CLIENT_SECRET"],
    scope: "email,profile"

  provider :apple,
    Rails.application.credentials.dig(:apple, :client_id) || ENV["APPLE_CLIENT_ID"],
    "",
    scope: "email name",
    team_id: Rails.application.credentials.dig(:apple, :team_id) || ENV["APPLE_TEAM_ID"],
    key_id: Rails.application.credentials.dig(:apple, :key_id) || ENV["APPLE_KEY_ID"],
    pem: Rails.application.credentials.dig(:apple, :private_key) || ENV["APPLE_PRIVATE_KEY"]
end

# GET /auth/:provider is a CSRF hole omniauth-rails_csrf_protection exists to
# close; POST-only is the half this line owns.
OmniAuth.config.allowed_request_methods = %i[post]
