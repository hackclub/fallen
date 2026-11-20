# frozen_string_literal: true

# /review: design reviewers and admins work the queue. Nobody reviews a project they're on; only admins reject (except
# for AI-generated journals, which any design reviewer can, Review::SubmissionsController#update) or clear a fraud flag.
class Review::SubmissionPolicy < ApplicationPolicy
  def index? = reviewer?
  def show? = reviewer?
  def next? = reviewer?
  def decide? = reviewer? && record.pending? && record.flagged_at.nil? && !record.project.on_team?(user)
  def claim? = decide?
  def reject? = decide? && admin?
  def flag? = reviewer? && record.pending? && record.flagged_at.nil?
  def unflag? = admin? && record.flagged_at.present?
  def note? = reviewer?

  class Scope < ApplicationPolicy::Scope
    def resolve = user&.reviews_designs? ? scope.all : scope.none
  end

  private

  def reviewer? = user&.reviews_designs? || false
end
