require "test_helper"

class TimezoneTest < ActionDispatch::IntegrationTest
  test "browser timezone header updates the user" do
    sign_in_as users(:member)
    get home_path, headers: { "X-Browser-Timezone" => "Europe/Berlin" }
    assert_equal "Europe/Berlin", users(:member).reload.timezone

    get home_path, headers: { "X-Browser-Timezone" => "Not/AZone" }
    assert_equal "Europe/Berlin", users(:member).reload.timezone
  end

  test "after the first, a change waits a week, and every change and the first refusal for each zone are logged" do
    user = users(:member)
    sign_in_as user
    get home_path, headers: { "X-Browser-Timezone" => "Asia/Kolkata" }
    assert_equal "Asia/Kolkata", user.reload.timezone

    travel 1.day
    2.times { get home_path, headers: { "X-Browser-Timezone" => "Pacific/Kiritimati" } }
    get home_path, headers: { "X-Browser-Timezone" => "Asia/Calcutta" }
    assert_equal "Asia/Kolkata", user.reload.timezone, "too soon; and Asia/Calcutta is the same zone"
    assert_equal [ [ "UTC", "Asia/Kolkata", false ], [ "Asia/Kolkata", "Pacific/Kiritimati", true ] ],
      user.timezone_changes.order(:id).pluck(:from, :to, :refused)

    travel User::TIMEZONE_CHANGE_EVERY
    get home_path, headers: { "X-Browser-Timezone" => "Pacific/Kiritimati" }
    assert_equal "Pacific/Kiritimati", user.reload.timezone
    assert_equal 3, user.timezone_changes.count
  end

  test "admins see the changes" do
    users(:member).change_timezone("Europe/Berlin", source: "browser")
    sign_in_as users(:admin)
    changes = load_deferred(admin_user_path(users(:member)), "Admin/Users/Show", "timezone_changes")["timezone_changes"]
    assert_equal [ [ "UTC", "Europe/Berlin", false ] ], changes.map { it.values_at("from", "to", "refused") }
  end
end
