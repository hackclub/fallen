# Rings someone into the huddle, like Slack's own "Invite to huddle": a person who pressed "Invite me" on the pet's
# huddle prompt, or a Slack id dropped when the last huddle ended (HuddleHandoffJob). A failed ring is logged,
# never retried; the prompt and the handoff post also link the huddle.
#
# Slack refuses the ring once the main huddle is full, which is how Fallen finds out: the huddle is marked full
# (Huddle#full!) and the person is rung into their team's huddle instead once the account has opened it. Slack says
# `invite_failed`, or `permission_denied` when the account itself is out of the huddle because a full huddle would
# not let it back in (script/slack_huddle.mjs logs `rooms_free_willy_create_attendee_failed`).
class HuddleRingJob < ApplicationJob
  queue_as :realtime

  # How long script/slack_huddle.mjs takes to notice a new team huddle is wanted and open it.
  TEAM_HUDDLE_OPENS_IN = 45.seconds
  REFUSED = %w[invite_failed permission_denied].freeze

  def perform(user_or_slack_id, retried: false)
    user = user_or_slack_id.is_a?(User) ? user_or_slack_id : User.kept.find_by(slack_id: user_or_slack_id)
    slack_id = user&.slack_id || user_or_slack_id
    return unless SlackHuddle.configured? && slack_id.is_a?(String) && slack_id.present?

    main = Huddle.current
    channel = Huddle.channel_for(user, main)
    begin
      SlackHuddle.ring(slack_id, channel)
    rescue SlackBot::BrowserClient::Error => e
      raise unless REFUSED.include?(e.code) && channel == SlackHuddle.channel_id && main && !retried
      return if main.sessions.ongoing.exists?(slack_id: slack_id)

      main.full!
      self.class.set(wait: TEAM_HUDDLE_OPENS_IN).perform_later(user_or_slack_id, retried: true) if Huddle.channel_for(user, main) != channel
      raise
    end
  rescue SlackBot::BrowserClient::Error, Faraday::Error => e
    Rails.logger.warn({ event: "huddle_ring.failed", slack_id: slack_id, error: e.message }.to_json)
  end
end
