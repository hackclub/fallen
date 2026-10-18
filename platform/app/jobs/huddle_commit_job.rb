# Tells the huddle what someone just committed to working on, in its thread and as their pet (HuddleGoalAction).
class HuddleCommitJob < ApplicationJob
  queue_as :slack
  retry_on Slack::Web::Api::Errors::TooManyRequestsError, wait: :polynomially_longer, attempts: 5

  def perform(session)
    return if session.goal.blank?

    huddle = session.huddle
    SlackBot.client.chat_postMessage(channel: huddle.channel_id, thread_ts: huddle.thread_ts, unfurl_links: false, unfurl_media: false, **SlackMessages.huddle_commit(session))
  end
end
