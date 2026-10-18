require "test_helper"

# Starting with just an email (TrialSessionsController), then signing in with HCA to keep going.
class TrialSessionsTest < ActionDispatch::IntegrationTest
  test "a new email gets a trial account and starts the onboarding" do
    assert_difference("User.count", 1) { post trial_session_path, params: { email: " New@Example.com " } }
    assert_redirected_to home_path

    user = User.find(session[:user_id])
    assert user.trial?
    assert_equal "new@example.com", user.email
    assert_equal "new", user.display_name
    assert_equal "onboarding", setup_prop["step"]
  end

  test "the same browser and email picks the trial account back up" do
    post trial_session_path, params: { email: "back@example.com" }
    first = session[:user_id]
    delete sign_out_path

    assert_no_difference("User.count") { post trial_session_path, params: { email: "back@example.com" } }
    assert_equal first, session[:user_id]
  end

  test "an email with an account here goes to HCA with it filled in" do
    member = users(:member)
    assert_no_difference("User.count") do
      post trial_session_path, params: { email: member.email }, headers: inertia_headers
    end
    assert_response :conflict
    assert_equal sign_in_path(login_hint: member.email), response.headers["X-Inertia-Location"]
  end

  test "an invalid email is turned away" do
    assert_no_difference("User.count") { post trial_session_path, params: { email: "nope" } }
    assert_redirected_to root_path
  end

  test "a trial account can make a project but is sent to HCA from the rest" do
    post trial_session_path, params: { email: "try@example.com" }

    post projects_path, params: { project: { title: "Hovercraft" } }
    assert_equal [ "Hovercraft" ], User.find(session[:user_id]).projects.pluck(:title)

    get settings_path
    assert_redirected_to sign_in_path(login_hint: "try@example.com")
    get settings_path, headers: inertia_headers
    assert_equal sign_in_path(login_hint: "try@example.com"), response.headers["X-Inertia-Location"]
  end

  test "after picking a pet, a trial account is asked to sign in with HCA" do
    post trial_session_path, params: { email: "pet@example.com" }
    patch pet_path, params: { pet: "lulu" }
    assert_equal({ "step" => "verify", "email" => "pet@example.com" }, setup_prop)
  end

  test "signing in with a new HCA account turns the trial account into it" do
    post trial_session_path, params: { email: "up@example.com" }
    trial = User.find(session[:user_id])
    trial.update!(pet: "sami")
    trial.projects.create!(title: "Hovercraft")

    assert_no_difference("User.count") { sign_in_through_hca("hca_up") }

    assert_redirected_to home_path
    assert_equal trial.id, session[:user_id]
    trial.reload
    assert_not trial.trial?
    assert_equal "hca_up", trial.hca_id
    assert_equal "sami", trial.pet
    assert cookies[TrialSessionsController::COOKIE].blank?
  end

  test "signing in with an existing HCA account moves the trial account's project over" do
    member = users(:member)
    post trial_session_path, params: { email: "other@example.com" }
    trial = User.find(session[:user_id])
    project = trial.projects.create!(title: "Hovercraft")

    sign_in_through_hca(member.hca_id)

    assert_equal member.id, session[:user_id]
    assert_equal member.id, project.reload.user_id
    assert trial.reload.discarded?
  end

  test "trial accounts are on no team" do
    user = User.start_trial!(email: "team@example.com")
    user.update!(pet: "lulu")
    assert_not_includes User.on_a_team, user
  end

  private

  def inertia_headers = { "X-Inertia" => "true", "X-Inertia-Version" => InertiaRails.configuration.version.to_s }

  def setup_prop
    get home_path, headers: inertia_headers
    assert_response :success
    response.parsed_body["props"]["setup"]
  end

  def sign_in_through_hca(hca_id)
    with_env("HCA_CLIENT_ID" => "id", "HCA_CLIENT_SECRET" => "secret") do
      get sign_in_path
      state = Rack::Utils.parse_query(URI(response.location).query)["state"]
      stub_method(HCA, :exchange_code_for_token, { "access_token" => "tok" }) do
        stub_method(HCA, :identity, { "id" => hca_id, "primary_email" => "#{hca_id}@example.com" }) do
          get hca_callback_path(code: "abc", state: state)
        end
      end
    end
  end
end
