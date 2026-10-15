require "test_helper"

class SlackAuthTest < ActionDispatch::IntegrationTest
  test "connects a Slack account" do
    user = User.create!(hca_id: "hca_fresh", email: "fresh@example.com", display_name: "Fresh", roles: [ "user" ])
    connect(user, slack_id: "U0FRESH")
    assert_match(/Slack connected/, flash[:notice])
    assert_equal "U0FRESH", user.reload.slack_id
  end

  test "refuses a Slack account already connected to someone else" do
    user = User.create!(hca_id: "hca_fresh", email: "fresh@example.com", display_name: "Fresh", roles: [ "user" ])
    connect(user, slack_id: users(:member).slack_id)
    assert_match(/already connected to another/, flash[:alert])
    assert_nil user.reload.slack_id
  end

  private

  def connect(user, slack_id:)
    sign_in_as user
    with_env("SLACK_CLIENT_ID" => "id", "SLACK_CLIENT_SECRET" => "secret") do
      get connect_slack_path
      state = Rack::Utils.parse_query(URI(response.location).query)["state"]
      stub_method(SlackMessaging, :exchange_code, { "id" => slack_id, "access_token" => "xoxp-new", "scope" => "chat:write" }) do
        get slack_callback_path(code: "abc", state: state)
      end
    end
  end
end
