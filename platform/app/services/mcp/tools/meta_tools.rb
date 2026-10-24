# frozen_string_literal: true

module Mcp
  module Tools
    # The MCP's own log (McpAction). Tokens are never minted or revoked here: that is a person's act on /admin/mcp.
    module MetaTools
      def self.tools = Tools.tools_in(self)

      class ListMcpActions < Mcp::Tool
        description "Recent MCP calls by every admin, newest first, 25 to a page. Rows leave out arguments and results."
        arguments({ mine: { type: "boolean" }, writes_only: { type: "boolean" }, **Compact.page_arguments })
        reads!

        def self.run(ctx, mine: false, writes_only: false, page: nil, per: nil)
          ctx.authorize!(McpAction, :index?, policy_class: Admin::McpPolicy)
          scope = ctx.scope(McpAction, policy_scope_class: Admin::McpPolicy::Scope).includes(:user).newest_first
          scope = scope.where(user: ctx.admin) if mine
          scope = scope.where(kind: "write") if writes_only
          Compact.paginate(scope, page:, per:) do |actions|
            actions.map do |action|
              { id: action.id, tool: action.tool, kind: action.kind, status: action.status, by: Compact.person(action.user),
                subject: action.subject_type && "#{action.subject_type}##{action.subject_id}", at: Compact.time(action.created_at) }
            end
          end
        end
      end

      class GetMcpAction < Mcp::Tool
        description "One MCP call: its arguments, its result if it was a write, and the record changes it made."
        arguments({ id: { type: "integer" } }, required: %w[id])
        reads!

        def self.run(ctx, id:)
          action = ctx.authorize!(McpAction.find(id), :show?, policy_class: Admin::McpPolicy)
          {
            id: action.id, tool: action.tool, kind: action.kind, status: action.status, error: action.error, by: Compact.person(action.user),
            arguments: action.arguments, result: action.result, durationMs: action.duration_ms, at: Compact.time(action.created_at),
            changes: action.versions.limit(25).map do |version|
              { event: version.event, item: "#{version.item_type}##{version.item_id}",
                fields: (version.object_changes || {}).transform_values { |pair| Array(pair).map { Compact.clip(it.to_s, 200) } } }
            end
          }
        end
      end
    end
  end
end
