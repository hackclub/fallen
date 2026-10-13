# frozen_string_literal: true

# Projects and journals are mirrored into Slack as the person, so neither can be made on the web until they
# have connected Slack (User#slack_connected?). Reading is fine without.
class ProjectPolicy < ApplicationPolicy
  def index? = user.present?
  def show? = owner? || staff?
  def create? = user.present? && user.slack_connected?
  def update? = owner?
  def destroy? = owner?

  class Scope < ApplicationPolicy::Scope
    def resolve = scope.kept.where(user: user)
  end
end
