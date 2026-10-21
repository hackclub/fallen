require "test_helper"

# ApplicationController#setup_props: the onboarding, then Slack, then everything else.
class SetupTest < ActionDispatch::IntegrationTest
  test "a newcomer starts the onboarding" do
    sign_in_as users(:newcomer)
    assert_equal({ "step" => "onboarding", "project" => nil, "joined_with" => nil, "rules" => Team.rules.as_json, "goals" => DailyGoal.preview(users(:newcomer)).as_json }, setup_prop)
  end

  test "the onboarding resumes after the project it made" do
    users(:newcomer).projects.create!(title: "Hovercraft")
    sign_in_as users(:newcomer)
    assert_equal({ "step" => "onboarding", "project" => "Hovercraft", "joined_with" => nil, "rules" => Team.rules.as_json, "goals" => DailyGoal.preview(users(:newcomer)).as_json }, setup_prop)
  end

  test "someone who joined a team in the onboarding is not asked to make a project" do
    sign_in_as users(:newcomer)
    projects(:station).memberships.create!(user: users(:newcomer))
    setup = setup_prop
    assert_equal "Weather station", setup["project"]
    assert_equal users(:member).display_name, setup["joined_with"]
  end

  test "after the onboarding, Slack" do
    users(:newcomer).update!(pet: "lulu")
    sign_in_as users(:newcomer)
    with_env("SLACK_CLIENT_ID" => "id", "SLACK_CLIENT_SECRET" => "secret") do
      assert_equal({ "step" => "slack" }, setup_prop)
    end
  end

  test "nothing left once Slack is skipped" do
    users(:newcomer).update!(pet: "lulu", slack_skipped_at: Time.current)
    sign_in_as users(:newcomer)
    with_env("SLACK_CLIENT_ID" => "id", "SLACK_CLIENT_SECRET" => "secret") do
      assert_nil setup_prop
    end
  end

  test "nothing left once Slack is connected" do
    sign_in_as users(:member)
    assert_nil setup_prop
  end

  test "nothing while impersonating" do
    sign_in_as users(:admin)
    post impersonate_admin_user_path(users(:newcomer))
    assert_nil setup_prop
  end

  private

  def setup_prop
    get home_path, headers: { "X-Inertia" => "true", "X-Inertia-Version" => InertiaRails.configuration.version.to_s }
    assert_response :success
    response.parsed_body["props"]["setup"]
  end
end
