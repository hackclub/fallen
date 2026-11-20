# frozen_string_literal: true

# A submission on the review page and in the queue, with what reviewers wrote for each other. Reviewers only.
class ReviewSubmissionSerializer < SubmissionSerializer
  typelize rubric: "Record<string, 'yes' | 'partly' | 'no'>", reviewer: "{ id: string; name: string; avatar: string } | null",
           claimed_by: "{ id: string; name: string; avatar: string } | null", project_title: :string, project_id: :string,
           submitter: "{ id: string; name: string; avatar: string }", waiting_since: :string
  attributes :rubric, :internal_reason, :claim_expires_at, :flagged_at, :flag_reason, :ai_generated, :internal_deflated_minutes
  one :reviewer, resource: PersonSerializer
  one :claimed_by, resource: PersonSerializer
  one :user, key: :submitter, resource: PersonSerializer
  attribute(:project_id) { |submission| submission.project.public_id }
  attribute(:project_title) { |submission| submission.project.title }
  attribute(:waiting_since, &:created_at)
end
