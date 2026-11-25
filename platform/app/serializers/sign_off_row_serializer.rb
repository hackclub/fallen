# frozen_string_literal: true

# A held decision as a row in the sign-off desk's queue (Admin::SignOffsController, the private vendor/desk desk).
class SignOffRowSerializer < ApplicationSerializer
  typelize_from Submission
  typelize id: :string, project_title: :string, verdict: "'approved' | 'returned' | 'rejected'", proposed_at: :string,
    copy_check_status: "'pending' | 'match' | 'clear' | 'unscreenable' | 'failed' | null", copy_check_holds: :boolean

  attributes :requested_cents, :created_at
  attribute(:id) { |submission| submission.public_id }
  attribute(:project_title) { |submission| submission.project.title }
  attribute(:verdict) { |submission| submission.proposed_review["verdict"] }
  attribute(:proposed_at) { |submission| submission.proposed_at&.iso8601(6) }
  attribute(:copy_check_status) { |submission| submission.copy_check&.dig("status") }
  attribute(:copy_check_holds) { |submission| submission.copy_check_holds_approval? }
  one :user, key: :submitter, resource: PersonSerializer
  one :proposed_by, resource: PersonSerializer
end
