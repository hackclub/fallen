require "test_helper"

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
class WritingCheckTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  LONG = "I soldered the display to the board and fixed the wiring. " * 6

  test "writing long enough to judge is sent once, however often it is checked" do
    first = nil
    assert_enqueued_with(job: CheckWritingJob) { first = WritingCheck.start(users(:member), LONG) }
    assert first.pending?

    assert_no_enqueued_jobs { assert_equal first, WritingCheck.start(users(:member), LONG) }
  end

  test "a few sentences are not sent" do
    check = nil
    assert_no_enqueued_jobs { check = WritingCheck.start(users(:member), "Worked on it. Wrote down what I did and what I learned along the way.") }
    assert_equal "skipped", check.status
    assert_not check.flagged?
  end

  test "a failed check is tried again" do
    WritingCheck.create!(user: users(:member), body: LONG, status: "failed")
    assert_enqueued_with(job: CheckWritingJob) { WritingCheck.start(users(:member), LONG) }
  end

  test "settling ties the check to the journal, insisting only counts when it was flagged" do
    journal = journals(:web_only)
    journal.update_columns(body: LONG)
    flagged = WritingCheck.create!(user: journal.user, body: LONG, status: "done", fraction_ai: 0.9)

    assert_enqueued_with(job: ReportWritingFlagJob) { WritingCheck.settle(journal, flagged.public_id, insisted: true) }
    assert_equal journal, flagged.reload.journal
    assert flagged.insisted?

    clean = WritingCheck.create!(user: journal.user, body: LONG, status: "done", fraction_ai: 0.1)
    WritingCheck.settle(journal, clean.public_id, insisted: true)
    assert_not clean.reload.insisted?
  end

  test "a journal posted without a matching check gets its own" do
    journal = journals(:web_only)
    journal.update_columns(body: LONG)
    other = WritingCheck.create!(user: journal.user, body: "#{LONG} and more", status: "done", fraction_ai: 0.1)

    assert_enqueued_with(job: CheckWritingJob) { WritingCheck.settle(journal, other.public_id, insisted: true) }
    check = WritingCheck.where(journal:).sole
    assert check.pending?
    assert_not check.insisted?
    assert_nil other.reload.journal
  end

  test "writing that already became a journal borrows its score instead of being sent again" do
    WritingCheck.create!(user: users(:member), body: LONG, status: "done", fraction_ai: 0.9, journal: journals(:web_only))

    check = nil
    assert_no_enqueued_jobs { check = WritingCheck.start(users(:member), LONG) }
    assert check.flagged?
    assert_not check.billed?
    assert_nil check.journal
  end

  test "past the day's word budget, writing is not sent" do
    WritingCheck.create!(user: users(:member), body: "word " * (WritingCheck::WORDS_PER_DAY - 20), status: "done", fraction_ai: 0.0)
    WritingCheck.create!(user: users(:member), body: "word " * 500, status: "done", fraction_ai: 0.0, billed: false)
    WritingCheck.create!(user: users(:member), body: "word " * 500, status: "done", fraction_ai: 0.0, created_at: 2.days.ago)

    check = nil
    assert_no_enqueued_jobs { check = WritingCheck.start(users(:member), LONG) }
    assert_equal "limited", check.status
    assert_not check.flagged?
    assert_enqueued_with(job: CheckWritingJob) { WritingCheck.start(users(:admin), LONG) }
  end
end
