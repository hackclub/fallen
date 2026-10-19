require "test_helper"

# Fallout's email links, /?email=…&code=… (FalloutLinksController).
class FalloutLinksTest < ActionDispatch::IntegrationTest
  setup do
    Rack::Attack.reset! # Every test here uses the same email, which is throttled
    FalloutInvite.create!(digest: FalloutInvite.digest("fan@example.com", "PPTMPR"))
  end

  test "a matching code makes a trial account and signs it in" do
    assert_difference("User.count", 1) { get root_path(email: " Fan@Example.com ", code: "pptmpr", utm_source: "fallout-email") }
    assert_redirected_to home_path

    user = User.find(session[:user_id])
    assert user.trial?
    assert_equal "fan@example.com", user.email
    assert_equal "fallout-email", user.signup_source["utm_source"]
    assert_equal "/", user.signup_source["landing_path"]
  end

  test "a wrong code or email makes nothing and lands on the page without them" do
    [ { email: "fan@example.com", code: "PPTMPX" }, { email: "other@example.com", code: "PPTMPR" }, { email: "fan@example.com", code: "" },
      { email: [ "fan@example.com" ], code: { a: "PPTMPR" } } ].each do |params|
      assert_no_difference("User.count") { get root_path(params) }
      assert_redirected_to root_path
      assert_nil session[:user_id]
    end
  end

  test "the same browser picks its trial account back up" do
    get root_path(email: "fan@example.com", code: "PPTMPR")
    first = session[:user_id]
    delete sign_out_path

    assert_no_difference("User.count") { get root_path(email: "fan@example.com", code: "PPTMPR") }
    assert_equal first, session[:user_id]
  end

  test "picks up the account the Slack join button made" do
    joined = User.create!(email: "fan@example.com", display_name: "fan", slack_id: "U0FAN1234", roles: [ "user" ])
    assert_no_difference("User.count") { get root_path(email: "fan@example.com", code: "PPTMPR") }
    assert_equal joined.id, session[:user_id]
  end

  test "never signs in to a trial account someone else made from the email form" do
    other = User.start_trial!(email: "fan@example.com")
    assert_difference("User.count", 1) { get root_path(email: "fan@example.com", code: "PPTMPR") }
    assert_not_equal other.id, session[:user_id]
  end

  test "an email with a Hack Club Auth account goes to sign in with it" do
    member = users(:member)
    FalloutInvite.create!(digest: FalloutInvite.digest(member.email, "HKXDDX"))
    assert_no_difference("User.count") { get root_path(email: member.email, code: "HKXDDX") }
    assert_redirected_to sign_in_path(login_hint: member.email)
    assert_nil session[:user_id]
  end

  test "someone signed in keeps their session" do
    sign_in_as users(:member)
    get root_path(email: "fan@example.com", code: "PPTMPR")
    assert_redirected_to home_path
    assert_equal users(:member).id, session[:user_id]
  end

  test "guessing codes for one email is cut off" do
    10.times { |i| get root_path(email: "fan@example.com", code: "AAAAA#{('A'..'Z').to_a[i]}") }
    get root_path(email: "fan@example.com", code: "PPTMPR")
    assert_response :too_many_requests
    assert_nil session[:user_id]
  end

  test "the landing page without a code is untouched" do
    get root_path(email: "fan@example.com")
    assert_response :success
  end
end
