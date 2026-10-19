# Rewrites a project's anchor message after its title or description changes on the web, as whoever posted it.
class UpdateProjectOnSlackJob < ApplicationJob
  queue_as :slack
  retry_on Slack::Web::Api::Errors::TooManyRequestsError, wait: :polynomially_longer, attempts: 5

  def perform(project)
    return if project.discarded? || !project.slack_linked? || !SlackMessaging.configured? || !(project.slack_posted_by_bot? || project.user.slack_connected?)

    SlackMessaging.update(project.user, channel: project.slack_channel_id, ts: project.slack_thread_ts, by_bot: project.slack_posted_by_bot, **SlackMessages.project_anchor(project))
  rescue Slack::Web::Api::Errors::CantUpdateMessage, Slack::Web::Api::Errors::MessageNotFound
    nil
  end
end
