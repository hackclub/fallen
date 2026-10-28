# frozen_string_literal: true

# /admin/streaks and the streak card on /admin/users/:id. Admins change anyone's streak but their own, and nobody's
# who is banned or deleted. Incidents are everyone's.
class Admin::StreakAdjustmentPolicy < ApplicationPolicy
  def index? = admin?
  def create? = admin? && why_not.nil?
  def destroy? = create? && !record.discarded?

  # Why an admin can't change this person's streak, for the page to say.
  def why_not
    person = record.user
    if person.nil? then nil
    elsif person == user then "You can't change your own streak."
    elsif person.is_banned? then "#{person.display_name} is banned."
    elsif person.discarded? then "#{person.display_name}'s account is deleted."
    end
  end

  class Scope < ApplicationPolicy::Scope
    def resolve = user&.admin? ? scope.all : scope.none
  end
end
