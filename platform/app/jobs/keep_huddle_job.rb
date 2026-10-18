# Keeps the user bot in a huddle in SLACK_HUDDLE_CHANNEL_ID around the clock. Slack ends every huddle after 24
# hours and drops a participant whose connection goes away, so this runs on a schedule (config/recurring.yml) and
# whenever bin/slack-typing sees the huddle end: it checks the huddle it last joined and joins again when that one
# is over or no longer has the bot in it. Joining a channel with a running huddle joins that one, so a lost record
# of the last huddle costs nothing.
class KeepHuddleJob < ApplicationJob
  queue_as :slack
  limits_concurrency key: "keep_huddle"

  STATE_KEY = "keep_huddle/room"

  def self.current_call_id = Rails.cache.read(STATE_KEY)&.fetch(:call_id)

  def perform
    return unless SlackHuddle.configured?

    current = Rails.cache.read(STATE_KEY)
    return if current && still_in?(current[:call_id])

    room = SlackHuddle.join
    Rails.cache.write(STATE_KEY, { call_id: room.call_id, thread_ts: room.thread_ts, joined_at: Time.current })
    Rails.logger.info({ event: "keep_huddle.joined", call_id: room.call_id, channel: SlackHuddle.channel_id, participants: room.participant_ids.size }.to_json)
  rescue SlackBot::BrowserClient::Error, Faraday::Error => e
    Rails.logger.error({ event: "keep_huddle.failed", error: e.message }.to_json)
  end

  private

  def still_in?(call_id)
    room = SlackHuddle.room(call_id)
    room&.active? && room.includes?(SlackHuddle.user_id)
  end
end
