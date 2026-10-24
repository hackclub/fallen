# frozen_string_literal: true

# Writes asked for with the MCP's query_sql (McpSqlChange). Any admin may look at one and approve or reject it from
# their browser session; an MCP token can ask for one but never decide it, since the decision is only reachable
# through /admin/sql_changes, which a token can't sign in to.
class Admin::SqlChangePolicy < ApplicationPolicy
  def index? = admin?
  def show? = admin?
  def create? = admin?
  def update? = admin? && !user.is_banned?

  class Scope < ApplicationPolicy::Scope
    def resolve = user&.admin? ? scope.all : scope.none
  end
end
