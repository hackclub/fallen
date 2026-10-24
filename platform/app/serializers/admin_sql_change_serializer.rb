# frozen_string_literal: true

# Admin-only. A write an MCP agent asked for with query_sql, as a row on /admin/mcp. The list query leaves out the SQL
# and the preview; AdminSqlChangeDetailSerializer has them.
class AdminSqlChangeSerializer < ApplicationSerializer
  typelize_from McpSqlChange
  typelize id: :string, state: "'pending' | 'done' | 'rejected' | 'failed' | 'expired'"

  attributes :kind, :table_name, :rows_affected, :created_at, :expires_at
  attribute(:id, &:public_id)
  attribute(:state, &:state)
  one :user, key: :requested_by, resource: PersonSerializer
end
