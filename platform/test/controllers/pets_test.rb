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

  test "switches freely up to the first journal" do
    user = users(:newcomer)
    user.update!(pet: "lulu")
    sign_in_as user
    patch pet_path, params: { pet: "sami" }
    patch pet_path, params: { pet: "lulu" }
    assert_equal "lulu", user.reload.pet
  end

  test "switches once a week after the first journal, the weeks starting on its weekday" do
    user = users(:member)
    user.xp_entries.update_all(day: Date.new(2026, 10, 14)) # A Wednesday
    user.update!(xp_multiplier: 1.3)
    sign_in_as user

    travel_to Time.zone.local(2026, 10, 19, 12) do
      patch pet_path, params: { pet: "sami" }
      assert_equal "sami", user.reload.pet
      assert_equal 1.0, user.xp_multiplier

      patch pet_path, params: { pet: "lulu" }
      assert_match(/again on October 21, 2026/, flash[:alert])
      assert_equal "sami", user.reload.pet
    end

    travel_to Time.zone.local(2026, 10, 21, 12) do
      patch pet_path, params: { pet: "lulu" }
      assert_equal "lulu", user.reload.pet
    end
  end

  test "deleted journals count neither for the limit nor for the week" do
    user = users(:member)
    first, second = user.xp_entries.order(:id).to_a
    first.update!(day: Date.new(2026, 10, 12))
    second.update!(day: Date.new(2026, 10, 14), discarded_at: Time.current)
    user.update!(pet_switched_at: Time.zone.local(2026, 10, 19, 12))

    travel_to Time.zone.local(2026, 10, 20, 12) do
      assert user.pet_switch.allowed?, "one journal left, so switching is still free"
      second.update!(discarded_at: nil, day: Date.new(2026, 10, 16))
      assert_not user.pet_switch.allowed?
      assert_equal Date.new(2026, 10, 26), user.pet_switch.next_on
    end
  end

  test "needs a session" do
    patch pet_path, params: { pet: "lulu" }
    assert_nil users(:newcomer).reload.pet
    assert_response :redirect
  end
end
