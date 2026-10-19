# Rings someone into the huddle, like Slack's own "Invite to huddle": a person who pressed "Invite me" on the pet's
# huddle prompt, or a Slack id dropped when the last huddle ended (HuddleHandoffJob). A failed ring is logged,
# never retried; the prompt and the handoff post also link the huddle.
class HuddleRingJob < ApplicationJob
  queue_as :realtime

  def perform(user_or_slack_id)
    slack_id = user_or_slack_id.is_a?(User) ? user_or_slack_id.slack_id : user_or_slack_id
    return unless SlackHuddle.configured? && slack_id.present?

    SlackHuddle.ring(slack_id)
  rescue SlackBot::BrowserClient::Error, Faraday::Error => e
    Rails.logger.warn({ event: "huddle_ring.failed", slack_id: slack_id, error: e.message }.to_json)
  end
end
