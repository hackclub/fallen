# frozen_string_literal: true

# /admin/jobs: Solid Queue's jobs, queues, workers and recurring tasks. Admins read and act on all of them.
class Admin::JobPolicy < ApplicationPolicy
  def index? = admin?
  def show? = admin?
  def update? = admin?
  def destroy? = admin?

  class Scope < ApplicationPolicy::Scope
    def resolve = user&.admin? ? scope.all : scope.none
  end
end
