# frozen_string_literal: true

# /admin/sign-offs: only admins see design reviewers' held decisions, and sign them off or send them back. Not on a
# project they're on: signing off their own team's approval would send their own team the money.
class Admin::SubmissionPolicy < ApplicationPolicy
  def index? = admin?
  # Not their own decision either (a design reviewer since made an admin): signing off is a second pair of eyes.
  def update? = admin? && record.awaiting_sign_off? && record.proposed_by_id != user.id && !record.project.on_team?(user)
  def destroy? = update?

  class Scope < ApplicationPolicy::Scope
    def resolve = user&.admin? ? scope.where.not(project_id: Project.teamed_with(user).select(:id)) : scope.none
  end
end
