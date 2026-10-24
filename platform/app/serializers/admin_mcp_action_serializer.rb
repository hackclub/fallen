# frozen_string_literal: true

# Admin-only. A call in the log on /admin/mcp. The result is left out; get_mcp_action has it.
class AdminMcpActionSerializer < ApplicationSerializer
  typelize_from McpAction
  typelize arguments: "Record<string, unknown>", subject: [ :string, nullable: true ]

  attributes :id, :tool, :kind, :status, :error, :arguments, :duration_ms, :created_at
  attribute(:subject) { |action| action.subject_type && "#{action.subject_type}##{action.subject_id}" }
  one :user, key: :admin, resource: PersonSerializer
end
