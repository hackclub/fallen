# frozen_string_literal: true

# /admin/projects. Admins read every project, including deleted ones, and approve finished ones; editing stays with
# the owner.
class Admin::ProjectPolicy < ApplicationPolicy
  def index? = admin?
  def show? = admin?
  def update? = admin? && !record.discarded?

  class Scope < ApplicationPolicy::Scope
    def resolve = user&.admin? ? scope.all : scope.none
  end
end
