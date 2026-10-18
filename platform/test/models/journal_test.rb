require "test_helper"

# == Schema Information
#
# Table name: journals
#
#  id               :bigint           not null, primary key
#  body             :text             not null
#  discarded_at     :datetime
#  duration_minutes :integer
#  lapse_url        :string
#  slack_parts      :jsonb            not null
#  slack_ts         :string
#  source           :string           default("web"), not null
#  created_at       :datetime         not null
#  updated_at       :datetime         not null
#  project_id       :bigint           not null
#  slack_channel_id :string
#  user_id          :bigint           not null
#
# Indexes
#
#  index_journals_needing_hours                     (project_id) WHERE ((discarded_at IS NULL) AND (duration_minutes IS NULL))
#  index_journals_on_created_at                     (created_at)
#  index_journals_on_discarded_at                   (discarded_at)
#  index_journals_on_project_id                     (project_id)
#  index_journals_on_slack_channel_id_and_slack_ts  (slack_channel_id,slack_ts) UNIQUE WHERE (slack_ts IS NOT NULL)
#  index_journals_on_slack_parts                    (slack_parts jsonb_path_ops) USING gin
#  index_journals_on_user_id                        (user_id)
#
# Foreign Keys
#
#  fk_rails_...  (project_id => projects.id)
#  fk_rails_...  (user_id => users.id)
#
class JournalTest < ActiveSupport::TestCase
  test "duration is typed and shown as decimal hours" do
    assert_equal 90, Duration.parse("1.5")
    assert_equal 30, Duration.parse("0.5")
    assert_equal 30, Duration.parse(".5")
    assert_equal 6, Duration.parse("0.1")
    assert_equal 120, Duration.parse("2h")
    assert_nil Duration.parse("1h 30m")
    assert_nil Duration.parse("45m")
    assert_nil Duration.parse("0")
    assert_nil Duration.parse("")
    assert_nil Duration.parse("lots")
    assert_equal "1.5h", Duration.format(90)
    assert_equal "2h", Duration.format(120)
    assert_equal "0.75h", Duration.format(45)
    assert_equal "0.83h", Duration.format(50)
    assert_nil Duration.format(nil)
  end

  test "typed duration sets minutes or an error" do
    journal = projects(:station).journals.build(user: users(:member), body: "x", duration: "2h", images: [ photo ])
    assert journal.valid?
    assert_equal 120, journal.duration_minutes
    journal.duration = "a while"
    assert_not journal.valid?
    assert journal.errors[:duration].any?
  end

  test "every journal needs a time" do
    journal = projects(:station).journals.build(user: users(:member), body: "x", images: [ photo ])
    assert_not journal.valid?
    assert journal.errors[:duration].any?
    journal.duration = "0.75"
    assert journal.valid?
  end

  test "every two hours logged need a photo" do
    journal = projects(:station).journals.build(user: users(:member), body: "x", duration: "2h")
    assert_not journal.valid?
    assert_equal [ "at least 1 for 2h, one per 2 hours" ], journal.errors[:images]
    journal.images = [ photo ]
    assert journal.valid?
    journal.duration = "2.1"
    assert_not journal.valid?
    assert_equal 2, journal.images_needed

    journal.incoming_images = 1
    assert journal.valid?, "photos still on their way from Slack count"
  end

  test "an older journal keeps editable without photos but cannot lose the ones it has" do
    journal = journals(:first)
    assert journal.update(body: "edited", images: [])
    journal.update!(images: [ photo ])
    assert_not journal.update(body: "edited", images: [])
    assert journal.reload.update(body: "edited", images: journal.images.map(&:signed_id))
  end

  test "author must own the project" do
    journal = projects(:station).journals.build(user: users(:admin), body: "mine?")
    assert_not journal.valid?
    assert journal.errors[:project].any?
  end

  test "slack ts is unique per channel" do
    dup = projects(:station).journals.build(user: users(:member), body: "again", slack_channel_id: "CJOURNALS", slack_ts: journals(:first).slack_ts)
    assert_not dup.valid?
  end
end
