require "test_helper"

class McpSqlTest < ActiveSupport::TestCase
  test "reads run read-only, one statement, a page of rows at a time" do
    result = Mcp::Sql.read("SELECT id, email, hca_token FROM users ORDER BY id", limit: 2)
    assert_equal %w[id email hca_token], result[:columns]
    assert_equal 2, result[:rows].size
    assert result[:truncated]
    users(:admin).update!(hca_token: "secret")
    assert_includes Mcp::Sql.read("SELECT hca_token FROM users WHERE id = #{users(:admin).id}")[:rows], [ "[hidden]" ]

    assert_refused(/data-modifying/) { Mcp::Sql.read("WITH d AS (DELETE FROM projects RETURNING id) SELECT * FROM d") }
    assert_refused(/read-only transaction/) { Mcp::Sql.read("SELECT nextval('users_id_seq')") }
    assert_refused(/multiple commands/) { Mcp::Sql.read("SELECT 1; DELETE FROM projects") }
    assert_refused(/That is a write/) { Mcp::Sql.read("DELETE FROM projects") }
    assert Project.exists?
  end

  test "settings, files, locks and schema changes are refused before they reach the database" do
    assert_refused(/set_config/) { Mcp::Sql.read("SELECT set_config('transaction_read_only', 'off', true)") }
    assert_refused(/pg_advisory_lock/) { Mcp::Sql.read("SELECT 1 -- pg_advisory_lock(1)") }
    assert_refused(/pg_read_file/) { Mcp::Sql.read("SELECT pg_read_file('/etc/passwd')") }
    assert_refused(/Schema changes/) { Mcp::Sql.kind("DROP TABLE users") }
    assert_refused(/Schema changes/) { Mcp::Sql.kind("TRUNCATE users") }
  end

  test "a preview shows the rows a write would touch and writes nothing" do
    project = projects(:station)
    preview = Mcp::Sql.preview("UPDATE projects SET title = 'Renamed' WHERE id = #{project.id};")
    assert_equal [ "update", "projects", "id", 1 ], preview.values_at("kind", "table", "key", "count")
    assert_equal %w[id title], preview["shown"], "an update shows its key and what it changes"
    title = preview["shown"].index("title")
    assert_equal [ project.title, "Renamed" ], [ preview["rows"].first["before"][title], preview["rows"].first["after"][title] ]
    assert_equal project.title, project.reload.title
  end

  test "a long value is clipped around where it changes" do
    journal = journals(:first)
    body = "#{'a' * 2_000}tail"
    Journal.where(id: journal.id).update_all(body:)
    preview = Mcp::Sql.preview("UPDATE journals SET body = body || '!' WHERE id = #{journal.id}")
    before, after = preview["rows"].first.values_at("before", "after").map { it[preview["shown"].index("body")] }
    assert_match(/\A… a+tail\z/, before)
    assert_match(/\A… a+tail!\z/, after)
  end

  test "writes to the audit trail, tokens, jobs and flags, and writes with their own RETURNING, are refused" do
    AdminToken.mint(user: users(:admin), name: "Laptop")
    assert_refused(/admin_tokens can't be written/) { Mcp::Sql.preview("UPDATE admin_tokens SET revoked_at = NULL") }
    assert_refused(/RETURNING/) { Mcp::Sql.preview("DELETE FROM projects RETURNING id") }
    assert_refused(/no rows/) { Mcp::Sql.preview("DELETE FROM projects WHERE id = -1") }
  end

  test "an approved change runs once, only on the rows the admin saw" do
    project = projects(:station)
    change = request_change("UPDATE projects SET title = 'Renamed' WHERE id = #{project.id}")
    change.approve!(users(:admin))
    assert_equal [ "done", 1 ], [ change.status, change.rows_affected ]
    assert_equal "Renamed", project.reload.title
    assert_raises(Mcp::Refused) { change.approve!(users(:admin)) }
  end

  test "a row that changed after the preview stops the change" do
    project = projects(:station)
    change = request_change("UPDATE projects SET title = title || '!' WHERE id = #{project.id}")
    project.update!(description: "Edited meanwhile")
    change.approve!(users(:admin))
    assert_equal "failed", change.status
    assert_match "changed", change.error
    assert_not project.reload.title.end_with?("!")
  end

  test "a change that would now touch other rows stops" do
    ProjectInvite.create!(project: projects(:station), user: users(:newcomer), inviter: users(:member))
    change = request_change("DELETE FROM project_invites WHERE project_id = #{projects(:station).id}")
    ProjectInvite.create!(project: projects(:station), user: users(:banned), inviter: users(:member))
    change.approve!(users(:admin))
    assert_equal [ "failed", "It would touch 2 rows now, not 1." ], [ change.status, change.error ]
    assert_equal 2, projects(:station).invites.count
  end

  test "expired, rejected and revoked-token changes never run" do
    change = request_change("UPDATE projects SET title = 'Late' WHERE id = #{projects(:station).id}")
    travel 31.minutes do
      assert_equal "expired", change.state
      assert_raises(Mcp::Refused) { change.approve!(users(:admin)) }
    end

    change = request_change("UPDATE projects SET title = 'Leaked' WHERE id = #{projects(:station).id}")
    change.admin_token.revoke!
    change.approve!(users(:admin))
    assert_equal [ "failed", "The token that asked for this has been revoked or has expired." ], [ change.status, change.error ]
    assert_not_equal "Leaked", projects(:station).reload.title
  end

  private

  def request_change(sql) = McpSqlChange.request!(sql:, admin: users(:admin), token: AdminToken.mint(user: users(:admin), name: "Laptop #{SecureRandom.hex(2)}"))

  def assert_refused(message, &)
    error = assert_raises(Mcp::Refused, &)
    assert_match message, error.message
  end
end
