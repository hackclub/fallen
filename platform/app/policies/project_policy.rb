# frozen_string_literal: true

# Journals are mirrored into Slack as the person, so they need Slack connected (User#slack_connected?). A project
# does not: onboarding makes one before Slack is connected, and its thread is posted once it is (PostProjectToSlackJob).
class ProjectPolicy < ApplicationPolicy
  def index? = user.present?
  def show? = owner? || staff?
  def create? = user.present?
  def update? = owner?
  def destroy? = owner?

  class Scope < ApplicationPolicy::Scope
    def resolve = scope.kept.where(user: user)
  end
end
