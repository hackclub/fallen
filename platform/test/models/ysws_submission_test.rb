require "test_helper"

class YswsSubmissionTest < ActiveSupport::TestCase
  test "the justification YSWS reads is Fallen's part then the staff's, written only where it changed" do
    rows = [
      { "id" => "recA", "fields" => { "Machine Justification" => "Machine A:", "Manual Justification" => "Because.", "Optional - Override Hours Spent Justification" => "Machine A:" } },
      { "id" => "recB", "fields" => { "Machine Justification" => "Machine B:", "Optional - Override Hours Spent Justification" => "Machine B:" } },
      { "id" => "recC", "fields" => { "Optional - Override Hours Spent Justification" => "Typed by staff" } }
    ]
    written = []
    original = Airtable.method(:upsert)
    Airtable.define_singleton_method(:upsert) { |_base, _table, id, fields| written << [ id, fields ] && id }
    with_env("AIRTABLE_API_KEY" => "key", "AIRTABLE_YSWS_BASE_ID" => "app1", "AIRTABLE_YSWS_TABLE" => "tbl1") do
      stub_method(Airtable, :records, rows) { assert_equal 1, YswsSubmission.join_justifications }
    end
    assert_equal [ [ "recA", { "Optional - Override Hours Spent Justification" => "Machine A:\n\nBecause." } ] ], written
  ensure
    Airtable.define_singleton_method(:upsert, original)
  end
end
