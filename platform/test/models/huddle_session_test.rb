require "test_helper"

# == Schema Information
#
# Table name: huddle_sessions
#
#  id                  :bigint           not null, primary key
#  camera_seconds      :integer          default(0), not null
#  camera_since        :datetime
#  goal                :text
#  join_source         :string
#  joined_at           :datetime         not null
#  last_seen_at        :datetime
#  leave_source        :string
#  left_at             :datetime
#  mode                :string
#  prompted_at_count   :integer
#  screenshare_seconds :integer          default(0), not null
#  screenshare_since   :datetime
#  created_at          :datetime         not null
#  updated_at          :datetime         not null
#  huddle_id           :bigint           not null
#  slack_id            :string           not null
#  user_id             :bigint
#
# Indexes
#
#  index_huddle_sessions_on_huddle_id_and_slack_id  (huddle_id,slack_id)
#  index_huddle_sessions_on_slack_id                (slack_id)
#  index_huddle_sessions_on_user_id                 (user_id)
#  index_huddle_sessions_one_open_per_person        (huddle_id,slack_id) UNIQUE WHERE (left_at IS NULL)
#
# Foreign Keys
#
#  fk_rails_...  (huddle_id => huddles.id)
#  fk_rails_...  (user_id => users.id)
#
class HuddleSessionTest < ActiveSupport::TestCase
  include ActiveSupport::Testing::TimeHelpers

  test "total_seconds adds every visit to the second, open ones up to now" do
    freeze_time do
      huddle = Huddle.create!(call_id: "R1", channel_id: "CHUDDLE", started_at: 1.hour.ago)
      huddle.sessions.create!(slack_id: "U0MEMBER", joined_at: 30.minutes.ago, left_at: 30.minutes.ago + 34.seconds)
      huddle.sessions.create!(slack_id: "U0MEMBER", joined_at: 20.minutes.ago, left_at: 20.minutes.ago + 8.minutes + 27.seconds)
      huddle.sessions.create!(slack_id: "U0MEMBER", joined_at: 90.seconds.ago)

      assert_equal 34 + 507 + 90, huddle.sessions.total_seconds
    end
  end

  test "leaving never ends before joining and closes open screenshare and camera time" do
    huddle = Huddle.create!(call_id: "R1", channel_id: "CHUDDLE", started_at: 1.hour.ago)
    joined = Time.zone.at(10.minutes.ago.to_i)
    session = huddle.sessions.create!(slack_id: "U0MEMBER", joined_at: joined, screenshare_since: joined + 1.minute)

    session.leave!(joined + 4.minutes, "event")
    assert_equal [ nil, 180 ], [ session.screenshare_since, session.screenshare_seconds ]

    early = huddle.sessions.create!(slack_id: "U0ADMIN", joined_at: joined)
    early.leave!(joined - 5.seconds, "sync")
    assert_equal joined, early.left_at
  end
end
