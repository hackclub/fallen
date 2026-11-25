# frozen_string_literal: true

# /review: design reviewers and admins work the queue. Nobody reviews a project they're on; only admins reject (except
# for AI-generated journals, which any design reviewer can, Review::SubmissionsController#update), take an internal cut
# off the hours reported to YSWS, or clear a fraud flag.
class Review::SubmissionPolicy < ApplicationPolicy
  def index? = reviewer?
  def show? = reviewer?
  def next? = reviewer?
  def decide? = reviewer? && record.pending? && record.flagged_at.nil? && !record.awaiting_sign_off? && !record.project.on_team?(user)
  # An admin signing off a design reviewer's held decision works it on the same page (Admin::SignOffsController#update).
  def sign_off? = admin? && Admin::SubmissionPolicy.new(user, record).update?
  def claim? = decide? || sign_off?
  def next_sign_off? = admin?
  def reject? = decide? && admin?
  def cut? = admin?
  def flag? = reviewer? && record.pending? && record.flagged_at.nil? && !record.awaiting_sign_off?
  def unflag? = admin? && record.flagged_at.present?
  def note? = reviewer?

  class Scope < ApplicationPolicy::Scope
    def resolve = user&.reviews_designs? ? scope.all : scope.none
  end

  private

  def reviewer? = user&.reviews_designs? || false
end
