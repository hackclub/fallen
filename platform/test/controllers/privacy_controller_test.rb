require "test_helper"

class PrivacyControllerTest < ActionDispatch::IntegrationTest
  KEY = JWT::JWK.new(OpenSSL::PKey::EC.generate("prime256v1"), kid: "test-key")
  JWKS = { "keys" => [ KEY.export.transform_keys(&:to_s) ] }.freeze

  setup { PrivacyToken.instance_variable_set(:@keys, nil) }

  test "a dry run reports what it would delete and changes nothing" do
    member = users(:member)
    member.update!(display_name: "Renamed")

    assert_no_difference -> { User.count } do
      assert_no_difference -> { PaperTrail::Version.count } do
        call_hub :delete, subject: { emails: [ "member@example.com" ] }
      end
    end

    assert_response :success
    body = response.parsed_body
    assert_equal true, body["found"]
    assert_equal true, body["dry_run"]
    assert_equal({ "users" => 1, "versions" => 1, "projects" => 2, "journals" => 3, "lapse_timelapses" => 2, "xp_entries" => 2 }, body["deleted"])
    assert_equal [], body["retained"]
    assert User.exists?(member.id)
  end

  test "a real run deletes the account and its history and returns the same counts as the dry run" do
    member = users(:member)
    member.update!(display_name: "Renamed")
    xp_entry = member.xp_entries.first
    xp_entry.update!(amount: 13)

    call_hub :delete, subject: { emails: [ "member@example.com" ] }
    dry = response.parsed_body["deleted"]
    call_hub :delete, dry_run: false, subject: { emails: [ "member@example.com" ] }

    assert_response :success
    assert_equal false, response.parsed_body["dry_run"]
    assert_equal dry, response.parsed_body["deleted"]
    assert_not User.exists?(member.id)
    assert_not PaperTrail::Version.exists?(item_type: "User", item_id: member.id)
    assert_not PaperTrail::Version.exists?(item_type: "XpEntry", item_id: xp_entry.id)
  end

  test "deletes projects and journals with the account" do
    member_id = users(:member).id
    call_hub :delete, dry_run: false, subject: { emails: [ "member@example.com" ] }

    assert_equal 2, response.parsed_body["deleted"]["projects"]
    assert_equal 3, response.parsed_body["deleted"]["journals"]
    assert_not Project.exists?(user_id: member_id)
    assert_not PaperTrail::Version.exists?(item_type: "Journal")
  end

  test "takes the person off flags turned on for them by name" do
    Flipper.enable_actor(:beta, users(:member))
    Flipper.enable_actor(:beta, users(:admin))
    call_hub :delete, dry_run: false, subject: { emails: [ "member@example.com" ] }

    assert_equal 1, response.parsed_body["deleted"]["feature_flags"]
    assert_equal [ users(:admin).public_id ], Flipper[:beta].actors_value.to_a
  end

  test "deletes an admin's MCP tokens and calls, and calls about the person" do
    admin = User.create!(email: "staff@example.com", display_name: "Staff", roles: %w[admin user], hca_id: "hca_staff")
    token = AdminToken.mint(user: admin, name: "staff@laptop")
    McpAction.create!(user: admin, admin_token: token, tool: "list_users", kind: "read", status: "ok")
    McpAction.create!(user: users(:admin), admin_token: AdminToken.mint(user: users(:admin), name: "admin@other"), tool: "get_user",
                      kind: "read", status: "ok", subject: users(:member))
    call_hub :delete, dry_run: false, subject: { emails: [ "staff@example.com", "member@example.com" ] }

    assert_equal [ 1, 2 ], response.parsed_body["deleted"].values_at("admin_tokens", "mcp_actions")
    assert_equal 0, McpAction.count
  end

  test "echoes the request id" do
    call_hub :delete, request_id: "req-123", subject: { emails: [ "member@example.com" ] }
    assert_equal "req-123", response.parsed_body["request_id"]
  end

  test "matches emails case-insensitively and by slack or identity id" do
    users(:member).update_column(:email, "Member@Example.com")
    call_hub :delete, dry_run: false, subject: { emails: [ "member@example.com" ], slack_id: users(:admin).slack_id, identity_id: "hca_banned" }

    assert_equal 2, response.parsed_body["deleted"]["users"]
    assert_equal 1, response.parsed_body["retained"].find { |r| r["type"] == "banned users" }["count"]
  end

  test "returns found false when nobody matches" do
    call_hub :delete, subject: { emails: [ "nobody@example.com" ], slack_id: nil, identity_id: nil }

    assert_response :success
    assert_equal false, response.parsed_body["found"]
    assert_equal({}, response.parsed_body["deleted"])
  end

  test "detaches staff history about other accounts instead of deleting it" do
    admin = users(:admin)
    PaperTrail.request(whodunnit: admin.id.to_s) { users(:member).update!(display_name: "Edited by admin") }

    call_hub :delete, dry_run: false, subject: { emails: [ "admin@example.com" ] }

    assert_equal 1, response.parsed_body["retained"].find { |r| r["type"] == "versions" }["count"]
    version = PaperTrail::Version.where(item_type: "User", item_id: users(:member).id).last
    assert_nil version.whodunnit
  end

  test "keeps banned accounts as anonymous placeholders" do
    banned = users(:banned)
    call_hub :delete, dry_run: false, subject: { emails: [ "banned@example.com" ] }

    banned.reload
    assert banned.is_banned?
    assert_equal "hca_banned", banned.hca_id
    assert_equal "Deleted user", banned.display_name
    assert_not_equal "banned@example.com", banned.email
  end

  test "a project others are building goes to a teammate, and only the person's own journals go" do
    project = projects(:station)
    friend = User.create!(hca_id: "hca_friend", email: "friend@example.com", display_name: "Friend", roles: [ "user" ], pet: "sami")
    project.memberships.create!(user: friend)
    theirs = project.journals.create!(user: friend, body: journal_text, duration: "1", images: [ photo ], source: "web")
    solo = projects(:unlinked).id

    call_hub :delete, action: "delete", dry_run: false, subject: { emails: [ "member@example.com" ] }
    assert_response :success
    assert_equal friend, project.reload.user
    assert_empty project.memberships
    assert_equal [ theirs ], project.journals.to_a
    assert_not Project.exists?(solo), "nobody else was on it"
  end

  test "export reports counts and never changes anything" do
    assert_no_difference -> { User.count } do
      call_hub :export, action: "export", dry_run: false, subject: { emails: [ "member@example.com" ] }
    end

    assert_response :success
    assert_equal 1, response.parsed_body["deleted"]["users"]
  end

  test "rejects a replayed token" do
    token = sign(claims(subject: { emails: [ "member@example.com" ] }))
    with_jwks { 2.times { post privacy_delete_path, headers: auth(token) } }

    assert_response :conflict
    assert_equal({ "error" => "replayed" }, response.parsed_body)
  end

  test "rejects a token for the other endpoint" do
    call_hub :export, action: "delete"
    assert_response :bad_request
    assert_equal "action_mismatch", response.parsed_body["error"]
  end

  test "rejects missing and malformed tokens" do
    post privacy_delete_path
    assert_response :unauthorized

    post privacy_delete_path, headers: auth("not-a-jwt")
    assert_response :unauthorized
  end

  test "rejects tokens with the wrong audience, issuer, typ, signer or lifetime" do
    now = Time.now.to_i
    other_key = JWT::JWK.new(OpenSSL::PKey::EC.generate("prime256v1"), kid: "test-key")

    [
      sign(claims(aud: "summer-of-making")),
      sign(claims(iss: "someone-else")),
      sign(claims, typ: "at+jwt"),
      sign(claims(iat: now, exp: now + 301)),
      sign(claims(iat: now - 400, exp: now - 100)),
      JWT.encode(claims, other_key.signing_key, "ES256", { kid: "test-key", typ: "JWT" }),
      JWT.encode(claims, "secret", "HS256", { kid: "test-key", typ: "JWT" })
    ].each do |token|
      with_jwks { post privacy_delete_path, headers: auth(token) }
      assert_response :unauthorized
    end
  end

  test "ignores identifiers in the body and query string" do
    call_hub :delete, dry_run: false, subject: { emails: [ "nobody@example.com" ] }, params: { email: "member@example.com" }

    assert_equal false, response.parsed_body["found"]
    assert User.exists?(users(:member).id)
  end

  test "asks the hub to retry when the JWKS cannot be fetched" do
    stub_method(PrivacyToken, :fetch_jwks, nil) do
      PrivacyToken.define_singleton_method(:fetch_jwks) { raise PrivacyToken::KeysUnavailable }
      post privacy_delete_path, headers: auth(sign(claims))
    end

    assert_response :service_unavailable
  end

  private

  def call_hub(endpoint, params: nil, **overrides)
    with_jwks { post public_send("privacy_#{endpoint}_path", params), headers: auth(sign(claims(action: endpoint.to_s, **overrides))) }
  end

  def claims(**overrides)
    now = Time.now.to_i
    {
      iss: "hackclub-privacy",
      aud: "fallen",
      iat: now,
      exp: now + 300,
      jti: SecureRandom.uuid,
      request_id: SecureRandom.uuid,
      action: "delete",
      dry_run: true,
      subject: { emails: [], slack_id: nil, identity_id: nil }
    }.merge(overrides)
  end

  def sign(payload, typ: "JWT")
    JWT.encode(payload, KEY.signing_key, "ES256", { kid: KEY.kid, typ: typ })
  end

  def auth(token) = { "Authorization" => "Bearer #{token}", "Accept" => "application/json" }

  def with_jwks(&) = stub_method(PrivacyToken, :fetch_jwks, JWKS, &)
end
