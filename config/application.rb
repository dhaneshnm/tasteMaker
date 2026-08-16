require_relative "boot"

require "rails"
# Pick the frameworks you want:
require "active_model/railtie"
require "active_job/railtie"
require "active_record/railtie"
require "active_storage/engine"
require "action_controller/railtie"
# require "action_mailer/railtie"
# require "action_mailbox/engine"
# require "action_text/engine"
require "action_view/railtie"
require "action_cable/engine"
require "rails/test_unit/railtie"

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module Tondo
  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 8.1

    # One value per deploy, folded into the ETag by ApplicationController.
    #
    # Without it, a change to the TEXT of a template does not move the ETag on
    # `/` or `/days` — those keys are model rows plus the importmap and
    # stylesheet digests — so a returning reader revalidates, gets a 304, and
    # keeps the old words forever. `REVISION` is written by the Dockerfile at
    # image build time; "dev" locally, where there are no returning readers and
    # the value only has to be stable.
    config.x.revision =
      Rails.root.join("REVISION").then { |f| f.exist? ? f.read.strip.presence : nil } || "dev"

    # Please, add to the `ignore` list any other `lib` subdirectories that do
    # not contain `.rb` files, or that should not be reloaded or eager loaded.
    # Common ones are `templates`, `generators`, or `middleware`, for example.
    # `middleware` is ignored because `config/initializers/omniauth.rb` requires
    # it explicitly and inserts it into the stack at boot — a constant the
    # middleware stack holds forever must not be one Zeitwerk can reload out
    # from under it.
    config.autoload_lib(ignore: %w[assets tasks middleware])

    # Configuration for the application, engines, and railties goes here.
    #
    # These settings can be overridden in specific environments using the files
    # in config/environments, which are processed later.
    #
    # The day rolls over at midnight Eastern for everyone. One clock, no
    # per-visitor timezone logic: `DailyPick.current` is only correct if
    # `Date.current` means "today in New York".
    config.time_zone = "America/New_York"

    # Rescued exceptions go back through the router, so an error page is a normal
    # request rendering the normal layout. Without this the reader lands on
    # `public/404.html` — the one screen in the product that is not on linen, and
    # the one the design test cannot see because it is a static file outside the
    # asset pipeline. See specs/0004-linen-404/.
    config.exceptions_app = routes
    # config.eager_load_paths << Rails.root.join("extras")

    # No libvips/imagemagick on this machine; image dimensions come from MIA
    # metadata, so skip Active Storage's analyzer pass entirely.
    config.active_storage.analyzers = []
  end
end
