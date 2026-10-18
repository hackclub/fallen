require "test_helper"

class RackAttackTest < ActiveSupport::TestCase
  test "signed-in requests count per person, so a room behind one IP shares nothing" do
    assert_equal 1, discriminator("req/user", request(user_id: 1))
    assert_equal 2, discriminator("req/user", request(user_id: 2))
    assert_nil discriminator("req/ip", request(user_id: 1))
  end

  test "signed-out requests count per IP" do
    assert_nil discriminator("req/user", request)
    assert_equal "203.0.113.7", discriminator("req/ip", request)
  end

  private

  def discriminator(name, req) = Rack::Attack.throttles.fetch(name).block.call(req)

  def request(user_id: nil)
    env = Rack::MockRequest.env_for("/home", "REMOTE_ADDR" => "203.0.113.7")
    env["rack.session"] = user_id ? { user_id: user_id } : {}
    Rack::Attack::Request.new(env)
  end
end
