require "test_helper"

class BrowserClientTest < ActiveSupport::TestCase
  test "posts the token and cookie like the desktop client and returns the body" do
    stubs = Faraday::Adapter::Test::Stubs.new
    stubs.post("/api/auth.test") do |env|
      assert_equal "d=xoxd-cookie", env.request_headers["Cookie"]
      assert_equal({ "token" => "xoxc-token", "foo" => "bar" }, Rack::Utils.parse_nested_query(env.body))
      [ 200, { "Content-Type" => "application/json" }, { ok: true, user_id: "U0BOT" }.to_json ]
    end
    assert_equal "U0BOT", client(stubs).call("auth.test", foo: "bar")["user_id"]
    stubs.verify_stubbed_calls
  end

  test "raises with Slack's error code" do
    stubs = Faraday::Adapter::Test::Stubs.new
    stubs.post("/api/screenhero.rooms.info") { [ 200, {}, { ok: false, error: "rooms_unauthorized_room" }.to_json ] }
    error = assert_raises(SlackBot::BrowserClient::Error) { client(stubs).call("screenhero.rooms.info", room: "R1") }
    assert_equal "rooms_unauthorized_room", error.code
  end

  test "raises on an HTTP failure" do
    stubs = Faraday::Adapter::Test::Stubs.new
    stubs.post("/api/rooms.join") { [ 503, {}, "" ] }
    assert_equal "http_503", assert_raises(SlackBot::BrowserClient::Error) { client(stubs).call("rooms.join") }.code
  end

  private

  def client(stubs)
    SlackBot::BrowserClient.new(token: "xoxc-token", cookie: "xoxd-cookie").tap do |client|
      connection = Faraday.new(url: "https://slack.com", headers: { "Cookie" => "d=xoxd-cookie" }) do |f|
        f.request :url_encoded
        f.adapter :test, stubs
      end
      client.instance_variable_set(:@connection, connection)
    end
  end
end
