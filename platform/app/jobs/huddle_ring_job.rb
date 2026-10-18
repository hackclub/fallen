# Someone pressed "Invite me" on the pet's huddle prompt: rings them into the huddle, like Slack's own "Invite to
# huddle". A failed ring is logged, never retried; the prompt also opened the huddle's link.
class HuddleRingJob < ApplicationJob
  queue_as :realtime

  def perform(user)
    return unless SlackHuddle.configured? && user.slack_id.present?

    SlackHuddle.ring(user.slack_id)
  rescue SlackBot::BrowserClient::Error, Faraday::Error => e
    Rails.logger.warn({ event: "huddle_ring.failed", user_id: user.id, error: e.message }.to_json)
  end
end
