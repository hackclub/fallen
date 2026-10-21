# frozen_string_literal: true

# Journals are mirrored into Slack as the person, so they need Slack connected or skipped (User#slack_ready?). A
# project does not: onboarding makes one before that, and its thread is posted once it is (PostProjectToSlackJob).
# Everyone on the team edits the project and invites people; only the owner takes people off or deletes it, and only
# once nobody else is on it, since deleting takes its journals' XP back.
class ProjectPolicy < ApplicationPolicy
  def index? = user.present?
  def show? = involved? || staff?
  def create? = user.present?
  def update? = teammate?
  def destroy? = owner? && record.solo?
  def invite? = teammate?
  def remove_teammate? = owner?
  # The owner can leave once there is someone to hand the project to.
  def leave? = teammate? && !(owner? && record.solo?)
  def join? = user.present? && !teammate? && !record.team_full?
  # The join link's page: holding the link is the permission, so it shows even before signing in.
  def show_invitation? = true

  class Scope < ApplicationPolicy::Scope
    def resolve = scope.kept.involving(user)
  end

  private

  def teammate? = record.on_team?(user)
  def involved? = teammate? || record.journals.kept.exists?(user: user)
end
