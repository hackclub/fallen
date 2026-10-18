# Someone joining or leaving the bot's huddle, as Slack's real-time socket reported it to bin/slack-typing, at the
# moment Slack stamped on the event. HuddleSyncJob takes join and leave times for HuddleSessions from these, so a
# session is as exact as Slack's own clock rather than as late as the sync that noticed it. Also the record to go
# back to when someone's huddle time is questioned.
# == Schema Information
#
# Table name: huddle_events
#
#  id          :bigint           not null, primary key
#  kind        :string           not null
#  occurred_at :datetime         not null
#  created_at  :datetime         not null
#  call_id     :string           not null
#  slack_id    :string           not null
#
# Indexes
#
#  index_huddle_events_on_call_id_and_slack_id_and_occurred_at  (call_id,slack_id,occurred_at)
#  index_huddle_events_on_slack_id                              (slack_id)
#
class HuddleEvent < ApplicationRecord
  has_paper_trail

  KINDS = { "sh_room_join" => "joined", "sh_room_leave" => "left" }.freeze

  validates :call_id, :slack_id, :occurred_at, presence: true
  validates :kind, inclusion: { in: KINDS.values }

  # Stores a socket event if it is a join or leave in the huddle's channel.
  def self.record(event)
    kind = KINDS[event["type"]]
    room = event["room"]
    return unless kind && room.is_a?(Hash) && event["user"].present? && event["event_ts"].present?
    return unless Array(room["channels"]).include?(SlackHuddle.channel_id) || event.dig("huddle", "channel_id") == SlackHuddle.channel_id

    create!(call_id: room["id"], slack_id: event["user"], kind: kind, occurred_at: Time.zone.at(event["event_ts"].to_r))
  end

  # When this person last did `kind` in this huddle at or after `since`, or nil.
  def self.last_at(call_id, slack_id, kind, since:)
    where(call_id: call_id, slack_id: slack_id, kind: kind, occurred_at: since..).maximum(:occurred_at)
  end
end
