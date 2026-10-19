require "test_helper"

class SyncFalloutInvitesJobTest < ActiveJob::TestCase
  test "copies the codes only once Fallout's Airtable key is set" do
    stub_method(FalloutInvite, :sync, :called) do
      with_env("FALLOUT_AIRTABLE_API_KEY" => nil) { assert_nil SyncFalloutInvitesJob.perform_now }
      with_env("FALLOUT_AIRTABLE_API_KEY" => "pat") { assert_equal :called, SyncFalloutInvitesJob.perform_now }
    end
  end
end
