require "test_helper"

class CheckWritingJobTest < ActiveJob::TestCase
  setup { @check = WritingCheck.create!(user: users(:member), body: "I wrote this. " * 20, status: "pending") }

  test "keeps Pangram's shares and reports a flagged check" do
    stub_method(Pangram, :submit, "task-1") do
      stub_method(Pangram, :result, { "fraction_ai" => 0.8, "fraction_ai_assisted" => 0.1 }) do
        assert_enqueued_with(job: ReportWritingFlagJob) { CheckWritingJob.perform_now(@check) }
      end
    end
    assert_equal "done", @check.reload.status
    assert_in_delta 0.8, @check.fraction_ai
    assert @check.flagged?
  end

  test "an unflagged check is not reported" do
    stub_method(Pangram, :submit, "task-1") do
      stub_method(Pangram, :result, { "fraction_ai" => 0.0, "fraction_ai_assisted" => 0.4 }) do
        assert_no_enqueued_jobs(only: ReportWritingFlagJob) { CheckWritingJob.perform_now(@check) }
      end
    end
    assert_not @check.reload.flagged?
  end

  test "an error lets the journal through" do
    original = Pangram.method(:submit)
    Pangram.define_singleton_method(:submit) { |_text| raise Pangram::Error, "down" }
    CheckWritingJob.perform_now(@check)
    assert_equal "failed", @check.reload.status
    assert_not @check.flagged?
  ensure
    Pangram.define_singleton_method(:submit, original)
  end
end
