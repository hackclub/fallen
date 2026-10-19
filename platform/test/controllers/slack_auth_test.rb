require "test_helper"

class SlackAuthTest < ActionDispatch::IntegrationTest
  test "connects a Slack account" do
    user = User.create!(hca_id: "hca_fresh", email: "fresh@example.com", display_name: "Fresh", roles: [ "user" ])
    connect(user, slack_id: "U0FRESH")
    assert_match(/Slack connected/, flash[:notice])
    assert_equal "U0FRESH", user.reload.slack_id
  end

  test "posts the threads of projects made before connecting" do
    user = User.create!(hca_id: "hca_fresh", email: "fresh@example.com", display_name: "Fresh", roles: [ "user" ])
    project = user.projects.create!(title: "Made during onboarding")
    assert_enqueued_with(job: PostProjectToSlackJob, args: [ project ]) { connect(user, slack_id: "U0FRESH") }
  end

  test "returns to the page that asked" do
    user = User.create!(hca_id: "hca_fresh", email: "fresh@example.com", display_name: "Fresh", roles: [ "user" ])
    connect(user, slack_id: "U0FRESH", return_to: "/settings#slack")
    assert_redirected_to "/settings#slack"
  end

  test "ignores a return_to on another host" do
    user = User.create!(hca_id: "hca_fresh", email: "fresh@example.com", display_name: "Fresh", roles: [ "user" ])
    [ "//evil.example/phish", "/\\evil.example/phish", "https://evil.example" ].each do |target|
      connect(user, slack_id: "U0FRESH", return_to: target)
      assert_redirected_to projects_path
    end
  end

  test "refuses a Slack account already connected to someone else" do
    user = User.create!(hca_id: "hca_fresh", email: "fresh@example.com", display_name: "Fresh", roles: [ "user" ])
    connect(user, slack_id: users(:member).slack_id)
    assert_match(/already connected to another/, flash[:alert])
    assert_nil user.reload.slack_id
  end

  test "skipping slack posts the threads of projects made before, through the bot" do
    user = User.create!(hca_id: "hca_fresh", email: "fresh@example.com", display_name: "Fresh", roles: [ "user" ], pet: "lulu")
    project = user.projects.create!(title: "Made during onboarding")
    sign_in_as user

    assert_enqueued_with(job: PostProjectToSlackJob, args: [ project ]) { post skip_slack_path }
    assert user.reload.slack_ready?
  end

  test "disconnecting counts as choosing the bot" do
    sign_in_as users(:member)
    with_fake_slack { delete disconnect_slack_path }
    assert users(:member).reload.slack_ready?
    assert_not users(:member).slack_connected?
  end

  private

  def connect(user, slack_id:, return_to: nil)
    sign_in_as user
    with_env("SLACK_CLIENT_ID" => "id", "SLACK_CLIENT_SECRET" => "secret") do
      get connect_slack_path(return_to: return_to)
      state = Rack::Utils.parse_query(URI(response.location).query)["state"]
      stub_method(SlackMessaging, :exchange_code, { "id" => slack_id, "access_token" => "xoxp-new", "scope" => "chat:write" }) do
        get slack_callback_path(code: "abc", state: state)
      end
    end
  end
end
