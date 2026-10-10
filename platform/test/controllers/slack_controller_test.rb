require "test_helper"

class SlackControllerTest < ActionDispatch::IntegrationTest
  SECRET = "test-signing-secret"

  setup do
    @previous_secret = Slack::Events.config.signing_secret
    Slack::Events.config.signing_secret = SECRET
  end

  teardown do
    Slack::Events.config.signing_secret = @previous_secret
  end

  test "rejects unsigned requests" do
    post slack_events_path, params: { type: "url_verification", challenge: "x" }.to_json, headers: { "Content-Type" => "application/json" }
    assert_response :unauthorized
  end

  test "answers the url verification challenge" do
    post_signed slack_events_path, { type: "url_verification", challenge: "hello" }.to_json, "application/json"
    assert_response :success
    assert_equal "hello", response.parsed_body["challenge"]
  end

  test "enqueues events" do
    body = { type: "event_callback", event: { type: "app_mention", user: "U1", channel: "C1", ts: "1.2", text: "hi" } }.to_json
    assert_enqueued_with(job: SlackEventJob) do
      post_signed slack_events_path, body, "application/json"
    end
    assert_response :success
  end

  test "runs slash commands inline and returns the response" do
    form = URI.encode_www_form(command: "/ping", text: "", user_id: users(:member).slack_id, channel_id: "C1", response_url: "https://hooks.slack.test/x")
    post_signed slack_commands_path, form, "application/x-www-form-urlencoded"
    assert_response :success
    assert_equal "ephemeral", response.parsed_body["response_type"]
    assert_includes response.parsed_body["blocks"].first["text"]["text"], users(:member).display_name
  end

  test "unknown commands ack with 200" do
    form = URI.encode_www_form(command: "/nope", text: "", user_id: "U1")
    post_signed slack_commands_path, form, "application/x-www-form-urlencoded"
    assert_response :success
    assert_empty response.body
  end

  test "view submissions can return validation errors" do
    payload = { type: "view_submission", user: { id: "U1" }, view: { callback_id: "feedback", state: { values: { message: { message: { type: "plain_text_input", value: "short" } } } } } }
    post_signed slack_interactions_path, URI.encode_www_form(payload: payload.to_json), "application/x-www-form-urlencoded"
    assert_response :success
    assert_equal "errors", response.parsed_body["response_action"]
    assert response.parsed_body["errors"]["message"].present?
  end

  private

  def post_signed(path, body, content_type)
    timestamp = Time.now.to_i.to_s
    signature = "v0=" + OpenSSL::HMAC.hexdigest("SHA256", SECRET, "v0:#{timestamp}:#{body}")
    post path, params: body, headers: {
      "Content-Type" => content_type,
      "X-Slack-Request-Timestamp" => timestamp,
      "X-Slack-Signature" => signature
    }
  end
end
