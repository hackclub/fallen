require "test_helper"

class KeepHuddleJobTest < ActiveJob::TestCase
  JOINED = {
    "ok" => true,
    "call" => { "call_id" => "R2" },
    "huddle" => { "id" => "R2", "participants" => [ "U0BOT" ] },
    "canvas" => { "root_thread_ts" => "1700000000.000200" }
  }.freeze

  setup do
    SlackHuddle.reset!
    @cache = Rails.cache
    Rails.cache = ActiveSupport::Cache::MemoryStore.new
  end

  teardown do
    Rails.cache = @cache
    SlackHuddle.reset!
  end

  test "does nothing when not configured" do
    fake = FakeBrowserClient.new
    with_env("SLACK_HUDDLE_CHANNEL_ID" => nil) { stub_method(SlackHuddle, :client, fake) { KeepHuddleJob.perform_now } }
    assert_empty fake.calls
  end

  test "starts a huddle when it has none" do
    fake = FakeBrowserClient.new("rooms.join" => JOINED)
    configured { stub_method(SlackHuddle, :client, fake) { KeepHuddleJob.perform_now } }
    assert_equal [ "rooms.join" ], fake.calls.map(&:first)
    assert_equal "R2", KeepHuddleJob.current_call_id
  end

  test "stays put while its huddle is running with the bot in it" do
    Rails.cache.write(KeepHuddleJob::STATE_KEY, { call_id: "R1" })
    fake = FakeBrowserClient.new(
      "auth.test" => { "ok" => true, "user_id" => "U0BOT" },
      "screenhero.rooms.info" => { "ok" => true, "room" => { "id" => "R1", "participants" => [ { "user_id" => "U0BOT" } ] } }
    )
    configured { stub_method(SlackHuddle, :client, fake) { KeepHuddleJob.perform_now } }
    assert_not_includes fake.calls.map(&:first), "rooms.join"
    assert_equal "R1", KeepHuddleJob.current_call_id
  end

  test "joins again when its huddle ended" do
    Rails.cache.write(KeepHuddleJob::STATE_KEY, { call_id: "R1" })
    fake = FakeBrowserClient.new(
      "screenhero.rooms.info" => { "ok" => true, "room" => { "id" => "R1", "participants" => [], "has_ended" => true, "date_end" => 1700086400 } },
      "rooms.join" => JOINED
    )
    configured { stub_method(SlackHuddle, :client, fake) { KeepHuddleJob.perform_now } }
    assert_includes fake.calls.map(&:first), "rooms.join"
    assert_equal "R2", KeepHuddleJob.current_call_id
  end

  test "joins again when the bot is no longer a participant" do
    Rails.cache.write(KeepHuddleJob::STATE_KEY, { call_id: "R1" })
    fake = FakeBrowserClient.new(
      "auth.test" => { "ok" => true, "user_id" => "U0BOT" },
      "screenhero.rooms.info" => { "ok" => true, "room" => { "id" => "R1", "participants" => [ "U0MEMBER" ] } },
      "rooms.join" => JOINED
    )
    configured { stub_method(SlackHuddle, :client, fake) { KeepHuddleJob.perform_now } }
    assert_includes fake.calls.map(&:first), "rooms.join"
  end

  test "joins again when Slack forgot the huddle" do
    Rails.cache.write(KeepHuddleJob::STATE_KEY, { call_id: "R1" })
    fake = FakeBrowserClient.new(
      "screenhero.rooms.info" => SlackBot::BrowserClient::Error.new("screenhero.rooms.info", "rooms_unauthorized_room"),
      "rooms.join" => JOINED
    )
    configured { stub_method(SlackHuddle, :client, fake) { KeepHuddleJob.perform_now } }
    assert_includes fake.calls.map(&:first), "rooms.join"
  end

  test "a Slack failure is logged, not raised, and keeps the last huddle" do
    Rails.cache.write(KeepHuddleJob::STATE_KEY, { call_id: "R1" })
    fake = FakeBrowserClient.new("screenhero.rooms.info" => SlackBot::BrowserClient::Error.new("screenhero.rooms.info", "invalid_auth"))
    configured { stub_method(SlackHuddle, :client, fake) { assert_nothing_raised { KeepHuddleJob.perform_now } } }
    assert_equal "R1", KeepHuddleJob.current_call_id
  end

  private

  def configured(&block)
    with_env("SLACK_HUDDLE_CHANNEL_ID" => "CHUDDLE", "SLACK_BROWSER_TOKEN" => "xoxc", "SLACK_BROWSER_COOKIE" => "xoxd", &block)
  end
end
