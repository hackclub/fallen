require "test_helper"

class WritingChecksTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper

  LONG = "I soldered the display to the board and fixed the wiring. " * 6

  setup do
    sign_in_as users(:member)
    Flipper.enable(:writing_check)
  end

  test "the composer starts a check and polls it" do
    with_env("PANGRAM_API_KEY" => "key") do
      assert_enqueued_with(job: CheckWritingJob) { post writing_checks_path, params: { body: LONG }, as: :json }
      assert_response :success
      assert_equal({ "status" => "pending", "flagged" => false }, response.parsed_body.except("id"))

      check = WritingCheck.find_by_public_id!(response.parsed_body["id"])
      check.update!(status: "done", fraction_ai: 0.9)
      get writing_check_path(check), as: :json
      assert_equal true, response.parsed_body["flagged"]
    end
  end

  test "nobody can poll someone else's check" do
    check = WritingCheck.create!(user: users(:admin), body: LONG, status: "done", fraction_ai: 0.9)
    with_env("PANGRAM_API_KEY" => "key") { get writing_check_path(check), as: :json }
    assert_not response.successful?
    assert_not_includes response.body, "flagged"
  end

  test "nothing is checked with the flag off or no API key" do
    assert_no_difference("WritingCheck.count") { post writing_checks_path, params: { body: LONG }, as: :json }
    Flipper.disable(:writing_check)
    with_env("PANGRAM_API_KEY" => "key") do
      assert_no_difference("WritingCheck.count") { post writing_checks_path, params: { body: LONG }, as: :json }
    end
  end

  test "posting the journal ties the check to it, with the hold" do
    check = WritingCheck.create!(user: users(:member), body: LONG, status: "done", fraction_ai: 0.9)
    with_env("PANGRAM_API_KEY" => "key") do
      post project_journals_path(projects(:station)), params: { journal: { body: LONG, duration: "1h", images: [ photo.signed_id ] }, writing_check: check.public_id, insisted: true }, as: :json
    end
    assert_equal Journal.last, check.reload.journal
    assert check.insisted?
  end
end
