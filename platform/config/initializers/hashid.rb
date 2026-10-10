# frozen_string_literal: true

# Stripe-style public IDs (usr_Ab12Cd). Set HASHID_SALT in production so IDs survive a secret_key_base rotation.
Hashid::Rails.configure do |config|
  config.salt = ENV.fetch("HASHID_SALT") { Rails.application.secret_key_base }
  config.min_hash_length = 6
  config.override_find = false
  config.override_to_param = false
end
