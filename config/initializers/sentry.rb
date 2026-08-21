# Error tracking — session gate 6 (decisions/0018). Rails credentials first,
# ENV fallback for local and CI, same idiom as OmniAuth (config/initializers/
# omniauth.rb). No DSN configured: Sentry no-ops rather than raising, so a
# clone with no credentials still boots.
Sentry.init do |config|
  config.dsn = Rails.application.credentials.dig(:sentry, :dsn).presence || ENV["SENTRY_DSN"]
  config.enabled_environments = %w[production]
  config.traces_sample_rate = 0.0
end
