# frozen_string_literal: true

# The person invited answers it; anyone on the team can take back one still waiting.
class ProjectInvitePolicy < ApplicationPolicy
  def show? = invitee?
  def accept? = invitee?
  def destroy? = invitee? || record.project.on_team?(user)

  private

  def invitee? = user.present? && record.user_id == user.id
end
