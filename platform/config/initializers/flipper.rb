# frozen_string_literal: true

# Feature flags, managed at /admin/flags (FeatureFlag). Check one with `Flipper.enabled?(:key, current_user)`.
# Users are actors by public_id (User#flipper_id). The groups below are the ones the admin page can turn on.
Rails.application.configure do
  # Flipper memoizes per request either way; preloading would add a query to every page, flag or not.
  config.flipper.preload = false
end

Rails.application.config.after_initialize do
  FeatureFlag::GROUPS.each_key do |name|
    Flipper.register(name) { |actor| actor.respond_to?(:flipper_group?) && actor.flipper_group?(name) }
  end
end
