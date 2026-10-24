require "test_helper"

class AdminMcpTest < ActionDispatch::IntegrationTest
  test "members get a 404" do
    sign_in_as users(:member)
    get admin_mcp_path
    assert_response :not_found
    post admin_mcp_tokens_path, params: { name: "member@laptop" }, as: :json
    assert_response :not_found
  end

  test "a token is shown once, stored only as its digest, and works at /mcp" do
    sign_in_as users(:admin)
    post admin_mcp_tokens_path, params: { name: "admin@laptop", lifetime_days: 7 }, as: :json
    assert_response :created
    secret = response.parsed_body["secret"]
    token = AdminToken.sole
    assert_equal [ AdminToken.digest(secret), secret.last(4) ], [ token.token_digest, token.token_hint ]
    assert_in_delta 7.days.from_now, token.expires_at, 1.minute
    assert_equal users(:admin), token.user

    props = inertia_props(admin_mcp_path, "Admin/Mcp/Index")
    assert_not_includes props.to_json, secret
    assert_equal [ "admin@laptop" ], props["tokens"].map { it["name"] }
    assert_equal "admin", props["default_handle"]

    post mcp_path, params: { jsonrpc: "2.0", id: 1, method: "tools/list" }.to_json,
      headers: { "Content-Type" => "application/json", "Accept" => "application/json, text/event-stream", "Authorization" => "Bearer #{secret}" }
    assert_response :success
  end

  test "tokens last at most 90 days and an admin holds five at most" do
    sign_in_as users(:admin)
    post admin_mcp_tokens_path, params: { name: "admin@forever", lifetime_days: 365 }, as: :json
    assert_response :unprocessable_content

    5.times { |i| AdminToken.mint(user: users(:admin), name: "admin@token-#{i}") }
    post admin_mcp_tokens_path, params: { name: "admin@sixth" }, as: :json
    assert_response :unprocessable_content
    assert_match "5 MCP tokens at most", response.parsed_body["error"]
  end

  test "any admin can revoke any token" do
    token = AdminToken.mint(user: users(:admin), name: "admin@leaked")
    other = User.create!(email: "other@example.com", display_name: "Other Admin", roles: %w[admin user], hca_id: "hca_other")
    sign_in_as other
    delete admin_mcp_token_path(token)
    assert_redirected_to admin_mcp_path
    assert token.reload.revoked_at
    assert_nil AdminToken.authenticate(token.token)
  end

  test "a token is named name@device" do
    sign_in_as users(:admin)
    [ "Laptop", "admin@", "@laptop", "Admin@Laptop", "admin@my laptop", "a@b@c" ].each do |name|
      post admin_mcp_tokens_path, params: { name: }, as: :json
      assert_response :unprocessable_content, name
    end
    post admin_mcp_tokens_path, params: { name: "anson.c@mac-mini_2" }, as: :json
    assert_response :created
    assert_equal "jordan", AdminToken.default_handle(User.new(display_name: "Jordan Park"))
  end

  test "only admins can hold a token" do
    assert_raises(ActiveRecord::RecordInvalid) { AdminToken.mint(user: users(:member), name: "member@nope") }
  end
end
