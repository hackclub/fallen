# frozen_string_literal: true

module SentryContext
  extend ActiveSupport::Concern

  included do
    before_action :set_sentry_context
  end

  private

  def set_sentry_context
    Sentry.set_user(id: current_user.public_id, email: current_user.email, username: current_user.display_name) if current_user
    Sentry.set_tags(controller: controller_path, action: action_name)
  end
end
