require "test_helper"

class TimezoneTest < ActionDispatch::IntegrationTest
  test "browser timezone header updates the user" do
    sign_in_as users(:member)
    get home_path, headers: { "X-Browser-Timezone" => "Europe/Berlin" }
    assert_equal "Europe/Berlin", users(:member).reload.timezone

    get home_path, headers: { "X-Browser-Timezone" => "Not/AZone" }
    assert_equal "Europe/Berlin", users(:member).reload.timezone
  end
end
