require "test_helper"

class PayloadTest < ActiveSupport::TestCase
  test "dot access, nested wrapping and nil for missing keys" do
    payload = SlackBot::Payload.wrap({ "event" => { "type" => "app_mention", "user" => "U1" }, "actions" => [ { "action_id" => "a:1" } ] })
    assert_equal "app_mention", payload.event.type
    assert_equal "a:1", payload.actions.first.action_id
    assert_nil payload.event.thread_ts
    assert_nil payload.missing
    assert_equal "U1", payload.dig("event", "user")
  end

  test "manifest lists handlers" do
    manifest = SlackBot::Manifest.generate(app_url: "https://example.com", name: "Test")
    commands = manifest.dig("features", "slash_commands").map { |c| c["command"] }
    assert_includes commands, "/ping"
    assert_includes commands, "/fallen-feedback"
    assert_includes manifest.dig("settings", "event_subscriptions", "bot_events"), "app_mention"
  end
end
