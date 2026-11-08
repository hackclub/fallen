require "test_helper"

class WorkshopRsvpsTest < ActionDispatch::IntegrationTest
  setup { travel_to Time.zone.parse("2026-11-04 12:00 EST") }

  test "anyone can sign up without an account, and it makes no user" do
    props = inertia_props(workshop_rsvp_path, "WorkshopRsvps/New")
    assert_equal %w[nov8 nov11], props["slots"].pluck("key")

    assert_no_difference -> { User.count } do
      post workshop_rsvp_path, params: { workshop_rsvp: { email: "guest@example.com", slack_username: "guest", slot: "nov11" } }
    end
    assert_redirected_to workshop_rsvp_path
    assert_equal "nov11", WorkshopRsvp.find_by!(email: "guest@example.com").slot
    assert_equal "nov11", inertia_props(workshop_rsvp_path, "WorkshopRsvps/New")["signed_up"]
  end

  test "a bad email comes back as a form error" do
    post workshop_rsvp_path, params: { workshop_rsvp: { email: "nope", slot: "nov8" } }, headers: { "HTTP_REFERER" => workshop_rsvp_url }
    assert_redirected_to workshop_rsvp_url
    assert_equal 0, WorkshopRsvp.count
  end

  test "admins see the sign-ups and can download a slot's CSV" do
    WorkshopRsvp.sign_up(email: "a@example.com", slot: "nov8")
    WorkshopRsvp.sign_up(email: "b@example.com", slot: "nov11")
    sign_in_as users(:admin)

    props = load_deferred(admin_workshop_rsvps_path, "Admin/WorkshopRsvps/Index", "rsvps", "pagy", "counts")
    assert_equal({ "nov8" => 1, "nov11" => 1 }, props["counts"])
    assert_equal 2, props["rsvps"].size

    get export_admin_workshop_rsvps_path(slot: "nov8")
    assert_equal "text/csv", response.media_type
    assert_includes response.body, "a@example.com"
    assert_not_includes response.body, "b@example.com"
  end

  test "the CSV keeps a typed formula as text" do
    WorkshopRsvp.sign_up(email: "a@example.com", slack_username: "=HYPERLINK(\"https://evil.test\")", slot: "nov8")
    sign_in_as users(:admin)

    get export_admin_workshop_rsvps_path
    assert_equal "'=HYPERLINK(\"https://evil.test\")", CSV.parse(response.body, headers: true).first["slack_username"]
  end

  test "the page closes once every session has started" do
    travel_to WorkshopRsvp::SLOTS["nov11"].first
    assert_empty inertia_props(workshop_rsvp_path, "WorkshopRsvps/New")["slots"]
  end

  test "admins only" do
    sign_in_as users(:member)
    get admin_workshop_rsvps_path
    assert_response :not_found
    get export_admin_workshop_rsvps_path
    assert_response :not_found
  end
end
