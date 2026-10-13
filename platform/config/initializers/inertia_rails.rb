# frozen_string_literal: true

InertiaRails.configure do |config|
  config.version = ViteRuby.digest
  # History encryption needs a secure context; development is sometimes served over plain HTTP on a LAN/Tailscale IP.
  config.encrypt_history = !Rails.env.development?
  config.always_include_errors_hash = true
  config.use_script_element_for_initial_page = true
  config.use_data_inertia_head_attribute = true
  config.layout = "inertia"
end
