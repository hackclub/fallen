require "test_helper"

class SyncProjectTransfersJobTest < ActiveJob::TestCase
  test "pulls the form's rows and fetches the projects not read yet" do
    project_transfers(:stardance).update!(fetched_at: nil)
    stub_method(ProjectTransfer, :sync, 2) do
      with_env("AIRTABLE_API_KEY" => "pat", "AIRTABLE_BASE_ID" => "appTEST") do
        assert_enqueued_with(job: FetchProjectTransferJob, args: [ project_transfers(:stardance) ]) { SyncProjectTransfersJob.perform_now }
      end
    end
    assert_enqueued_jobs 1, only: FetchProjectTransferJob
  end

  test "does nothing until Airtable is configured" do
    with_env("AIRTABLE_API_KEY" => nil) do
      assert_no_enqueued_jobs { SyncProjectTransfersJob.perform_now }
    end
  end

  test "fetching stores what the program shows" do
    transfer = project_transfers(:stardance)
    entry = { "ref" => "1", "minutes" => 60, "body" => "Wired it.\n\n![](https://fabricate.hackclub-assets.com/a.png)\n\nDone.", "images" => [ "https://x.example/b.png" ] }
    stub_method(Stardance, :project, { "title" => "New title", "entries" => [ entry ] }) { FetchProjectTransferJob.perform_now(transfer) }

    snapshot = transfer.reload.snapshot
    assert_equal "New title", snapshot["title"]
    assert_equal "Wired it.\n\nDone.", snapshot.dig("entries", 0, "body"), "photos come out of the writing"
    assert_equal %w[https://x.example/b.png https://fabricate.hackclub-assets.com/a.png], snapshot.dig("entries", 0, "images")
    assert_nil transfer.error
  end
end
