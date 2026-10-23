require "test_helper"

class AuthTest < ActionDispatch::IntegrationTest
  test "sign in start falls back to the dev login when HCA is not configured" do
    get sign_in_path
    assert_redirected_to dev_path
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

  test "sign in start passes the email to fill in on to HCA" do
    with_env("HCA_CLIENT_ID" => "id", "HCA_CLIENT_SECRET" => "secret") do
      get sign_in_path(login_hint: "someone@example.com")
      assert_equal "someone@example.com", Rack::Utils.parse_query(URI(response.location).query)["login_hint"]
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

  test "a new account keeps the UTM tags and referrer of its first visit" do
    with_env("HCA_CLIENT_ID" => "id", "HCA_CLIENT_SECRET" => "secret") do
      get root_path(utm_source: "reddit", utm_campaign: "launch", ref: "ysws", junk: "x"), headers: { "Referer" => "https://www.reddit.com/r/hackclub/comments/abc?share=me" }
      get root_path(utm_source: "later")

      sign_in_through_hca("hca_tagged")

      source = User.find_by!(hca_id: "hca_tagged").signup_source
      assert_equal "reddit", source["utm_source"]
      assert_equal "launch", source["utm_campaign"]
      assert_equal "ysws", source["ref"]
      assert_equal "https://www.reddit.com/r/hackclub/comments/abc", source["referrer"]
      assert_equal "/", source["landing_path"]
      assert_not source.key?("junk")
      assert cookies[:signup_source].blank?
    end
  end

  test "signing in to an existing account leaves its signup source alone" do
    with_env("HCA_CLIENT_ID" => "id", "HCA_CLIENT_SECRET" => "secret") do
      member = users(:member)
      get root_path(utm_source: "newsletter")
      sign_in_through_hca(member.hca_id)

      assert_equal({}, member.reload.signup_source)
    end
  end

  test "a callback loaded twice signs the second one in as whoever the first was, without redeeming the code again" do
    cache = Rails.cache
    Rails.cache = ActiveSupport::Cache::MemoryStore.new
    with_env("HCA_CLIENT_ID" => "id", "HCA_CLIENT_SECRET" => "secret") do
      get sign_in_path
      state = Rack::Utils.parse_query(URI(response.location).query)["state"]
      duplicate = open_session
      duplicate.cookies[:oauth_state] = cookies[:oauth_state]

      sign_in_through_hca(users(:member).hca_id, state: state)
      stub_method(HCA, :exchange_code_for_token, nil) { duplicate.get hca_callback_path(code: "abc", state: state) }

      duplicate.assert_redirected_to home_path
      assert_equal users(:member).id, duplicate.session[:user_id]
    end
  ensure
    Rails.cache = cache
  end

  test "two sign-ins at once for a new person end up in the same account" do
    original = User.method(:joined_from_slack)
    # The other tab saves the account between this one looking for it and saving its own.
    User.define_singleton_method(:joined_from_slack) do |slack_id|
      User.create!(hca_id: "hca_race", email: "race@example.com", display_name: "Racer", roles: [ "user" ]) unless User.exists?(hca_id: "hca_race")
      original.call(slack_id)
    end
    with_env("HCA_CLIENT_ID" => "id", "HCA_CLIENT_SECRET" => "secret") do
      assert_difference -> { User.count }, 1 do
        sign_in_through_hca("hca_race")
      end
    end
    assert_nil flash[:alert]
    assert_equal User.find_by(hca_id: "hca_race").id, session[:user_id]
  ensure
    User.define_singleton_method(:joined_from_slack, original)
  end

  test "visits without tags or another site's referrer remember nothing" do
    get root_path, headers: { "Referer" => "http://www.example.com/somewhere" }
    assert cookies[:signup_source].blank?
  end

  test "sign out clears the session" do
    sign_in_as users(:member)
    delete sign_out_path
    assert_redirected_to root_path
    get home_path
    assert_redirected_to root_path
  end

  private

  def sign_in_through_hca(hca_id, state: nil)
    state ||= begin
      get sign_in_path
      Rack::Utils.parse_query(URI(response.location).query)["state"]
    end
    stub_method(HCA, :exchange_code_for_token, { "access_token" => "tok" }) do
      stub_method(HCA, :identity, { "id" => hca_id, "primary_email" => "#{hca_id}@example.com" }) do
        get hca_callback_path(code: "abc", state: state)
      end
    end
  end
end
