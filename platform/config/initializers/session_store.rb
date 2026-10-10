# frozen_string_literal: true

# Keep people signed in across browser restarts.
Rails.application.config.session_store :cookie_store, key: "_fallen_session", expire_after: 3.months
