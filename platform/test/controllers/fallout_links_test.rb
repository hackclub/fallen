require "test_helper"

# Fallout's email links, /?email=…&code=… (FalloutLinksController): a soft signup that never signs anyone in, made
# only once the landing page sees a person.
class FalloutLinksTest < ActionDispatch::IntegrationTest
  setup do
    Rack::Attack.reset! # Every test here uses the same email, which is throttled
    FalloutInvite.create!(digest: FalloutInvite.digest("fan@example.com", "PPTMPR"))
  end

  test "following the link makes nothing, so a mail scanner opening it signs no one up" do
    assert_no_difference("User.count") { get root_path(email: "fan@example.com", code: "PPTMPR") }
    assert_redirected_to root_path
    assert inertia_props(root_path, "Landing/Index")["pending_welcome"]
  end

  test "the page's post for a person makes a trial account without signing in" do
    get root_path(email: " Fan@Example.com ", code: "pptmpr", utm_source: "fallout-email")
    assert_difference("User.count", 1) { post welcome_path }
    assert_response :no_content
    assert_nil session[:user_id]

    user = User.find_by!(email: "fan@example.com")
    assert user.trial?
    assert_equal "fallout_link", user.soft_signup
    assert_equal "fan", user.display_name
    assert_equal({ "ref" => "fallout-link", "utm_source" => "fallout-email", "landing_path" => "/" }, user.signup_source)

    assert_no_difference("User.count") { post welcome_path }
    assert_not inertia_props(root_path, "Landing/Index")["pending_welcome"]
  end

  test "a wrong code or email leaves nothing to make and lands the same way" do
    [ { email: "fan@example.com", code: "PPTMPX" }, { email: "other@example.com", code: "PPTMPR" }, { email: "fan@example.com", code: "" },
      { email: [ "fan@example.com" ], code: { a: "PPTMPR" } } ].each do |params|
      get root_path(params)
      assert_redirected_to root_path
      assert_not inertia_props(root_path, "Landing/Index")["pending_welcome"]
      assert_no_difference("User.count") { post welcome_path }
    end
  end

  test "an email with any account already makes nothing" do
    User.start_trial!(email: "fan@example.com")
    get root_path(email: "fan@example.com", code: "PPTMPR")
    assert_no_difference("User.count") { post welcome_path }

    FalloutInvite.create!(digest: FalloutInvite.digest(users(:member).email, "HKXDDX"))
    get root_path(email: users(:member).email, code: "HKXDDX")
    assert_no_difference("User.count") { post welcome_path }
  end

  test "someone signed in stays who they are" do
    sign_in_as users(:member)
    get root_path(email: "fan@example.com", code: "PPTMPR")
    assert_redirected_to root_path
    assert_equal users(:member).id, session[:user_id]
  end

  test "guessing codes for one email is cut off" do
    10.times { |i| get root_path(email: "fan@example.com", code: "AAAAA#{('A'..'Z').to_a[i]}") }
    get root_path(email: "fan@example.com", code: "PPTMPR")
    assert_response :too_many_requests
    assert_no_difference("User.count") { post welcome_path }
  end

  test "signing in with Hack Club Auth claims it by email, and a trial made from the email form hands its project over" do
    get root_path(email: "fan@example.com", code: "PPTMPR")
    post welcome_path
    joined = User.find_by!(email: "fan@example.com")
    post trial_session_path, params: { email: "fan@example.com" }
    typed = User.find(session[:user_id])
    assert_not_equal joined, typed
    typed.projects.create!(title: "Hovercraft")

    sign_in_through_hca("id" => "hca_fan", "primary_email" => "Fan@Example.com")
    assert_equal joined.id, session[:user_id]
    assert_equal "hca_fan", joined.reload.hca_id
    assert_equal [ "Hovercraft" ], joined.projects.pluck(:title)
    assert typed.reload.discarded?
  end

  test "never claims a trial someone made from the email form, whoever's email it has" do
    post trial_session_path, params: { email: "fan@example.com" }
    typed = User.find(session[:user_id])
    delete sign_out_path

    assert_difference("User.count", 1) { sign_in_through_hca("id" => "hca_fan", "primary_email" => "fan@example.com") }
    assert_not_equal typed.id, session[:user_id]
    assert typed.reload.trial?
  end

  test "the page it lands on sends someone signed in to Hack Club Auth on to sign in, right code or not" do
    [ "PPTMPR", "PPTMPX" ].each do |code|
      get root_path(email: "fan@example.com", code: code)
      assert inertia_props(root_path, "Landing/Index")["continue_with_hca"]
      assert_not inertia_props(root_path, "Landing/Index")["continue_with_hca"]
    end
  end

  test "the landing page without a code is untouched" do
    props = inertia_props(root_path(email: "fan@example.com"), "Landing/Index")
    assert_not props["continue_with_hca"]
    assert_not props["pending_welcome"]
  end

  private

  def sign_in_through_hca(identity)
    with_env("HCA_CLIENT_ID" => "id", "HCA_CLIENT_SECRET" => "secret") do
      get sign_in_path
      state = Rack::Utils.parse_query(URI(response.location).query)["state"]
      stub_method(HCA, :exchange_code_for_token, { "access_token" => "tok" }) do
        stub_method(HCA, :identity, identity) { get hca_callback_path(code: "abc", state: state) }
      end
    end
  end
end
