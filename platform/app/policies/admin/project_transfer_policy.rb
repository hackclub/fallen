# frozen_string_literal: true

# /admin/transfers. Reviewers and admins read every transfer and decide pending ones; only admins pull the form.
class Admin::ProjectTransferPolicy < ApplicationPolicy
  def index? = transfer_reviewer?
  def show? = transfer_reviewer?
  def approve? = transfer_reviewer? && record.pending? && !record.discarded?
  def reject? = approve?
  def refetch? = approve? && record.fetchable?
  def reach_out? = transfer_reviewer? && !record.discarded?
  def undo_reach_out? = reach_out?
  def sync? = admin?
  def lapse? = transfer_reviewer?
  def review_lapse? = approve?

  class Scope < ApplicationPolicy::Scope
    def resolve = user&.reviews_transfers? ? scope.all : scope.none
  end

  private

  def transfer_reviewer? = user&.reviews_transfers? || false
end
