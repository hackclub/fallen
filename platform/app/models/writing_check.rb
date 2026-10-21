# What Pangram made of a journal's writing before it was posted (CheckWritingJob). The composer runs one when
# "Log journal" is pressed; a flagged one asks the person to rewrite it in their own words, or to hold a button
# saying they did (`insisted`). Nothing is blocked. Checks that never became a journal are kept, so reviewers can
# see what was flagged and what was posted in the end.
# == Schema Information
#
# Table name: writing_checks
#
#  id                   :bigint           not null, primary key
#  billed               :boolean          default(TRUE), not null
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

  # `limited`: over the day's budget, so not sent.
  STATUSES = %w[pending done failed skipped limited].freeze
  # Sent to Pangram, so billed (or perhaps billed, for failed ones). A check that borrowed an earlier score isn't.
  SENT = %w[pending done failed].freeze
  # Detectors are unreliable on a few sentences, and every word is billed, so shorter writing isn't sent.
  WORDS_NEEDED = 50
  # Share of the writing Pangram calls AI-generated. AI-assisted (grammar tools, translation) doesn't count.
  FLAG_AT = 0.5
  # The most one person can send in a day, about $2.50, so checking over and over can't run up the bill. A long
  # journal rewritten ten times is about 4,000.
  WORDS_PER_DAY = 5_000
  # Words in the body as Pangram bills them, for sums in SQL.
  WORDS_SQL = "COALESCE(array_length(regexp_split_to_array(btrim(body), '\\s+'), 1), 0)"

  set_public_id_prefix :wck
  has_paper_trail

  belongs_to :user
  belongs_to :journal, optional: true

  validates :status, inclusion: { in: STATUSES }

  def self.enabled_for?(user) = Pangram.configured? && Flipper.enabled?(:writing_check, user)

  # The same writing is only sent once: a check not yet on a journal is reused, and one that is lends its score.
  def self.start(user, body, journal: nil)
    earlier = where(user:, body:).where.not(status: %w[failed limited]).order(:id).last
    return earlier if earlier && earlier.journal_id.nil? && journal.nil?
    if earlier&.status == "done"
      return create!(user:, journal:, body:, status: "done", billed: false,
        fraction_ai: earlier.fraction_ai, fraction_ai_assisted: earlier.fraction_ai_assisted)
    end

    status = if !checkable?(body) then "skipped"
    elsif words_sent_today(user) + body.split.size > WORDS_PER_DAY then "limited"
    else "pending"
    end
    check = create!(user:, journal:, body:, status:)
    CheckWritingJob.perform_later(check) if check.pending?
    check
  end

  def self.words_sent_today(user) = where(user:, status: SENT, billed: true, created_at: 1.day.ago..).sum(Arel.sql(WORDS_SQL))

  def self.checkable?(body)
    body.to_s.length <= Journal::MAX_BODY_LENGTH && Journal.written_text(body).split.size >= WORDS_NEEDED
  end

  # Ties the composer's check to the journal it became. A journal posted without a matching one (an old tab, or
  # the check skipped by hand) gets its own, so reviewers see a score either way.
  def self.settle(journal, id, insisted:)
    check = where(user_id: journal.user_id, journal_id: nil, body: journal.body).find_by_public_id(id)
    check ||= start(journal.user, journal.body, journal:)
    check.update!(journal:, insisted: insisted && check.flagged?)
    ReportWritingFlagJob.perform_later(check) if check.flagged?
  end

  def pending? = status == "pending"
  def flagged? = status == "done" && fraction_ai.to_f >= FLAG_AT
end
