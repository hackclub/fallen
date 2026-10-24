# frozen_string_literal: true

# /admin/mcp: MCP tokens and the log of calls made with them. Every admin sees every token and call, and may revoke
# any token, since a leaked one is everyone's problem. Minting is always for oneself, which the controller enforces.
class Admin::McpPolicy < ApplicationPolicy
  def index? = admin?
  def show? = admin?
  def create? = admin? && !user.is_banned?
  def destroy? = admin?

  class Scope < ApplicationPolicy::Scope
    def resolve = user&.admin? ? scope.all : scope.none
  end
end
