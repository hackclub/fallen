require "test_helper"

class AirtableUsersTest < ActiveSupport::TestCase
  test "a row carries the account, its counts and no tokens" do
    member = users(:member)
    member.update!(hca_token: "hca-secret", slack_user_token: "xoxp-secret")
    row = AirtableUsers.rows([ member ]).sole
    journals = member.journals.kept

    assert_equal member.public_id, row["ID"]
    assert_equal member.email, row["Email"]
    assert_equal member.xp, row["XP"]
    assert_equal member.projects.kept.count, row["Projects"]
    assert_equal journals.count, row["Journals"]
    assert_equal (journals.sum(:duration_minutes) / 60.0).round(2), row["Hours"]
    assert_equal member.pet_form, row["Stage"]
    assert_empty row.values.grep(/secret/)
  end

  test "trial accounts are uploaded and marked" do
    trial = User.start_trial!(email: "trial@example.com")
    row = AirtableUsers.rows([ trial, users(:member) ]).index_by { _1["ID"] }

    assert row[trial.public_id]["Trial"]
    assert_nil row[trial.public_id]["HCA ID"]
    assert_not row[users(:member).public_id]["Trial"]
  end

  test "every row has the same columns" do
    assert_equal 1, AirtableUsers.rows(User.all.to_a).map(&:keys).uniq.size
  end

  test "sync uploads every user to the configured table" do
    uploaded = nil
    original = Airtable.method(:sync)
    Airtable.define_singleton_method(:sync) { |table, sync_id, rows| uploaded = [ table, sync_id, rows ] }

    with_env("AIRTABLE_USERS_TABLE" => nil, "AIRTABLE_USERS_SYNC_ID" => "sync1") { assert_equal User.count, AirtableUsers.sync }
    assert_equal [ "Users", "sync1" ], uploaded.first(2)
    assert_equal User.all.map(&:public_id).sort, uploaded.last.pluck("ID").sort
  ensure
    Airtable.define_singleton_method(:sync, original)
  end
end
