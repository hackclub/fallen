require "test_helper"

class McpTest < ActionDispatch::IntegrationTest
  setup { @secret = AdminToken.mint(user: users(:admin), name: "admin@laptop").token }

  test "only a live token of a current admin gets in" do
    assert_equal 401, rpc("tools/list", token: nil).status
    assert_equal 401, rpc("tools/list", token: "fallen_admin_#{'x' * 40}").status
    assert_equal 401, rpc("tools/list", token: "Basic #{@secret}").status
    assert_equal 'Bearer realm="fallen-admin"', response.headers["WWW-Authenticate"]
    assert_equal 200, rpc("tools/list").status
    assert_equal "no-store", response.headers["Cache-Control"]

    AdminToken.last.update!(expires_at: 1.minute.ago)
    assert_equal 401, rpc("tools/list").status
  end

  test "a session cookie is not a token" do
    sign_in_as users(:admin)
    assert_equal 401, rpc("tools/list", token: nil).status
  end

  test "losing the admin role, a ban or deleting the account revokes every token" do
    users(:admin).update!(roles: [ "user" ])
    assert_equal 401, rpc("tools/list").status
    assert AdminToken.last.revoked_at

    users(:admin).update!(roles: %w[admin user])
    assert_equal 401, rpc("tools/list").status, "a revoked token stays revoked"
    secret = AdminToken.mint(user: users(:admin), name: "admin@again").token
    users(:admin).update!(is_banned: true)
    assert_equal 401, rpc("tools/list", token: secret).status
  end

  test "the kill switch turns the server off" do
    Flipper.enable(:disable_admin_mcp)
    assert_equal 503, rpc("tools/list").status
  end

  test "only POST" do
    get mcp_path, headers: { "Authorization" => "Bearer #{@secret}" }
    assert_response :method_not_allowed
    post "/mcp.json", headers: { "Authorization" => "Bearer #{@secret}" }
    assert_response :not_found
  end

  test "lists every tool with schemas that refuse unknown arguments" do
    tools = rpc("tools/list").parsed_body.dig("result", "tools")
    assert_equal Mcp::Registry.tools.size, tools.size
    assert tools.all? { it.dig("inputSchema", "additionalProperties") == false }
    assert tools.find { it["name"] == "update_user" }.dig("annotations", "destructiveHint")
  end

  test "a read is logged without its result" do
    body = call_tool("list_users", query: "member")
    assert_equal [ users(:member).public_id ], body.dig("result", "rows").map { it["id"] }

    action = McpAction.find(body["mcp_action_id"])
    assert_equal [ "list_users", "read", "ok", users(:admin) ], [ action.tool, action.kind, action.status, action.user ]
    assert_equal({ "query" => "member" }, action.arguments)
    assert_nil action.result
  end

  test "a write runs the page's policy and stamps its versions with the call" do
    body = call_tool("update_user", id: users(:member).public_id, is_banned: true)
    assert users(:member).reload.is_banned?

    action = McpAction.find(body["mcp_action_id"])
    assert_equal users(:member), action.subject
    version = action.versions.sole
    assert_equal [ users(:admin).id.to_s, "mcp:update_user" ], [ version.whodunnit, version.source ]

    body = call_tool("update_user", id: users(:admin).public_id, roles: [ "user" ])
    assert_equal [ false, "Not allowed." ], body.values_at("ok", "error")
    assert_equal "refused", McpAction.find(body["mcp_action_id"]).status
    assert users(:admin).reload.admin?
  end

  test "unknown arguments are refused before the tool runs" do
    assert_no_difference -> { McpAction.count } do
      response = rpc("tools/call", name: "update_user", arguments: { id: users(:member).public_id, email: "x@example.com" })
      assert response.parsed_body.dig("result", "isError")
    end
    assert_equal "member@example.com", users(:member).reload.email
  end

  test "projects, flags and jobs act as their pages do" do
    project = projects(:station)
    assert call_tool("set_project_approved", id: project.public_id, approved: true)["ok"]
    assert project.reload.approved?
    assert_equal project.title, call_tool("get_project", id: project.public_id).dig("result", "project", "title")

    call_tool("create_flag", key: "beta")
    call_tool("update_flag", key: "beta", actors: [ users(:member).public_id ])
    assert Flipper.enabled?(:beta, users(:member))
    assert_not Flipper.enabled?(:beta, users(:newcomer))

    assert_equal "Not found.", call_tool("get_job", id: 0)["error"]
    assert_equal({ "failed" => 0 }, call_tool("list_jobs", status: "failed").dig("result", "counts").slice("failed"))
  end

  test "an answer too long for a context window is withheld but the call stands" do
    stub_const(Mcp::Invoke, :RESPONSE_LIMIT, 200) do
      body = call_tool("list_users")
      assert_nil body["result"]
      assert body.dig("too_large", "sections").key?("rows")
      assert_match "withheld", McpAction.find(body["mcp_action_id"]).error
    end
  end

  test "query_sql reads at once, keeps no rows in the log, and turns a write into an approval link" do
    body = call_tool("query_sql", sql: "SELECT email FROM users WHERE id = #{users(:member).id}")
    assert_equal [ [ "member@example.com" ] ], body.dig("result", "rows")
    assert_nil McpAction.find(body["mcp_action_id"]).result
    assert_equal "SELECT email FROM users WHERE id = #{users(:member).id}", McpAction.find(body["mcp_action_id"]).arguments["sql"]

    body = call_tool("query_sql", sql: "UPDATE projects SET title = 'Renamed' WHERE id = #{projects(:station).id}")
    change = McpSqlChange.last
    assert_equal [ "pending", "http://www.example.com/admin/sql_changes/#{change.public_id}" ], body["result"].values_at("status", "approvalUrl")
    assert_not_equal "Renamed", projects(:station).reload.title

    change.approve!(users(:admin))
    assert_equal [ "done", 1 ], call_tool("check_sql_change", id: change.public_id)["result"].values_at("status", "rowsAffected")
  end

  test "query_sql has its own kill switch" do
    Flipper.enable(:disable_mcp_sql)
    assert_equal "SQL is turned off.", call_tool("query_sql", sql: "SELECT 1")["error"]
  end

  private

  def rpc(method, token: "Bearer #{@secret}", **params)
    token = "Bearer #{token}" if token && !token.include?(" ")
    post mcp_path, params: { jsonrpc: "2.0", id: 1, method:, params: }.to_json, headers: {
      "Content-Type" => "application/json", "Accept" => "application/json, text/event-stream", "Authorization" => token
    }.compact
    response
  end

  def call_tool(name, **arguments)
    rpc("tools/call", name:, arguments:).parsed_body.dig("result", "structuredContent")
  end

  def stub_const(mod, name, value)
    original = mod.const_get(name)
    mod.send(:remove_const, name)
    mod.const_set(name, value)
    yield
  ensure
    mod.send(:remove_const, name)
    mod.const_set(name, original)
  end
end
