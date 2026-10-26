# frozen_string_literal: true

# /admin/transfers. Admins read every transfer and decide pending ones.
class Admin::ProjectTransferPolicy < ApplicationPolicy
  def index? = admin?
  def show? = admin?
  def approve? = admin? && record.pending? && !record.discarded?
  def reject? = approve?
  def refetch? = approve? && record.fetchable?
  def sync? = admin?

  class Scope < ApplicationPolicy::Scope
    def resolve = user&.admin? ? scope.all : scope.none
  end
end
