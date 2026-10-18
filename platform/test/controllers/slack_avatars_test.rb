require "test_helper"

class SlackAvatarsTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper

  setup do
    @cache = Rails.cache
    Rails.cache = ActiveSupport::Cache::MemoryStore.new
  end

  teardown { Rails.cache = @cache }

  # Answers users.lookupByEmail with profile_for's result (a profile hash, or an exception to raise).
  def with_fake_lookup(profile_for)
    fake = FakeSlackClient.new
    fake.define_singleton_method(:users_lookupByEmail) do |email:|
      calls << [ :users_lookupByEmail, { email: email } ]
      profile = profile_for.call(email)
      raise profile if profile.is_a?(Exception)

      Slack::Messages::Message.new("user" => { "profile" => profile })
    end
    fake.define_singleton_method(:users_info) do |user:|
      calls << [ :users_info, { user: user } ]
      Slack::Messages::Message.new("user" => { "profile" => profile_for.call(user) })
    end
    SlackAvatars.instance_variable_set(:@client, fake)
    with_env("SLACK_LOOKUP_TOKEN" => "xoxb-lookup") { yield fake }
  ensure
    SlackAvatars.instance_variable_set(:@client, nil)
  end

  test "looks the picture up in a job and answers once it is cached" do
    with_fake_lookup(->(_) { { "image_192" => "https://avatars.slack-edge.com/a_192.png" } }) do |slack|
      assert_enqueued_jobs 1, only: SlackAvatarJob do
        post slack_avatar_path, params: { email: " Orpheus@HackClub.com " }, as: :json
        post slack_avatar_path, params: { email: "orpheus@hackclub.com" }, as: :json
      end
      assert_response :accepted

      perform_enqueued_jobs
      assert_equal [ { email: "orpheus@hackclub.com" } ], slack.calls_to(:users_lookupByEmail)

      post slack_avatar_path, params: { email: "orpheus@hackclub.com" }, as: :json
      assert_response :success
      assert_equal "https://avatars.slack-edge.com/a_192.png", response.parsed_body["url"]
    end
  end

  test "answers a real Gravatar, asking for no fallback" do
    picture = "https://secure.gravatar.com/avatar/real.jpg?s=192&d=https%3A%2F%2Fa.slack-edge.com%2Fava_0013-192.png"
    stub_method(SlackAvatars, :gravatar?, true) do
      with_fake_lookup(->(_) { { "image_192" => picture } }) do
        post slack_avatar_path, params: { email: "grav@hackclub.com" }, as: :json
        perform_enqueued_jobs
        post slack_avatar_path, params: { email: "grav@hackclub.com" }, as: :json
        assert_equal "https://secure.gravatar.com/avatar/real.jpg?d=404&s=192", response.parsed_body["url"]
      end
    end
  end

  test "answers nothing for Slack's default picture or someone not in Slack" do
    default_art = "https://secure.gravatar.com/avatar/x.jpg?d=https%3A%2F%2Fa.slack-edge.com%2Fdf10d%2Fimg%2Favatars%2Fava_0013-192.png"
    stub_method(SlackAvatars, :gravatar?, false) do
      with_fake_lookup(lambda { |email|
        next Slack::Web::Api::Errors::UsersNotFound.new("users_not_found") if email.start_with?("nobody")

        { "is_custom_image" => true, "image_192" => default_art }
      }) do
        %w[plain@hackclub.com nobody@hackclub.com].each do |email|
          post slack_avatar_path, params: { email: email }, as: :json
          perform_enqueued_jobs
          post slack_avatar_path, params: { email: email }, as: :json
          assert_response :success
          assert_nil response.parsed_body["url"]
        end
      end
    end
  end

  test "uses the Slack account HCA linked to a Fallen account, whatever email Slack has" do
    pictures = { "U0MEMBER" => "https://avatars.slack-edge.com/member_192.png" }
    with_fake_lookup(->(key) { { "image_192" => pictures.fetch(key, "https://secure.gravatar.com/x.jpg") } }) do |slack|
      post slack_avatar_path, params: { email: users(:member).email }, as: :json
      perform_enqueued_jobs
      post slack_avatar_path, params: { email: users(:member).email }, as: :json

      assert_equal "https://avatars.slack-edge.com/member_192.png", response.parsed_body["url"]
      assert_empty slack.calls_to(:users_lookupByEmail)
    end
  end

  test "refuses something that isn't an email" do
    post slack_avatar_path, params: { email: "not an email" }, as: :json
    assert_response :unprocessable_content
  end
end
