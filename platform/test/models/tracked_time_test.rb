require "test_helper"

class TrackedTimeTest < ActiveSupport::TestCase
  include ActiveSupport::Testing::TimeHelpers

  setup do
    @user = users(:member)
    @huddle = Huddle.create!(call_id: "R1", channel_id: "CHUDDLE", started_at: 1.day.ago)
  end

  test "counts huddle and timer time since the last journal, overlaps once, never chilling" do
    freeze_time do
      @user.journals.kept.update_all(created_at: 2.hours.ago)
      # Started before the journal: only the 30 minutes after it count.
      session(joined_at: 150.minutes.ago, left_at: 90.minutes.ago)
      session(joined_at: 60.minutes.ago, left_at: 30.minutes.ago, mode: "chilling")
      # 20 minutes of timer, half of it while also in the huddle.
      session(joined_at: 20.minutes.ago, left_at: 10.minutes.ago, mode: "working")
      @user.timer_sessions.create!(started_at: 15.minutes.ago, stopped_at: 5.minutes.ago)

      time = TrackedTime.new(@user)
      assert_equal (30 + 15).minutes.to_i, time.seconds
      assert_nil time.running
    end
  end

  test "says what is counting now" do
    freeze_time do
      @user.journals.kept.update_all(created_at: 1.hour.ago)
      @user.timer_sessions.create!(started_at: 10.minutes.ago)
      assert_equal [ "timer", 600 ], TrackedTime.new(@user).then { |time| [ time.running, time.seconds ] }

      session(joined_at: 5.minutes.ago)
      assert_equal [ "huddle", 600 ], TrackedTime.new(@user).then { |time| [ time.running, time.seconds ] }
    end
  end

  test "a forgotten timer stops counting at its limit" do
    freeze_time do
      @user.journals.update_all(discarded_at: Time.current)
      @user.timer_sessions.create!(started_at: 20.hours.ago)

      time = TrackedTime.new(@user)
      assert_equal [ TimerSession::MAX_LENGTH.to_i, nil ], [ time.seconds, time.running ]
    end
  end

  test "a pause takes its time out of the huddle and says paused" do
    freeze_time do
      @user.journals.kept.update_all(created_at: 1.hour.ago)
      session(joined_at: 30.minutes.ago)
      @user.huddle_pauses.create!(started_at: 25.minutes.ago, ended_at: 20.minutes.ago, end_reason: "resumed")
      @user.huddle_pauses.create!(started_at: 10.minutes.ago)

      time = TrackedTime.new(@user)
      assert_equal [ 15.minutes.to_i, "paused", true ], [ time.seconds, time.running, time.in_huddle? ]
    end
  end

  test "chilling in the huddle is in it but not counting" do
    freeze_time do
      session(joined_at: 10.minutes.ago, mode: "chilling")
      time = TrackedTime.new(@user)
      assert_equal [ nil, true ], [ time.running, time.in_huddle? ]
    end
  end

  test "honest hours come off each session's own time, so overlapping time is not taken off twice" do
    freeze_time do
      @user.journals.update_all(discarded_at: Time.current)
      # The same hour in the huddle and on the timer, and each says only 30 minutes of it were work.
      session(joined_at: 60.minutes.ago, left_at: 0.minutes.ago, mode: "working", deducted_seconds: 30.minutes.to_i)
      @user.timer_sessions.create!(started_at: 60.minutes.ago, stopped_at: Time.current, deducted_seconds: 30.minutes.to_i)

      assert_equal 30.minutes.to_i, TrackedTime.new(@user).seconds
    end
  end

  private

  def session(**attributes) = @huddle.sessions.create!(slack_id: @user.slack_id, user: @user, **attributes)
end
