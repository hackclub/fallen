# frozen_string_literal: true

module Mcp
  # What a tool's `run` gets: the admin the token belongs to, the token, and `authorize!`/`scope`, which run the
  # same Pundit policies the admin controller does. The token check in McpController is the first gate; the policy is
  # the second, so a tool can never do more than the page for the same action lets the admin do.
  class Context
    attr_reader :admin, :token
    attr_accessor :subject

    def initialize(server_context)
      @admin = server_context.fetch(:admin)
      @token = server_context.fetch(:token)
    end

    def authorize!(record, query, policy_class: nil) = Pundit.authorize(admin, record, query, policy_class:)

    def scope(relation, policy_scope_class: nil)
      return Pundit.policy_scope!(admin, relation) unless policy_scope_class

      policy_scope_class.new(admin, relation).resolve
    end

    # The record the call is about, for the action log.
    def subject!(record)
      @subject = record
    end

    def refuse!(message) = raise(Mcp::Refused, message)
  end
end
