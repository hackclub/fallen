require "test_helper"

module ApplicationCable
  class ConnectionTest < ActionCable::Connection::TestCase
    test "connects the signed-in user" do
      connect session: { user_id: users(:member).id }
      assert_equal users(:member), connection.current_user
    end

    test "turns away anyone not signed in" do
      assert_reject_connection { connect }
    end
  end
end
