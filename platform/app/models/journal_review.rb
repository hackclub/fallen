# The reviewer's call on one journal in a Submission: how much of its logged time counts, and why when it isn't all
# of it. Deciding the submission copies `approved_minutes` onto the journal (Journal#reviewed_minutes), and its XP
# follows. A journal looked at again in a later submission starts from the last call made on it.
# == Schema Information
#
# Table name: journal_reviews
#
#  id               :bigint           not null, primary key
#  approved_minutes :integer          not null
#  note             :text
#  reason           :string
#  created_at       :datetime         not null
#  updated_at       :datetime         not null
#  journal_id       :bigint           not null
#  reviewer_id      :bigint
#  submission_id    :bigint           not null
#
# Indexes
#
#  index_journal_reviews_on_journal_id                    (journal_id)
#  index_journal_reviews_on_reviewer_id                   (reviewer_id)
#  index_journal_reviews_on_submission_id                 (submission_id)
#  index_journal_reviews_on_submission_id_and_journal_id  (submission_id,journal_id) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (journal_id => journals.id)
#  fk_rails_...  (reviewer_id => users.id)
#  fk_rails_...  (submission_id => submissions.id)
#
class JournalReview < ApplicationRecord
  has_paper_trail

  # Recorded on every journal of a project rejected for AI-generated journals (SubmissionReview), never picked by hand.
  AI_GENERATED = "AI-generated"
  REASONS = [ "Idle or AFK time", "Not work on this project", "Tutorials or research only", "More time than the journal shows",
    "Padded or repeated", "Other" ].freeze

  belongs_to :submission
  belongs_to :journal
  belongs_to :reviewer, class_name: "User", optional: true

  validates :approved_minutes, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :reason, inclusion: { in: [ *REASONS, AI_GENERATED ] }, allow_nil: true
  validates :note, length: { maximum: 1_000 }
  validate :reason_when_deflated

  def deflated? = approved_minutes < journal.duration_minutes.to_i

  private

  def reason_when_deflated
    errors.add(:reason, "is needed when time is taken off") if deflated? && reason.blank?
    errors.add(:approved_minutes, "can't be more than was logged") if approved_minutes > journal.duration_minutes.to_i
  end
end
