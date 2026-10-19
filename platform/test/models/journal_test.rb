require "test_helper"

# == Schema Information
#
# Table name: journals
#
#  id                  :bigint           not null, primary key
#  body                :text             not null
#  discarded_at        :datetime
#  duration_minutes    :integer
#  hours_self_claimed  :boolean
#  lapse_url           :string
#  slack_parts         :jsonb            not null
#  slack_posted_by_bot :boolean          default(FALSE), not null
#  slack_ts            :string
#  source              :string           default("web"), not null
#  tracked_minutes     :integer
#  created_at          :datetime         not null
#  updated_at          :datetime         not null
#  project_id          :bigint           not null
#  slack_channel_id    :string
#  user_id             :bigint           not null
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
  include ActiveJob::TestHelper

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

  test "needs 100 characters of writing, not counting embedded photos" do
    short = projects(:station).journals.build(user: users(:member), body: "Soldered it ![board](/rails/active_storage/#{'x' * 120})", duration: "1", images: [ photo ])
    assert_not short.valid?
    assert_match(/needs at least 100 characters .* \(11 so far\)/, short.errors[:body].first)

    short.body = journal_text("Soldered it")
    assert short.valid?
  end

  test "an older, shorter journal can still be edited in Slack, but not shortened on the site" do
    journal = journals(:first)
    assert journal.update(slack_parts: [], body: "Shorter now", source: "slack"), "Slack edits keep up with the thread"
    journal.update_columns(source: "web")
    assert_not journal.update(body: "Still short")
  end

  test "typed duration sets minutes or an error" do
    journal = projects(:station).journals.build(user: users(:member), body: journal_text("x"), duration: "2h", images: [ photo ])
    assert journal.valid?
    assert_equal 120, journal.duration_minutes
    journal.duration = "a while"
    assert_not journal.valid?
    assert journal.errors[:duration].any?
  end

  test "picked timelapses fill in the hours only when none are typed" do
    second = users(:member).lapse_timelapses.create!(lapse_id: "lapse_second", name: "Wiring", duration_seconds: 1800, visibility: "PUBLIC", playback_url: "https://cdn.lapse.test/2.mp4")
    journal = projects(:station).journals.build(user: users(:member), body: journal_text("x"), duration: "", picked_timelapses: [ lapse_timelapses(:desk), second ], images: [ photo ])
    assert journal.save, journal.errors.full_messages.to_sentence
    assert_equal 120, journal.duration_minutes
    assert_equal [ journal.id ] * 2, [ lapse_timelapses(:desk), second ].map { |t| t.reload.journal_id }

    journal.update!(duration: "1.5")
    assert_equal 90, journal.reload.duration_minutes, "typed time stands, timelapses or not"

    journal.update!(picked_timelapses: [ second ], duration: "")
    assert_equal 30, journal.reload.duration_minutes
    assert_nil lapse_timelapses(:desk).reload.journal_id

    journal.update!(picked_timelapses: [], duration: "1")
    assert_equal 60, journal.reload.duration_minutes
    assert_empty journal.lapse_timelapses
  end

  test "keeps the tracked time it was written after, and flags hours over it and over its timelapses" do
    user = users(:member)
    user.journals.update_all(created_at: 1.day.ago)
    huddle = Huddle.create!(call_id: "R1", channel_id: "CHUDDLE", started_at: 1.day.ago)
    huddle.sessions.create!(slack_id: user.slack_id, user: user, joined_at: 1.minute.ago - 1.hour, left_at: 1.minute.ago, mode: "working")

    tracked = projects(:station).journals.create!(user: user, body: journal_text("x"), duration: "1", images: [ photo ])
    assert_equal [ 60, false ], [ tracked.tracked_minutes, tracked.hours_self_claimed ]

    tracked.update!(duration: "1.5")
    assert tracked.hours_self_claimed, "more than was tracked"

    covered = projects(:station).journals.create!(user: user, body: journal_text("y"), duration: "1.5", picked_timelapses: [ lapse_timelapses(:desk) ], images: [ photo ])
    assert_equal [ 0, false ], [ covered.tracked_minutes, covered.hours_self_claimed ], "the timelapses cover it"

    under = projects(:station).journals.create!(user: user, body: journal_text("z"), duration: "0.5", images: [ photo ])
    assert under.hours_self_claimed, "nothing tracked since the last journal"
  end

  test "picked timelapses must be rendered, yours, and on one journal at a time, whatever their visibility" do
    journal = projects(:station).journals.build(user: users(:member), body: journal_text("x"), picked_timelapses: [ lapse_timelapses(:hidden) ], images: [ photo ])
    assert journal.valid?, "a private timelapse is fine; Fallen never shows it publicly"

    lapse_timelapses(:hidden).update!(playback_url: nil)
    journal.picked_timelapses = [ lapse_timelapses(:hidden) ]
    assert_not journal.valid?
    assert_match(/“Private one” is still rendering/, journal.errors[:lapse_timelapses].first)

    journal.picked_timelapses = [ lapse_timelapses(:admins) ]
    assert_not journal.valid?
    assert_equal [ "“Admin's timelapse” must be yours" ], journal.errors[:lapse_timelapses]

    first = projects(:station).journals.create!(user: users(:member), body: journal_text("first"), picked_timelapses: [ lapse_timelapses(:desk) ], images: [ photo ])
    journal.picked_timelapses = [ lapse_timelapses(:desk).reload ]
    assert_not journal.valid?
    assert_equal [ "“Soldering the sensor board” is already on another journal" ], journal.errors[:lapse_timelapses]

    first.discard
    assert journal.valid?, "a deleted journal frees its timelapses"
  end

  test "every journal needs a time" do
    journal = projects(:station).journals.build(user: users(:member), body: journal_text("x"), images: [ photo ])
    assert_not journal.valid?
    assert journal.errors[:duration].any?
    journal.duration = "0.75"
    assert journal.valid?
  end

  test "every two hours logged need a photo" do
    journal = projects(:station).journals.build(user: users(:member), body: journal_text("x"), duration: "2h")
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

  test "photos are queued for analysis together, once" do
    journal = projects(:station).journals.build(user: users(:member), body: journal_text("x"), duration: "1", images: [ photo, photo("b.png") ])
    assert_enqueued_jobs 2, only: ActiveStorage::AnalyzeJob do
      journal.save!
    end
    assert_enqueued_jobs 1, only: ActiveStorage::AnalyzeJob do
      journal.images.attach(io: StringIO.new("png"), filename: "slack.png", content_type: "image/png")
    end
    assert_no_enqueued_jobs(only: ActiveStorage::AnalyzeJob) { journal.update!(body: journal_text("edited")) }
  end

  test "author must own the project" do
    journal = projects(:station).journals.build(user: users(:admin), body: journal_text("mine?"))
    assert_not journal.valid?
    assert journal.errors[:project].any?
  end

  test "slack ts is unique per channel" do
    dup = projects(:station).journals.build(user: users(:member), body: journal_text("again"), slack_channel_id: "CJOURNALS", slack_ts: journals(:first).slack_ts)
    assert_not dup.valid?
  end
end
