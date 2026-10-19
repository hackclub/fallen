require_relative "boot"

require "rails/all"

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module Fallen
  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 8.1

    # lib/ is autoloaded (SlackBot::*, Constraints::*). Keep non-Ruby dirs ignored.
    config.autoload_lib(ignore: %w[assets tasks])

    config.time_zone = "UTC"

    # No encrypted credentials: every secret comes from ENV (dotenv locally). Generate production keys with
    # `bin/rails db:encryption:init` and set the three ACTIVE_RECORD_ENCRYPTION_* variables.
    config.active_record.encryption.primary_key = ENV.fetch("ACTIVE_RECORD_ENCRYPTION_PRIMARY_KEY") { "fallen-local-primary-key" if Rails.env.local? }
    config.active_record.encryption.deterministic_key = ENV.fetch("ACTIVE_RECORD_ENCRYPTION_DETERMINISTIC_KEY") { "fallen-local-deterministic-key" if Rails.env.local? }
    config.active_record.encryption.key_derivation_salt = ENV.fetch("ACTIVE_RECORD_ENCRYPTION_KEY_DERIVATION_SALT") { "fallen-local-salt" if Rails.env.local? }

    # Jobs run through Solid Queue in every environment (bin/jobs). Tests use the inline test adapter.
    config.active_job.queue_adapter = :solid_queue

    config.generators do |g|
      g.helper false
      g.assets false
      g.stylesheets false
      g.test_framework :test_unit, fixture: true
    end

    # So a fix typed into a production console shows up in the change history as one.
    console { PaperTrail.request.controller_info = { source: "console" } }
  end
end
