# frozen_string_literal: true

# /admin/sign-offs: only admins see design reviewers' held decisions, and sign them off or send them back. Not on a
# project they're on: signing off their own team's approval would send their own team the money.
class Admin::SubmissionPolicy < ApplicationPolicy
  def index? = admin?
  def update? = admin? && record.awaiting_sign_off? && !record.project.on_team?(user)
  def destroy? = update?

  class Scope < ApplicationPolicy::Scope
    def resolve = user&.admin? ? scope.where.not(project_id: Project.teamed_with(user).select(:id)) : scope.none
  end
end
