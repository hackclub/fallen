# What Pangram made of a journal's writing before it was posted (CheckWritingJob). The composer runs one when
# "Log journal" is pressed; a flagged one asks the person to rewrite it in their own words, or to hold a button
# saying they did (`insisted`). Nothing is blocked. Checks that never became a journal are kept, so reviewers can
# see what was flagged and what was posted in the end.
# == Schema Information
#
# Table name: writing_checks
#
#  id                   :bigint           not null, primary key
#  body                 :text             not null
#  fraction_ai          :float
#  fraction_ai_assisted :float
#  insisted             :boolean          default(FALSE), not null
#  slack_ts             :string
#  status               :string           default("pending"), not null
#  created_at           :datetime         not null
#  updated_at           :datetime         not null
#  journal_id           :bigint
#  user_id              :bigint           not null
#
# Indexes
#
#  index_writing_checks_on_journal_id  (journal_id)
#  index_writing_checks_on_user_id     (user_id)
#
# Foreign Keys
#
#  fk_rails_...  (journal_id => journals.id)
#  fk_rails_...  (user_id => users.id)
#
class WritingCheck < ApplicationRecord
  include PublicIdentifiable

  STATUSES = %w[pending done failed skipped].freeze
  # Detectors are unreliable on a few sentences, and every word is billed, so shorter writing isn't sent.
  WORDS_NEEDED = 50
  # Share of the writing Pangram calls AI-generated. AI-assisted (grammar tools, translation) doesn't count.
  FLAG_AT = 0.5

  set_public_id_prefix :wck
  has_paper_trail

  belongs_to :user
  belongs_to :journal, optional: true

  validates :status, inclusion: { in: STATUSES }

  def self.enabled_for?(user) = Pangram.configured? && Flipper.enabled?(:writing_check, user)

  # The same writing is only sent once.
  def self.start(user, body, journal: nil)
    unless journal
      existing = where(user:, journal_id: nil, body:).where.not(status: "failed").order(:id).last
      return existing if existing
    end

    check = create!(user:, journal:, body:, status: checkable?(body) ? "pending" : "skipped")
    CheckWritingJob.perform_later(check) if check.pending?
    check
  end

  def self.checkable?(body)
    body.to_s.length <= Journal::MAX_BODY_LENGTH && Journal.written_text(body).split.size >= WORDS_NEEDED
  end

  # Ties the composer's check to the journal it became. A journal posted without a matching one (an old tab, or
  # the check skipped by hand) gets its own, so reviewers see a score either way.
  def self.settle(journal, id, insisted:)
    check = where(user_id: journal.user_id, journal_id: nil, body: journal.body).find_by_public_id(id)
    return start(journal.user, journal.body, journal:) unless check

    check.update!(journal:, insisted: insisted && check.flagged?)
    ReportWritingFlagJob.perform_later(check) if check.flagged?
  end

  def pending? = status == "pending"
  def flagged? = status == "done" && fraction_ai.to_f >= FLAG_AT
end
