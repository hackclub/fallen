# frozen_string_literal: true

# A row of the review queue (/review).
class ReviewQueueRowSerializer < ApplicationSerializer
  typelize_from Submission
  typelize id: :string, status: "'pending' | 'approved' | 'returned' | 'rejected' | 'withdrawn'", project_title: :string,
           submitter: "{ id: string; name: string; avatar: string }", reviewer: "{ id: string; name: string; avatar: string } | null",
           claimed_by: "{ id: string; name: string; avatar: string } | null", proposed_by: "{ id: string; name: string; avatar: string } | null", flagged: :boolean, resubmission: :boolean
  attributes :status, :requested_cents, :approved_cents, :created_at, :decided_at, :claim_expires_at, :proposed_at
  attribute(:id) { |submission| submission.public_id }
  attribute(:project_title) { |submission| submission.project.title }
  attribute(:flagged) { |submission| submission.flagged_at.present? }
  attribute(:resubmission) { |submission| params[:resubmitted]&.include?(submission.project_id) || false }
  one :user, key: :submitter, resource: PersonSerializer
  one :reviewer, resource: PersonSerializer
  one :claimed_by, resource: PersonSerializer
  one :proposed_by, resource: PersonSerializer
end
