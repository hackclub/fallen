# Deletes a top-level post in the journals channel that is not a project anchor (MessageEvent), then tells the
# author where projects start and hands their text back so nothing is lost.
class RemoveStrayPostJob < ApplicationJob
  queue_as :slack
  retry_on Prometheus::Error, wait: :polynomially_longer, attempts: 5

  def perform(channel_id, ts, slack_user_id, text)
    return if Project.exists?(slack_channel_id: channel_id, slack_thread_ts: ts)

    removed = Prometheus.configured?
    Prometheus.delete_thread(ts, reason: "Fallen: projects are started on the site, not by posting in the channel") if removed
    SlackBot.client.chat_postEphemeral(channel: channel_id, user: slack_user_id, **SlackMessages.stray_post(text, removed: removed))
  rescue Slack::Web::Api::Errors::SlackError
    nil
  end
end
