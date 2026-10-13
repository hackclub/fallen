# "Make this a project" under someone's top-level message in the journals channel (see MessageEvent).
class ProjectFromMessageAction < SlackBot::Action
  def call
    return unless user

    open_modal ProjectView.build(channel_id: channel_id, anchor_ts: value, response_url: response_url, initial_description: original_text)
  end

  private

  def original_text
    history = client.conversations_history(channel: channel_id, latest: value, oldest: value, inclusive: true, limit: 1)
    history.messages.first&.text.to_s.truncate(2000).presence
  rescue Slack::Web::Api::Errors::SlackError
    nil
  end
end
