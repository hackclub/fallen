# frozen_string_literal: true

module Mcp
  # The base class of every tool (docs/mcp.md). A subclass declares a description, an input schema, whether it reads
  # or writes (which also sets the hints a client shows before running it) and a `run` that does the work. Calls go
  # through Mcp::Invoke, which logs them, so a tool never audits itself.
  #
  #   class SetProjectApproved < Mcp::Tool
  #     description "Approve a finished project, or take the approval back."
  #     arguments({ id: { type: "string" }, approved: { type: "boolean" } }, required: %w[id approved])
  #     writes!
  #
  #     def self.run(ctx, id:, approved:)
  #       project = ctx.authorize!([ :admin, Project.find_by_public_id!(id) ], :update?)
  #       ...
  #     end
  #   end
  class Tool < MCP::Tool
    class << self
      attr_reader :kind_value

      def inherited(subclass)
        super
        subclass.instance_variable_set(:@kind_value, nil)
      end

      # An object schema that refuses arguments it doesn't name, so nothing reaches `run` that the tool didn't ask for.
      def arguments(properties = {}, required: [])
        input_schema(type: "object", properties:, required:, additionalProperties: false)
      end

      def reads!
        @kind_value = :read
        annotations(read_only_hint: true, destructive_hint: false, idempotent_hint: true, open_world_hint: false)
      end

      def writes!(destructive: false, idempotent: false)
        @kind_value = :write
        annotations(read_only_hint: false, destructive_hint: destructive, idempotent_hint: idempotent, open_world_hint: false)
      end

      def write? = kind_value == :write

      # Whether the log keeps what a write answered (Mcp::Scrub). A tool whose answer can be arbitrary rows says no.
      def logs_result? = write?

      # The gem calls this with the request's arguments; the work is in `run`, reached through Mcp::Invoke.
      def call(server_context:, **args)
        Mcp::Invoke.call(self, args, server_context)
      end

      def run(_ctx, **)
        raise NotImplementedError, "#{name} must define self.run(ctx, **args)"
      end
    end
  end
end
