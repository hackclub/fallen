require "test_helper"
require Rails.root.join("config/warmup").to_s

# Warmup (config/warmup.rb) drops any request that does not answer 2xx and only logs it, so a change to sign-in or a
# route would quietly turn it into warming the redirect. This keeps every page it warms reachable.
class WarmupTest < ActionDispatch::IntegrationTest
  test "every page it warms answers as the signed-in person" do
    user = users(:member)
    assert user.projects.kept.exists?, "the fixture needs a project so the project pages are warmed"

    requests = Warmup.requests_for(user)

    assert_equal 9, requests.size, "dropped: check the [warmup] lines in log/test.log"
  end

  test "its requests skip Rack::Attack" do
    env = Rack::MockRequest.env_for("/", Warmup::ENV_KEY => true)
    assert Rack::Attack.configuration.safelisted?(Rack::Attack::Request.new(env))
  end
end
