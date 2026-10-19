require "test_helper"

class SyncFalloutInvitesJobTest < ActiveJob::TestCase
  test "copies the codes only once Airtable is configured" do
    stub_method(FalloutInvite, :sync, :called) do
      with_env("AIRTABLE_API_KEY" => nil) { assert_nil SyncFalloutInvitesJob.perform_now }
      with_env("AIRTABLE_API_KEY" => "pat", "AIRTABLE_BASE_ID" => "app1") { assert_equal :called, SyncFalloutInvitesJob.perform_now }
    end
  end
end
