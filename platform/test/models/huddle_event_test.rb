require "test_helper"

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
class HuddleEventTest < ActiveSupport::TestCase
  test "records joins and leaves in the huddle's channel at Slack's time" do
    with_env("SLACK_HUDDLE_CHANNEL_ID" => "CHUDDLE") do
      event = HuddleEvent.record(socket_event("sh_room_join", channels: %w[CHUDDLE]))
      assert_equal [ "R1", "U0MEMBER", "joined", Time.zone.at(Rational("1792315428.012")) ], [ event.call_id, event.slack_id, event.kind, event.occurred_at ]

      assert_nil HuddleEvent.record(socket_event("sh_room_leave", channels: %w[COTHER]))
      assert_nil HuddleEvent.record(socket_event("sh_room_update", channels: %w[CHUDDLE]))
    end
    assert_equal 1, HuddleEvent.count
  end

  private

  def socket_event(type, channels:)
    { "type" => type, "user" => "U0MEMBER", "event_ts" => "1792315428.012000", "room" => { "id" => "R1", "channels" => channels } }
  end
end
