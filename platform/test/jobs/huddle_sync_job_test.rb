require "test_helper"

class HuddleSyncJobTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

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

  test "closes the session of someone who left and only asks once when they come back" do
    huddle = Huddle.create!(call_id: "R1", channel_id: CHANNEL, thread_ts: "1700000000.000100", started_at: 1.hour.ago)
    huddle.sessions.create!(slack_id: "U0MEMBER", user: users(:member), joined_at: 30.minutes.ago, mode: "working", goal: "Case")

    sync(fake_browser(room: room("R1", %w[U0BOT])))
    assert_not_nil huddle.sessions.sole.left_at

    assert_no_enqueued_jobs(only: HuddlePromptJob) { sync(fake_browser(room: room("R1", %w[U0BOT U0MEMBER]))) }
    back = huddle.sessions.ongoing.sole
    assert_equal [ "working", "Case" ], [ back.mode, back.goal ]
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
