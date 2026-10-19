# frozen_string_literal: true

class JournalPolicy < ApplicationPolicy
  def create? = record.project.user == user && user.slack_ready?
  def update? = owner?
  def destroy? = owner?

  class Scope < ApplicationPolicy::Scope
    def resolve = scope.kept.where(user: user)
  end
end
