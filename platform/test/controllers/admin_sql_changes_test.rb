require "test_helper"

class AdminSqlChangesTest < ActionDispatch::IntegrationTest
  setup do
    token = AdminToken.mint(user: users(:admin), name: "Laptop")
    @change = McpSqlChange.request!(sql: "UPDATE projects SET title = 'Renamed' WHERE id = #{projects(:station).id}", admin: users(:admin), token:)
  end

  test "members get a 404 and can't decide" do
    sign_in_as users(:member)
    get admin_sql_change_path(@change)
    assert_response :not_found
    patch admin_sql_change_path(@change), params: { decision: "approve" }
    assert_response :not_found
    assert_equal "pending", @change.reload.status
  end

  test "the page shows the preview without its fingerprints" do
    sign_in_as users(:admin)
    change = inertia_props(admin_sql_change_path(@change), "Admin/SqlChanges/Show")["change"]
    assert_equal [ "pending", 1, "projects" ], change.values_at("state", "count", "table_name")
    assert_not change.key?("digests")
    assert_not_includes response.body, @change.preview["digests"].values.first
  end

  test "approving runs it once and records who did" do
    sign_in_as users(:admin)
    patch admin_sql_change_path(@change), params: { decision: "approve" }
    assert_redirected_to admin_sql_change_path(@change)
    assert_equal "Done. 1 row changed.", flash[:notice]
    assert_equal [ "done", users(:admin) ], [ @change.reload.status, @change.reviewer ]
    assert_equal "Renamed", projects(:station).reload.title

    patch admin_sql_change_path(@change), params: { decision: "approve" }
    assert_equal "This change is done, so it can't be decided now.", flash[:alert]
  end

  test "rejecting changes nothing" do
    sign_in_as users(:admin)
    patch admin_sql_change_path(@change), params: { decision: "reject" }
    assert_equal "rejected", @change.reload.status
    assert_not_equal "Renamed", projects(:station).reload.title
  end
end
