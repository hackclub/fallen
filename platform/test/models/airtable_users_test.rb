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

  test "sync sends the users synced longest ago and marks them" do
    synced = users(:admin)
    synced.update_columns(airtable_synced_at: 1.minute.ago)
    sent = capturing_upsert { assert_equal 2, AirtableUsers.sync(limit: 2) }

    assert_equal 2, sent.size
    assert_not_includes sent.pluck("ID"), synced.public_id
    assert_equal 2, User.where.not(airtable_synced_at: nil).where.not(id: synced.id).count
  end

  test "a change to the user or their XP puts them back at the front" do
    member = users(:member)
    member.update_columns(airtable_synced_at: Time.current)

    member.update!(display_name: "Renamed")
    assert_nil member.reload.airtable_synced_at

    member.update_columns(airtable_synced_at: Time.current)
    User.recount_xp([ member.id ])
    assert_nil member.reload.airtable_synced_at
  end

  test "touching last seen does not resend the user" do
    member = users(:member)
    member.update_columns(airtable_synced_at: Time.current, last_seen_at: 1.hour.ago)
    member.touch_last_seen
    assert_not_nil member.reload.airtable_synced_at
  end

  private

  def capturing_upsert
    sent = []
    original = Airtable.method(:upsert)
    Airtable.define_singleton_method(:upsert) { |_table, rows, merge_on:| sent.concat(rows) }
    yield
    sent
  ensure
    Airtable.define_singleton_method(:upsert, original)
  end
end
