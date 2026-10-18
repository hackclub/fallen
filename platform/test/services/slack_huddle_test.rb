require "test_helper"

class SlackHuddleTest < ActiveSupport::TestCase
  setup { SlackHuddle.reset! }
  teardown { SlackHuddle.reset! }

  test "configured only with a channel and the browser session" do
    with_env("SLACK_HUDDLE_CHANNEL_ID" => "CHUDDLE", "SLACK_BROWSER_TOKEN" => "xoxc", "SLACK_BROWSER_COOKIE" => "xoxd") { assert SlackHuddle.configured? }
    with_env("SLACK_HUDDLE_CHANNEL_ID" => nil, "SLACK_BROWSER_TOKEN" => "xoxc", "SLACK_BROWSER_COOKIE" => "xoxd") { assert_not SlackHuddle.configured? }
    with_env("SLACK_HUDDLE_CHANNEL_ID" => "CHUDDLE", "SLACK_BROWSER_TOKEN" => nil, "SLACK_BROWSER_COOKIE" => "xoxd") { assert_not SlackHuddle.configured? }
  end

  test "join starts or joins the channel's huddle" do
    fake = FakeBrowserClient.new("rooms.join" => {
      "ok" => true,
      "call" => { "call_id" => "R123", "free_willy" => {} },
      "huddle" => { "id" => "R123", "created_by" => "U0BOT", "participants" => [ { "user_id" => "U0BOT" }, "U0MEMBER" ] },
      "canvas" => { "thread_channel_id" => "CHUDDLE", "root_thread_ts" => "1700000000.000100" }
    })
    with_env("SLACK_HUDDLE_CHANNEL_ID" => "CHUDDLE") do
      stub_method(SlackHuddle, :client, fake) do
        room = SlackHuddle.join
        assert_equal "R123", room.call_id
        assert_equal "1700000000.000100", room.thread_ts
        assert_equal %w[U0BOT U0MEMBER], room.participant_ids
        assert room.active?
        assert_equal({ channel_id: "CHUDDLE", regions: "us-east-1", multidevice: "true" }, fake.calls.first.last)
      end
    end
  end

  test "room reports an ended huddle and nil for one Slack no longer knows" do
    fake = FakeBrowserClient.new("screenhero.rooms.info" => { "ok" => true, "room" => { "id" => "R123", "participants" => [], "has_ended" => true, "date_end" => 1700086400 } })
    stub_method(SlackHuddle, :client, fake) do
      room = SlackHuddle.room("R123")
      assert room.ended
      assert_not room.includes?("U0BOT")
    end

    gone = FakeBrowserClient.new("screenhero.rooms.info" => SlackBot::BrowserClient::Error.new("screenhero.rooms.info", "rooms_unauthorized_room"))
    stub_method(SlackHuddle, :client, gone) { assert_nil SlackHuddle.room("R404") }

    broken = FakeBrowserClient.new("screenhero.rooms.info" => SlackBot::BrowserClient::Error.new("screenhero.rooms.info", "invalid_auth"))
    stub_method(SlackHuddle, :client, broken) { assert_raises(SlackBot::BrowserClient::Error) { SlackHuddle.room("R123") } }
  end

  test "left? spots the bot's huddle ending or the bot leaving it, and nothing else" do
    fake = FakeBrowserClient.new("auth.test" => { "ok" => true, "user_id" => "U0BOT" })
    stub_method(SlackHuddle, :client, fake) do
      assert SlackHuddle.left?({ "type" => "sh_room_update", "room" => { "call_id" => "R123" }, "huddle" => { "has_ended" => true } }, "R123")
      assert SlackHuddle.left?({ "type" => "sh_room_update", "huddle" => { "id" => "R123", "date_end" => 1700086400 } }, "R123")
      assert_not SlackHuddle.left?({ "type" => "sh_room_update", "huddle" => { "id" => "R123", "participants" => [] } }, "R123")
      assert_not SlackHuddle.left?({ "type" => "sh_room_update", "huddle" => { "id" => "R999", "has_ended" => true } }, "R123")
      assert SlackHuddle.left?({ "type" => "sh_room_leave", "call_id" => "R123", "user" => "U0BOT" }, "R123")
      assert_not SlackHuddle.left?({ "type" => "sh_room_leave", "call_id" => "R123", "user" => "U0MEMBER" }, "R123")
      assert_not SlackHuddle.left?({ "type" => "sh_room_join", "call_id" => "R123", "user" => "U0BOT" }, "R123")
      assert_not SlackHuddle.left?({ "type" => "sh_room_update", "huddle" => { "id" => "R123", "has_ended" => true } }, nil)
    end
  end
end
