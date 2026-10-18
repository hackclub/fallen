require "test_helper"

class HuddleSyncJobTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper
  include ActiveSupport::Testing::TimeHelpers

  CHANNEL = "CHUDDLE"
  BOT = "U0BOT"

  test "finds the running huddle and opens a session for everyone but the bot" do
    browser = fake_browser(history: [ huddle_message("R1", %w[U0BOT U0MEMBER U0STRANGER]) ])

    assert_enqueued_jobs 2, only: HuddlePromptJob do
      sync(browser)
    end

    huddle = Huddle.find_by!(call_id: "R1")
    assert_equal [ CHANNEL, "1700000000.000100" ], [ huddle.channel_id, huddle.thread_ts ]
    assert_equal %w[U0MEMBER U0STRANGER], huddle.sessions.ongoing.order(:slack_id).pluck(:slack_id)
    assert_equal users(:member), huddle.sessions.find_by(slack_id: "U0MEMBER").user
    assert_nil huddle.sessions.find_by(slack_id: "U0STRANGER").user
  end

  test "closes the session of someone who left and asks whether they are still on it when they come back" do
    huddle = Huddle.create!(call_id: "R1", channel_id: CHANNEL, thread_ts: "1700000000.000100", started_at: 1.hour.ago)
    huddle.sessions.create!(slack_id: "U0MEMBER", user: users(:member), joined_at: 30.minutes.ago, mode: "working", goal: "Case")

    sync(fake_browser(room: room("R1", %w[U0BOT])))
    assert_not_nil huddle.sessions.sole.left_at

    travel Huddle::REJOIN_QUIET + 1.second do
      assert_enqueued_jobs(1, only: HuddlePromptJob) { sync(fake_browser(room: room("R1", %w[U0BOT U0MEMBER]))) }
    end
    back = huddle.sessions.ongoing.sole
    assert_equal [ nil, "Case" ], [ back.mode, back.goal ]
  end

  test "a dropped connection keeps the answer and is not asked again" do
    huddle = Huddle.create!(call_id: "R1", channel_id: CHANNEL, started_at: 1.hour.ago)
    huddle.sessions.create!(slack_id: "U0MEMBER", joined_at: 30.minutes.ago, left_at: 10.seconds.ago, mode: "working", goal: "Case", prompted_at_count: 3)

    assert_no_enqueued_jobs(only: HuddlePromptJob) { sync(fake_browser(room: room("R1", %w[U0BOT U0MEMBER]))) }
    back = huddle.sessions.ongoing.sole
    assert_equal [ "working", "Case", 3 ], [ back.mode, back.goal, back.prompted_at_count ]
  end

  test "a dropped connection without an answer is asked again" do
    huddle = Huddle.create!(call_id: "R1", channel_id: CHANNEL, started_at: 1.hour.ago)
    huddle.sessions.create!(slack_id: "U0MEMBER", joined_at: 30.minutes.ago, left_at: 5.seconds.ago, goal: "Case", prompted_at_count: 0)

    assert_enqueued_jobs(1, only: HuddlePromptJob) { sync(fake_browser(room: room("R1", %w[U0BOT U0MEMBER]))) }
    assert_equal "Case", huddle.sessions.ongoing.sole.goal
  end

  test "someone who was chilling comes back still chilling, without being asked again" do
    huddle = Huddle.create!(call_id: "R1", channel_id: CHANNEL, started_at: 1.hour.ago)
    huddle.sessions.create!(slack_id: "U0MEMBER", joined_at: 30.minutes.ago, left_at: 10.minutes.ago, mode: "chilling")

    assert_no_enqueued_jobs(only: HuddlePromptJob) { sync(fake_browser(room: room("R1", %w[U0BOT U0MEMBER]))) }
    assert_equal [ "chilling", nil ], huddle.sessions.ongoing.sole.slice(:mode, :goal).values
  end

  test "an empty participant list leaves everyone where they are" do
    huddle = Huddle.create!(call_id: "R1", channel_id: CHANNEL, started_at: 1.hour.ago)
    huddle.sessions.create!(slack_id: "U0MEMBER", joined_at: 30.minutes.ago)

    sync(fake_browser(room: room("R1", [])))

    assert_nil huddle.sessions.sole.left_at
  end

  test "when Slack ends the huddle, the next one mentions whoever was still in the old one" do
    ended_at = Time.zone.at(1.minute.ago.to_i)
    old = Huddle.create!(call_id: "R1", channel_id: CHANNEL, started_at: 1.day.ago)
    old.sessions.create!(slack_id: "U0MEMBER", joined_at: 2.hours.ago)
    old.sessions.create!(slack_id: "U0STRANGER", joined_at: 2.hours.ago)
    old.sessions.create!(slack_id: "U0ADMIN", joined_at: 3.hours.ago, left_at: 2.hours.ago)
    old.sessions.create!(slack_id: "U0BACK", joined_at: 2.hours.ago)
    browser = fake_browser(room: room("R1", [], date_end: ended_at.to_i), history: [ huddle_message("R2", %w[U0BOT U0BACK], ts: "1700090000.000100") ])

    assert_enqueued_with(job: HuddleHandoffJob) { sync(browser) }

    assert_equal ended_at, old.reload.ended_at
    assert_not_nil old.handed_off_at
    assert_equal [ ended_at ], old.sessions.where.not(slack_id: "U0ADMIN").distinct.pluck(:left_at)
    new_huddle, mentioned = enqueued_jobs.find { |job| job["job_class"] == "HuddleHandoffJob" }["arguments"].then { |args| ActiveJob::Arguments.deserialize(args) }
    assert_equal "R2", new_huddle.call_id
    assert_equal %w[U0MEMBER U0STRANGER], mentioned.sort

    assert_no_enqueued_jobs(only: HuddleHandoffJob) { sync(fake_browser(room: room("R2", %w[U0BOT U0BACK]))) }
  end

  test "an answer from the last huddle carries over for someone back within 15 minutes of the restart" do
    old = Huddle.create!(call_id: "R1", channel_id: CHANNEL, started_at: 1.day.ago, ended_at: 10.minutes.ago, handed_off_at: 9.minutes.ago)
    old.sessions.create!(slack_id: "U0MEMBER", joined_at: 2.hours.ago, left_at: 10.minutes.ago, mode: "working", goal: "Case")
    old.sessions.create!(slack_id: "U0ADMIN", joined_at: 2.hours.ago, left_at: 10.minutes.ago)
    Huddle.create!(call_id: "R2", channel_id: CHANNEL, thread_ts: "1700090000.000100", started_at: 9.minutes.ago)

    assert_enqueued_jobs 1, only: HuddlePromptJob do
      sync(fake_browser(room: room("R2", %w[U0BOT U0MEMBER U0ADMIN])))
    end
    carried = Huddle.find_by!(call_id: "R2").sessions.find_by!(slack_id: "U0MEMBER")
    assert_equal [ "working", "Case" ], [ carried.mode, carried.goal ]
  end

  test "after 15 minutes everyone is asked fresh" do
    old = Huddle.create!(call_id: "R1", channel_id: CHANNEL, started_at: 1.day.ago, ended_at: 20.minutes.ago, handed_off_at: 19.minutes.ago)
    old.sessions.create!(slack_id: "U0MEMBER", joined_at: 2.hours.ago, left_at: 20.minutes.ago, mode: "working", goal: "Case")
    Huddle.create!(call_id: "R2", channel_id: CHANNEL, started_at: 19.minutes.ago)

    assert_enqueued_jobs(1, only: HuddlePromptJob) { sync(fake_browser(room: room("R2", %w[U0BOT U0MEMBER]))) }
    assert_nil Huddle.find_by!(call_id: "R2").sessions.sole.mode
  end

  test "takes join and leave times from Slack's events" do
    huddle = Huddle.create!(call_id: "R1", channel_id: CHANNEL, started_at: 1.hour.ago)
    joined = Time.zone.at(40.seconds.ago.to_i)
    HuddleEvent.create!(call_id: "R1", slack_id: "U0MEMBER", kind: "joined", occurred_at: joined)

    sync(fake_browser(room: room("R1", %w[U0BOT U0MEMBER])))
    session = huddle.sessions.sole
    assert_equal [ joined, "event" ], [ session.joined_at, session.join_source ]

    left = Time.zone.at(5.seconds.ago.to_i)
    HuddleEvent.create!(call_id: "R1", slack_id: "U0MEMBER", kind: "left", occurred_at: left)
    sync(fake_browser(room: room("R1", %w[U0BOT])))
    assert_equal [ left, "event" ], [ session.reload.left_at, session.leave_source ]
  end

  test "without events, times are when the sync noticed" do
    huddle = Huddle.create!(call_id: "R1", channel_id: CHANNEL, started_at: 1.hour.ago)
    HuddleEvent.create!(call_id: "R1", slack_id: "U0MEMBER", kind: "joined", occurred_at: 2.hours.ago)

    freeze_time do
      sync(fake_browser(room: room("R1", %w[U0BOT U0MEMBER])))
      session = huddle.sessions.sole
      assert_equal [ Time.current, "sync", Time.current ], [ session.joined_at, session.join_source, session.last_seen_at ]
    end
  end

  test "someone who left while nothing was watching leaves when last seen, not when syncs resume" do
    huddle = Huddle.create!(call_id: "R1", channel_id: CHANNEL, started_at: 1.hour.ago)
    seen = Time.zone.at(20.minutes.ago.to_i)
    session = huddle.sessions.create!(slack_id: "U0MEMBER", joined_at: 30.minutes.ago, last_seen_at: seen)
    staying = huddle.sessions.create!(slack_id: "U0ADMIN", joined_at: 30.minutes.ago, last_seen_at: seen)

    sync(fake_browser(room: room("R1", %w[U0BOT U0ADMIN])))

    assert_equal [ seen, "unseen" ], [ session.reload.left_at, session.leave_source ]
    assert_nil staying.reload.left_at
    assert_in_delta Time.current, staying.last_seen_at, 2
  end

  test "counts time with the screen shared and the camera on" do
    huddle = Huddle.create!(call_id: "R1", channel_id: CHANNEL, started_at: 1.hour.ago)
    sharing = room("R1", %w[U0BOT U0MEMBER]).merge("participants_screenshare_on" => %w[U0MEMBER], "participants_camera_on" => [ { "user_id" => "U0MEMBER" } ])
    start = Time.current.change(usec: 0)

    travel_to(start) { sync(fake_browser(room: sharing)) }
    session = huddle.sessions.sole
    assert_equal [ start, start ], [ session.screenshare_since, session.camera_since ]

    travel_to(start + 90.seconds) { sync(fake_browser(room: sharing.merge("participants_screenshare_on" => []))) }
    assert_equal [ nil, 90, 0 ], [ session.reload.screenshare_since, session.screenshare_seconds, session.camera_seconds ]

    travel_to(start + 2.minutes) { sync(fake_browser(room: room("R1", %w[U0BOT]))) }
    assert_equal [ nil, 120 ], [ session.reload.camera_since, session.camera_seconds ]
  end

  test "sessions still open when the huddle ends close at the end" do
    ended_at = Time.zone.at(30.seconds.ago.to_i)
    huddle = Huddle.create!(call_id: "R1", channel_id: CHANNEL, started_at: 1.day.ago)
    huddle.sessions.create!(slack_id: "U0MEMBER", joined_at: 2.hours.ago, last_seen_at: 1.minute.ago)

    sync(fake_browser(room: room("R1", [], date_end: ended_at.to_i)))

    assert_equal [ ended_at, "huddle_end" ], huddle.sessions.sole.slice(:left_at, :leave_source).values
  end

  test "leaving ends a pause, a dropped connection keeps it, and no pause outlives its huddle visit" do
    huddle = Huddle.create!(call_id: "R1", channel_id: CHANNEL, started_at: 1.hour.ago)
    huddle.sessions.create!(slack_id: "U0MEMBER", user: users(:member), joined_at: 30.minutes.ago, last_seen_at: Time.current, mode: "working")
    pause = users(:member).huddle_pauses.create!(started_at: 10.minutes.ago)

    sync(fake_browser(room: room("R1", %w[U0BOT])))
    assert_equal "left", pause.reload.end_reason

    travel 5.seconds do
      sync(fake_browser(room: room("R1", %w[U0BOT U0MEMBER])))
    end
    assert_equal 1, users(:member).huddle_pauses.open.count

    stray = users(:admin).huddle_pauses.create!(started_at: 1.minute.ago)
    sync(fake_browser(room: room("R1", %w[U0BOT U0MEMBER])))
    assert_equal "left", stray.reload.end_reason
    assert_equal 1, users(:member).huddle_pauses.open.count
  end

  test "does nothing until the huddle is configured" do
    with_env("SLACK_HUDDLE_CHANNEL_ID" => nil) { HuddleSyncJob.perform_now }
    assert_equal 0, Huddle.count
  end

  private

  def sync(browser)
    SlackHuddle.instance_variable_set(:@client, browser)
    SlackHuddle.instance_variable_set(:@user_id, BOT)
    with_env("SLACK_HUDDLE_CHANNEL_ID" => CHANNEL, "SLACK_BROWSER_TOKEN" => "xoxc-test", "SLACK_BROWSER_COOKIE" => "xoxd-test") { HuddleSyncJob.perform_now }
  ensure
    SlackHuddle.reset!
  end

  def fake_browser(room: nil, history: [])
    FakeBrowserClient.new(
      "screenhero.rooms.info" => room ? { "ok" => true, "room" => room } : SlackBot::BrowserClient::Error.new("screenhero.rooms.info", "rooms_not_found"),
      "conversations.history" => { "ok" => true, "messages" => history }
    )
  end

  def room(id, participants, date_end: 0)
    { "id" => id, "participants" => participants, "date_start" => 1.hour.ago.to_i, "date_end" => date_end, "has_ended" => date_end.positive? }
  end

  def huddle_message(id, participants, ts: "1700000000.000100")
    { "type" => "message", "subtype" => "huddle_thread", "ts" => ts, "room" => room(id, participants) }
  end
end
