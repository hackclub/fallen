# frozen_string_literal: true

# A design reviewer's decision held for an admin (/admin/sign-offs): what they decided and every call, next to what the
# person asked for. `params[:journals]` is the journals the review covers, by submission id.
class AdminSignOffSerializer < ApplicationSerializer
  typelize_from Submission
  typelize id: :string, project_title: :string, verdict: "'approved' | 'returned' | 'rejected'", feedback: [ :string, nullable: true ],
    internal_reason: [ :string, nullable: true ], proposed_at: :string, rubric: "Record<string, string>", ai: :boolean, logged_minutes: :number, counted_minutes: :number,
    journals: "{ id: string; created_at: string; excerpt: string; logged_minutes: number; counted_minutes: number; reason: string | null; note: string | null }[]"

  attributes :requested_cents, :created_at
  # Microseconds, not JSON's milliseconds: it comes back on sign-off to name the exact proposal the admin read.
  attribute(:proposed_at) { |submission| submission.proposed_at&.iso8601(6) }
  attribute(:id) { |submission| submission.public_id }
  attribute(:project_title) { |submission| submission.project.title }
  attribute(:verdict) { |submission| submission.proposed_review["verdict"] }
  attribute(:feedback) { |submission| submission.proposed_review["feedback"] }
  attribute(:internal_reason) { |submission| submission.proposed_review["internal_reason"] }
  attribute(:rubric) { |submission| submission.proposed_review["rubric"] || {} }
  attribute(:ai) { |submission| submission.proposed_review["ai"] == true }
  attribute(:journals) { |submission| calls(submission) }
  attribute(:logged_minutes) { |submission| calls(submission).sum { it[:logged_minutes] } }
  attribute(:counted_minutes) { |submission| calls(submission).sum { it[:counted_minutes] } }
  one :user, key: :submitter, resource: PersonSerializer
  one :proposed_by, resource: PersonSerializer

  # Each journal with the time the reviewer let count (all of it for AI-generated journals' "none").
  def calls(submission)
    given = submission.proposed_review["journals"] || {}
    ai = submission.proposed_review["ai"] == true
    (params[:journals]&.[](submission.id) || []).map do |journal|
      call = given[journal.public_id] || {}
      counted = ai ? 0 : Integer(call["approved_minutes"].to_s, exception: false) || journal.duration_minutes
      {
        id: journal.public_id, created_at: journal.created_at, excerpt: journal.body.to_s.squish.truncate(140),
        logged_minutes: journal.duration_minutes, counted_minutes: counted,
        reason: counted < journal.duration_minutes ? (ai ? JournalReview::AI_GENERATED : call["reason"]) : nil, note: call["note"].presence
      }
    end
  end
end
