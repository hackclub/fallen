# frozen_string_literal: true

# A project's design submission as its team sees it: what was sent and, once decided, the outcome and the feedback.
# What reviewers wrote for each other (internal_reason, notes) is only in the review serializers.
# == Schema Information
#
# Table name: submissions
#
#  id                 :bigint           not null, primary key
#  approved_cents     :integer
#  bom_csv            :text
#  checks             :jsonb            not null
#  claim_expires_at   :datetime
#  commit_sha         :string
#  decided_at         :datetime
#  feedback           :text
#  flag_reason        :text
#  flagged_at         :datetime
#  internal_reason    :text
#  kind               :string           default("design"), not null
#  lock_version       :integer          default(0), not null
#  made_with          :string           default([]), not null, is an Array
#  note               :text
#  repo_url           :string           not null
#  requested_cents    :integer          default(0), not null
#  review_draft       :jsonb
#  review_draft_at    :datetime
#  rubric             :jsonb            not null
#  status             :string           default("pending"), not null
#  created_at         :datetime         not null
#  updated_at         :datetime         not null
#  claimed_by_id      :bigint
#  project_id         :bigint           not null
#  repo_snapshot_id   :bigint
#  review_draft_by_id :bigint
#  reviewer_id        :bigint
#  user_id            :bigint           not null
#
# Indexes
#
#  index_submissions_on_claimed_by_id          (claimed_by_id)
#  index_submissions_on_project_id             (project_id)
#  index_submissions_on_repo_snapshot_id       (repo_snapshot_id)
#  index_submissions_on_review_draft_by_id     (review_draft_by_id)
#  index_submissions_on_reviewer_id            (reviewer_id)
#  index_submissions_on_status_and_created_at  (status,created_at)
#  index_submissions_on_user_id                (user_id)
#  index_submissions_one_pending_per_project   (project_id) UNIQUE WHERE ((status)::text = 'pending'::text)
#
# Foreign Keys
#
#  fk_rails_...  (claimed_by_id => users.id)
#  fk_rails_...  (project_id => projects.id)
#  fk_rails_...  (repo_snapshot_id => repo_snapshots.id)
#  fk_rails_...  (review_draft_by_id => users.id)
#  fk_rails_...  (reviewer_id => users.id)
#  fk_rails_...  (user_id => users.id)
#
class SubmissionSerializer < ApplicationSerializer
  typelize_from Submission
  typelize id: :string, status: "'pending' | 'approved' | 'returned' | 'rejected' | 'withdrawn'",
           checks: "Array<{ key: string; label: string; status: 'pass' | 'warn' | 'fail'; detail: string | null; doc?: string | null }>",
           screenshots: "Array<{ id: string; url: string }>", payout_status: [ :string, nullable: true ]
  attributes :status, :repo_url, :commit_sha, :made_with, :note, :requested_cents, :approved_cents, :feedback, :checks, :created_at, :decided_at
  attribute(:id) { |submission| submission.public_id }
  attribute(:screenshots) do |submission|
    submission.screenshots.map { |image| { id: image.signed_id, url: Rails.application.routes.url_helpers.rails_blob_path(image, only_path: true) } }
  end
  many :bom_items, resource: BomItemSerializer
  attribute(:payout_status) { |submission| submission.grant_payout&.status }
end
