# frozen_string_literal: true

class JournalPolicy < ApplicationPolicy
  def create? = record.project.on_team?(user) && user.slack_ready?
  # A transferred journal is a copy of what was written in the other program (ProjectTransfer).
  def update? = owner? && !record.transferred?
  def destroy? = owner?

  class Scope < ApplicationPolicy::Scope
    def resolve = scope.kept.where(user: user)
  end
end
