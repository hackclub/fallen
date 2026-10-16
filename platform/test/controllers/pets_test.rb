require "test_helper"

class PetsTest < ActionDispatch::IntegrationTest
  test "picks a pet" do
    sign_in_as users(:newcomer)
    patch pet_path, params: { pet: "sami" }
    assert_redirected_to home_path
    assert_equal "sami", users(:newcomer).reload.pet
  end

  test "refuses a pet that does not exist" do
    sign_in_as users(:newcomer)
    patch pet_path, params: { pet: "dragon" }
    assert_match(/doesn't exist/, flash[:alert])
    assert_nil users(:newcomer).reload.pet
  end

  test "needs a session" do
    patch pet_path, params: { pet: "lulu" }
    assert_nil users(:newcomer).reload.pet
    assert_response :redirect
  end
end
