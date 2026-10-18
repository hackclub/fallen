require "test_helper"

class TimerChannelTest < ActionCable::Channel::TestCase
  test "streams the person's own changes" do
    stub_connection current_user: users(:member)
    subscribe
    assert subscription.confirmed?
    assert_has_stream_for users(:member)
  end

  test "joining the huddle tells their pages" do
    huddle = Huddle.create!(call_id: "R1", channel_id: "CHUDDLE", started_at: 1.hour.ago)
    assert_broadcasts(TimerChannel.broadcasting_for(users(:member)), 1) do
      huddle.sessions.create!(slack_id: "U0MEMBER", user: users(:member), joined_at: Time.current)
    end
    assert_no_broadcasts(TimerChannel.broadcasting_for(users(:member))) do
      HuddleSession.update_all(last_seen_at: Time.current)
    end
  end
end
