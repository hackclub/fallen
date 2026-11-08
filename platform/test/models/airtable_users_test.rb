require "test_helper"

class AirtableUsersTest < ActiveSupport::TestCase
  test "a row carries the account, its counts and no tokens" do
    member = users(:member)
    member.update!(hca_token: "hca-secret", slack_user_token: "xoxp-secret")
    loaded = AirtableUsers.users.find(member.id)
    row = AirtableUsers.rows([ loaded ]).sole
    journals = member.journals.kept

    assert_equal member.public_id, row["ID"]
    assert_equal member.email, row["Email"]
    assert_equal member.xp, row["XP"]
    assert_equal member.projects.kept.count, row["Projects"]
    assert_equal journals.count, row["Journals"]
    assert_equal (journals.sum(:duration_minutes) / 60.0).round(2), row["Hours"]
    assert_equal member.pet_form, row["Stage"]
    assert row["Slack Connected"]
    assert_empty row.values.grep(/secret/)
    assert_not loaded.has_attribute?(:hca_token)
  end

  test "the stats take one journals query and one projects query, however many users" do
    everyone = AirtableUsers.users.to_a
    rows = assert_queries_count(2) { AirtableUsers.rows(everyone) }.index_by { it["ID"] }
    member = users(:member)
    journals = member.journals.kept

    assert_equal journals.minimum(:created_at).iso8601, rows[member.public_id]["First Journal At"]
    assert_equal journals.maximum(:created_at).iso8601, rows[member.public_id]["Last Journal At"]
    assert_equal member.projects.kept.approved.count, rows[member.public_id]["Approved Projects"]
  end

  test "Slack Connected is false once Slack is disconnected" do
    users(:member).disconnect_slack!

    assert_not AirtableUsers.rows([ AirtableUsers.users.find(users(:member).id) ]).sole["Slack Connected"]
  end

  test "trial accounts are uploaded and marked" do
    trial = User.start_trial!(email: "trial@example.com")
    row = AirtableUsers.rows(AirtableUsers.users.where(id: [ trial.id, users(:member).id ]).to_a).index_by { _1["ID"] }

    assert row[trial.public_id]["Trial"]
    assert_nil row[trial.public_id]["HCA ID"]
    assert_not row[users(:member).public_id]["Trial"]
  end

  test "every row has the same columns" do
    assert_equal 1, AirtableUsers.rows(AirtableUsers.users.to_a).map(&:keys).uniq.size
  end

  test "sync uploads every user to the configured table" do
    uploaded = nil
    original = Airtable.method(:sync)
    Airtable.define_singleton_method(:sync) { |table, sync_id, rows| uploaded = [ table, sync_id, rows ] }

    with_env("AIRTABLE_USERS_TABLE" => nil, "AIRTABLE_USERS_SYNC_ID" => "sync1") do
      stats = []
      count = ->(*, payload) { stats << payload[:sql] if payload[:sql].match?(/FROM "(journals|projects)"/) }
      ActiveSupport::Notifications.subscribed(count, "sql.active_record") do
        assert_equal User.count, AirtableUsers.sync(batch_size: 2)
      end
      assert_equal 2, stats.size, "journal and project stats should be read once, not once per batch"
    end
    assert_equal [ "Users", "sync1" ], uploaded.first(2)
    assert_equal User.all.map(&:public_id).sort, uploaded.last.pluck("ID").sort
  ensure
    Airtable.define_singleton_method(:sync, original)
  end
end
