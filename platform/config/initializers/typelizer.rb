# frozen_string_literal: true

# Generates app/frontend/types/serializers/* from app/serializers and app/frontend/routes/* from config/routes.rb.
# Runs automatically in development (middleware); CI checks the output is committed and current.
Typelizer.configure do |config|
  config.dirs = [ Rails.root.join("app/serializers") ]
  config.output_dir = Rails.root.join("app/frontend/types/serializers")
  config.types_import_path = "@/types"
  config.null_strategy = :nullable
  config.verbatim_module_syntax = true

  config.routes.enabled = true
  config.routes.output_dir = Rails.root.join("app/frontend/routes")
  config.routes.exclude = ->(route) {
    route[:controller].to_s.match?(%r{\A(rails/|active_storage/|action_mailbox/|mission_control/|turbo/)}) ||
      route[:controller].to_s == "slack" ||
      route[:path].start_with?("/rails", "/up")
  }
end
