require "test_helper"

class SlackJoinsTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper

  SECRET = "join-secret"

  setup do
    @fake = FakeSlackClient.new
    @fake.define_singleton_method(:users_info) do |user:|
      calls << [ :users_info, { user: user } ]
      Slack::Messages::Message.new("user" => { "id" => user, "tz" => "America/New_York", "profile" => { "email" => "Joiner@Example.com", "display_name" => "joiner" } })
    end
    SlackAvatars.instance_variable_set(:@client, @fake)
  end

  teardown { SlackAvatars.instance_variable_set(:@client, nil) }

  test "makes a trial account from the Slack profile" do
    with_join_env do
      assert_enqueued_jobs 1, only: SlackJoinJob do
        post slack_join_path, params: { slack_id: "u0joiner1", utm_source: "slack", utm_campaign: "launch", junk: "x" }, headers: auth, as: :json
      end
      assert_response :accepted

      assert_difference("User.count", 1) { perform_enqueued_jobs }
      user = User.find_by!(slack_id: "U0JOINER1")
      assert user.trial?
      assert_equal "joiner@example.com", user.email
      assert_equal "joiner", user.display_name
      assert_equal "America/New_York", user.timezone
      assert_equal({ "ref" => "slack-join", "utm_source" => "slack", "utm_campaign" => "launch", "landing_path" => "/api/slack/join" }, user.signup_source)

      post slack_join_path, params: { slack_id: "U0JOINER1" }, headers: auth, as: :json
      assert_response :success
      assert_equal({ "ok" => true, "created" => false, "user_id" => user.public_id, "signed_in" => false }, response.parsed_body)
    end
  end

  test "takes the secret and Slack ID however a sloppy sender puts them" do
    with_join_env do
      assert_enqueued_with(job: SlackJoinJob, args: [ "U0JOINER2", { "ref" => "ysws" } ]) do
        post slack_join_path(secret: SECRET, user_id: "U0JOINER2", ref: "ysws")
      end
      assert_response :accepted
      post slack_join_path, params: { user: { id: "U0JOINER3" } }.to_json, headers: { "X-Fallen-Secret" => SECRET, "Content-Type" => "text/plain" }
      assert_response :accepted
      post slack_join_path, params: "slackId=U0JOINER4", headers: auth.merge("Content-Type" => "application/x-www-form-urlencoded")
      assert_response :accepted
    end
  end

  test "rejects a wrong or missing secret and a malformed Slack ID" do
    post slack_join_path, params: { slack_id: "U0JOINER1" }, as: :json
    assert_response :unauthorized, "no secret configured"

    with_join_env do
      post slack_join_path, params: { slack_id: "U0JOINER1" }, headers: { "Authorization" => "Bearer wrong" }, as: :json
      assert_response :unauthorized
      post slack_join_path, params: { slack_id: "not a slack id" }, headers: auth, as: :json
      assert_response :bad_request
    end
    assert_no_enqueued_jobs only: SlackJoinJob
  end

  test "makes nothing when someone already has the Slack ID or the email" do
    with_join_env do
      member = users(:member)
      assert_no_difference("User.count") { User.join_from_slack!(member.slack_id) }
      assert_empty @fake.calls_to(:users_info)

      User.start_trial!(email: "joiner@example.com")
      assert_no_difference("User.count") { User.join_from_slack!("U0JOINER1") }
    end
  end

  test "signing in with Hack Club Auth claims the account" do
    with_join_env do
      joined = User.join_from_slack!("U0JOINER1")
      get sign_in_path
      state = Rack::Utils.parse_query(URI(response.location).query)["state"]
      identity = { "id" => "hca_joiner", "primary_email" => "joiner@hackclub.com", "slack_id" => "U0JOINER1" }
      stub_method(HCA, :exchange_code_for_token, { "access_token" => "tok" }) do
        stub_method(HCA, :identity, identity) do
          assert_no_difference("User.count") { get hca_callback_path(code: "abc", state: state) }
        end
      end

      joined.reload
      assert_equal "hca_joiner", joined.hca_id
      assert_equal joined.id, session[:user_id]
      assert_equal "slack-join", joined.signup_source["ref"]
    end
  end

  private

  def auth = { "Authorization" => "Bearer #{SECRET}" }

  def with_join_env(&) = with_env("SLACK_JOIN_SECRET" => SECRET, "SLACK_LOOKUP_TOKEN" => "xoxb-lookup", "HCA_CLIENT_ID" => "id", "HCA_CLIENT_SECRET" => "secret", &)
end
