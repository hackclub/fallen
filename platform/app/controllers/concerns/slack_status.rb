# frozen_string_literal: true

# What the pages need to know about Slack before letting someone write: projects and journals are posted as them.
module SlackStatus
  extend ActiveSupport::Concern

  private

  def slack_props
    {
      configured: SlackMessaging.configured?,
      oauth_available: SlackMessaging.oauth_configured?,
      connected: current_user.slack_connected?,
      linked: current_user.slack_id.present?
    }
  end
end
