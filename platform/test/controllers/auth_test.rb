require "test_helper"

class AuthTest < ActionDispatch::IntegrationTest
  test "sign in start explains when HCA is not configured" do
    get sign_in_path
    assert_redirected_to root_path
    assert_match(/not configured/, flash[:alert])
  end

  test "sign in start redirects to HCA with a state stored in a cookie" do
    with_env("HCA_CLIENT_ID" => "id", "HCA_CLIENT_SECRET" => "secret") do
      get sign_in_path
      assert_response :redirect
      assert_match %r{\Ahttps://hca\.dinosaurbbq\.org/oauth/authorize\?}, response.location
      state = Rack::Utils.parse_query(URI(response.location).query)["state"]
      assert_equal 48, state.length
      assert cookies[:oauth_state].present?
    end
  end

  test "callback rejects a state mismatch" do
    get hca_callback_path(code: "abc", state: "nope")
    assert_redirected_to root_path
    assert_match(/state mismatch/, flash[:alert])
  end

  test "callback creates the user, signs them in and returns to the requested page" do
    with_env("HCA_CLIENT_ID" => "id", "HCA_CLIENT_SECRET" => "secret") do
      get home_path
      assert_redirected_to root_path

      get sign_in_path
      state = Rack::Utils.parse_query(URI(response.location).query)["state"]

      identity = { "id" => "hca_new", "primary_email" => "new@example.com", "first_name" => "New", "last_name" => "Person", "slack_id" => "U0NEW" }
      stub_method(HCA, :exchange_code_for_token, { "access_token" => "tok" }) do
        stub_method(HCA, :identity, identity) do
          assert_difference("User.count", 1) do
            assert_enqueued_with(job: SyncSlackProfileJob) do
              get hca_callback_path(code: "abc", state: state)
            end
          end
        end
      end

      assert_redirected_to home_path
      user = User.find_by!(hca_id: "hca_new")
      assert_equal user.id, session[:user_id]
      assert_equal "New Person", user.display_name

      get hca_callback_path(code: "abc", state: state)
      assert_match(/state mismatch/, flash[:alert], "states are single use")
    end
  end

  test "sign out clears the session" do
    sign_in_as users(:member)
    delete sign_out_path
    assert_redirected_to root_path
    get home_path
    assert_redirected_to root_path
  end
end
