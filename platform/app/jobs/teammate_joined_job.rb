# Someone joined a project's team: says so in its thread and subscribes them to it, so they see the replies there.
# A project not on Slack yet gets nothing; its thread is posted later (PostProjectToSlackJob).
class TeammateJoinedJob < ApplicationJob
  queue_as :slack
  retry_on Slack::Web::Api::Errors::TooManyRequestsError, wait: :polynomially_longer, attempts: 5

  def perform(project, user)
    return if project.discarded? || !project.slack_linked? || !SlackMessaging.configured? || !project.on_team?(user)

    SlackBot.client.chat_postMessage(channel: project.slack_channel_id, thread_ts: project.slack_thread_ts, **SlackMessages.teammate_joined(project, user))
  end
end
