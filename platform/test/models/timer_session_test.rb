require "test_helper"

# == Schema Information
#
# Table name: timer_sessions
#
#  id               :bigint           not null, primary key
#  deducted_seconds :integer          default(0), not null
#  done             :text
#  goal             :text
#  started_at       :datetime         not null
#  stopped_at       :datetime
#  wrapped_up_at    :datetime
#  created_at       :datetime         not null
#  updated_at       :datetime         not null
#  user_id          :bigint           not null
#
# Indexes
#
#  index_timer_sessions_on_stopped_at              (stopped_at)
#  index_timer_sessions_on_user_id_and_started_at  (user_id,started_at)
#  index_timer_sessions_one_running_per_user       (user_id) UNIQUE WHERE (stopped_at IS NULL)
#
# Foreign Keys
#
#  fk_rails_...  (user_id => users.id)
#
class TimerSessionTest < ActiveSupport::TestCase
  include ActiveSupport::Testing::TimeHelpers

  test "start keeps a running timer and replaces one that ran out" do
    user = users(:member)
    freeze_time do
      first = TimerSession.start(user)
      assert_equal first, TimerSession.start(user)

      travel TimerSession::MAX_LENGTH + 1.hour
      second = TimerSession.start(user)
      assert_not_equal first, second
      assert_equal first.started_at + TimerSession::MAX_LENGTH, first.reload.stopped_at
      assert_equal [ second ], user.timer_sessions.running.to_a
    end
  end

  test "stop only ever closes a running timer, so a second stop keeps the first time" do
    user = users(:member)
    timer = user.timer_sessions.create!(started_at: 1.hour.ago)
    stopped_at = Time.zone.at(10.minutes.ago.to_i)

    TimerSession.stop(user, at: stopped_at)
    TimerSession.stop(user, at: Time.current)
    assert_equal stopped_at, timer.reload.stopped_at
  end

  test "stop never runs past the limit" do
    user = users(:member)
    timer = user.timer_sessions.create!(started_at: 20.hours.ago)
    TimerSession.stop(user)
    assert_in_delta timer.started_at + TimerSession::MAX_LENGTH, timer.reload.stopped_at, 1
  end
end
