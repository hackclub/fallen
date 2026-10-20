require "test_helper"

class AdminFlagsTest < ActionDispatch::IntegrationTest
  setup { sign_in_as users(:admin) }

  test "the list says who each flag is on for" do
    Flipper.enable(:new_shop)
    Flipper.enable_group(:beta_journal, :staff)
    Flipper.enable_actor(:beta_journal, users(:member))
    Flipper.add(:dormant)

    flags = inertia_props(admin_flags_path, "Admin/Flags/Index")["flags"].index_by { it["key"] }
    assert_equal %w[beta_journal dormant new_shop], flags.keys
    assert_equal [ "on", "on for everyone" ], flags["new_shop"].values_at("state", "summary")
    assert_equal [ "conditional", "on for staff and 1 person" ], flags["beta_journal"].values_at("state", "summary")
    assert_equal [ { "id" => users(:member).public_id, "name" => users(:member).display_name } ],
      flags["beta_journal"]["actors"].map { it.slice("id", "name") }
    assert_equal "off", flags["dormant"]["state"]
  end

  test "creating a flag starts it off, and names must be new and well formed" do
    post admin_flags_path, params: { flag: { key: "new_shop" } }
    assert_redirected_to admin_flag_path("new_shop")
    assert Flipper.exist?(:new_shop)
    assert_not Flipper.enabled?(:new_shop, users(:member))

    post admin_flags_path, params: { flag: { key: "new_shop" } }
    assert_equal [ "is already a flag" ], inertia_props(admin_flags_path, "Admin/Flags/Index")["errors"]["key"]

    post admin_flags_path, params: { flag: { key: "New Shop!" } }
    assert_equal [ "must be lowercase letters, numbers and underscores" ],
      inertia_props(admin_flags_path, "Admin/Flags/Index")["errors"]["key"]
    assert_not Flipper.exist?(:"New Shop!")
  end

  test "groups, people and shares each turn on for exactly who they say" do
    Flipper.add(:beta)
    patch admin_flag_path("beta"), params: { flag: { groups: [ "admins" ], actors: [ users(:member).public_id ] } }
    assert_equal "beta is on for admins and 1 person.", flash[:notice]
    assert Flipper.enabled?(:beta, users(:admin))
    assert Flipper.enabled?(:beta, users(:member))
    assert_not Flipper.enabled?(:beta, users(:newcomer))

    patch admin_flag_path("beta"), params: { flag: { actors: [ "" ], percentage_of_actors: 30 } }
    assert_equal 30, Flipper[:beta].percentage_of_actors_value
    assert_empty Flipper[:beta].actors_value
    assert_equal [ "admins" ], Flipper[:beta].groups_value.to_a
  end

  test "on or off for everyone clears the other rules, as Flipper does" do
    Flipper.enable_group(:beta, :staff)
    patch admin_flag_path("beta"), params: { flag: { everyone: true, groups: [ "admins" ] } }
    assert Flipper.enabled?(:beta, users(:member))
    assert_empty Flipper[:beta].groups_value, "the rest of a change to everyone is ignored"

    patch admin_flag_path("beta"), params: { flag: { everyone: false } }
    assert_equal "beta is off.", flash[:notice]
    assert_not Flipper.enabled?(:beta, users(:admin))
  end

  test "people are only added if they exist" do
    Flipper.add(:beta)
    patch admin_flag_path("beta"), params: { flag: { actors: [ "usr_nope", users(:member).public_id ] } }
    assert_equal [ users(:member).public_id ], Flipper[:beta].actors_value.to_a
  end

  test "the people search is loaded only when asked for" do
    Flipper.add(:beta)
    assert_not inertia_props(admin_flag_path("beta"), "Admin/Flags/Show").key?("user_matches")

    matches = load_deferred(admin_flag_path("beta", user_query: users(:member).display_name), "Admin/Flags/Show", "user_matches")
    assert_includes matches["user_matches"].pluck("id"), users(:member).public_id
  end

  test "deleting a flag removes it" do
    Flipper.enable(:beta)
    delete admin_flag_path("beta")
    assert_redirected_to admin_flags_path
    assert_not Flipper.exist?(:beta)
  end

  test "an unknown flag is a 404" do
    get admin_flag_path("nope")
    assert_response :not_found
  end
end
