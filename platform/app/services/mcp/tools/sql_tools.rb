# frozen_string_literal: true

module Mcp
  module Tools
    # Raw SQL (Mcp::Sql). Reads answer at once; writes wait for an admin to approve a preview in their browser.
    module SqlTools
      def self.tools = Tools.tools_in(self)

      def self.change_json(change, base_url)
        url = Rails.application.routes.url_helpers.admin_sql_change_url(change, host: base_url) if base_url
        { id: change.public_id, status: change.state, approvalUrl: url, table: change.table_name, kind: change.kind,
          rowsAffected: change.rows_affected, error: change.error, expiresAt: Compact.time(change.expires_at) }
      end

      class QuerySql < Mcp::Tool
        description <<~TEXT.squish
          Run one SQL statement against Fallen's Postgres database. SELECT, WITH, TABLE, VALUES, EXPLAIN and SHOW run
          read-only and answer at once, `limit` rows at most (100 by default, 1000 at most). One INSERT, UPDATE or
          DELETE (up to #{Mcp::Sql::MAX_WRITE_ROWS} rows, no RETURNING) is not run: it is previewed and answers with an
          approvalUrl. Give the admin that link; nothing changes until they approve it in their browser, within
          #{McpSqlChange::LIFETIME.in_minutes.to_i} minutes. Then check_sql_change says how it went. Writes skip model
          validations, callbacks and change history, so prefer the purpose-built tools when one fits. Schema changes,
          and writes to the audit, token, job and flag tables, are refused. Every statement has a 5 second timeout.
        TEXT
        arguments({ sql: { type: "string", maxLength: 20_000 }, limit: { type: "integer", minimum: 1, maximum: Mcp::Sql::MAX_READ_LIMIT } },
                  required: %w[sql])
        writes!

        # A read's rows can hold anything; a write's preview is kept on its McpSqlChange.
        def self.logs_result? = false

        def self.run(ctx, sql:, limit: nil)
          ctx.authorize!(McpSqlChange, :create?, policy_class: Admin::SqlChangePolicy)
          ctx.refuse!("SQL is turned off.") if Flipper.enabled?(:disable_mcp_sql)
          return Mcp::Sql.read(sql, limit:) if Mcp::Sql.kind(sql) == "read"

          change = McpSqlChange.request!(sql:, admin: ctx.admin, token: ctx.token)
          ctx.subject!(change)
          sample = change.preview.slice("kind", "table", "count", "columns").merge("rows" => change.preview["rows"].first(5))
          { **SqlTools.change_json(change, ctx.base_url), preview: sample,
            next: "Nothing has changed yet. Ask the admin to open approvalUrl, check the preview and approve it." }
        end
      end

      class CheckSqlChange < Mcp::Tool
        description "Whether a write from query_sql is still waiting, was approved and run (done, with rowsAffected), " \
                    "was rejected, expired, or failed because its rows changed after the preview."
        arguments({ id: { type: "string", description: "The id query_sql answered, sql_…" } }, required: %w[id])
        reads!

        def self.run(ctx, id:)
          change = ctx.authorize!(McpSqlChange.find_by_public_id!(id), :show?, policy_class: Admin::SqlChangePolicy)
          ctx.subject!(change)
          SqlTools.change_json(change, ctx.base_url)
        end
      end
    end
  end
end
