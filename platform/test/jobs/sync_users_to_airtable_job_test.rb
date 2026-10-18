require "test_helper"

class SyncUsersToAirtableJobTest < ActiveJob::TestCase
  test "does nothing until Airtable and the sync are configured" do
    stub_method(AirtableUsers, :sync, :called) do
      with_env("AIRTABLE_API_KEY" => nil) { assert_nil SyncUsersToAirtableJob.perform_now }
      with_env("AIRTABLE_API_KEY" => "pat", "AIRTABLE_BASE_ID" => "app1", "AIRTABLE_USERS_SYNC_ID" => nil) { assert_nil SyncUsersToAirtableJob.perform_now }
    end
  end

  test "uploads the users when configured" do
    with_env("AIRTABLE_API_KEY" => "pat", "AIRTABLE_BASE_ID" => "app1", "AIRTABLE_USERS_SYNC_ID" => "sync1") do
      stub_method(AirtableUsers, :sync, :called) { assert_equal :called, SyncUsersToAirtableJob.perform_now }
    end
  end
end
