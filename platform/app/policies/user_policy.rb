# frozen_string_literal: true

class UserPolicy < ApplicationPolicy
  def index? = admin?
  def show? = admin? || record == user
  def update? = admin? && record != user
  def destroy? = admin? && record != user
  def choose_pet? = record == user
  # An admin watching it while impersonating does not count as the person seeing it.
  def watch_hatch? = record == user && !user_impersonating?

  # Admins can browse as regular, active users only; never as other staff or while already impersonating.
  def impersonate?
    admin? && record != user && !record.staff? && !record.is_banned? && !record.discarded? && user_impersonating?.!
  end

  class Scope < ApplicationPolicy::Scope
    def resolve
      user&.admin? ? scope.all : scope.kept.where(id: user&.id)
    end
  end

  private

  def user_impersonating? = Current.true_user.present? && Current.true_user != Current.user
end
