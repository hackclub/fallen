require "test_helper"

class AdminTransfersTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper

  setup { sign_in_as users(:admin) }

  test "pending transfers arrive in the deferred table, oldest first, with counts by status" do
    project_transfers(:stranger).update!(status: "rejected")
    props = load_deferred(admin_transfers_path, "Admin/Transfers/Index", "transfers", "pagy", "counts")

    assert_equal [ project_transfers(:stardance).public_id ], props["transfers"].pluck("id")
    assert_equal({ "pending" => 1, "rejected" => 1 }, props["counts"])
    assert_equal [ "matches", 180 ], props["transfers"].first.values_at("owner_check", "snapshot_minutes")

    rows = load_deferred(admin_transfers_path(status: "all"), "Admin/Transfers/Index", "transfers")["transfers"]
    assert_equal 2, rows.size
    assert_nil rows.find { it["email"] == "stranger@example.com" }["user"]
  end

  test "a transfer's page has the snapshot and suggests hours and XP" do
    props = inertia_props(admin_transfer_path(project_transfers(:stardance)), "Admin/Transfers/Show")
    assert_equal [ 180, XpEntry.journal_xp(180, 1) ], props["transfer"].values_at("suggested_minutes", "suggested_xp")
    assert_equal "Designed the legs.", props["transfer"].dig("snapshot", "entries", 0, "body")
    assert_equal [ projects(:station).public_id, projects(:unlinked).public_id ].sort, props["transfer"]["user_projects"].pluck("id").sort
    assert props["can"]["approve"]
  end

  test "approving imports the journals and issues the XP the reviewer typed" do
    transfer = project_transfers(:stardance)
    post approve_admin_transfer_path(transfer), params: { transfer: { hours: "2.5", xp: "25", project_id: projects(:station).public_id, note: "Looks right" } }

    assert_redirected_to admin_transfer_path(transfer)
    transfer.reload
    assert_equal [ "approved", 150, 25, projects(:station), users(:admin) ], transfer.values_at(:status, :approved_minutes, :xp, :project, :reviewer)
    assert_equal 150, projects(:station).journals.where(source: "transfer").sum(:duration_minutes)
  end

  test "approving with bad hours says why and imports nothing" do
    transfer = project_transfers(:stardance)
    post approve_admin_transfer_path(transfer), params: { transfer: { hours: "lots", xp: "25", project_id: "", note: "" } }

    assert_response :redirect
    assert transfer.reload.pending?
    assert_not Journal.exists?(source: "transfer")
  end

  test "rejecting keeps the note, and a decided transfer can't be decided again" do
    transfer = project_transfers(:stardance)
    post reject_admin_transfer_path(transfer), params: { transfer: { note: "Not their project" } }
    assert_redirected_to admin_transfers_path
    assert_equal [ "rejected", "Not their project" ], transfer.reload.values_at(:status, :note)

    post approve_admin_transfer_path(transfer), params: { transfer: { hours: "1", xp: "8" } }
    assert_equal "You are not allowed to do that.", flash[:alert]
    assert_not Journal.exists?(source: "transfer")
  end

  test "pulling from Airtable and fetching again are jobs" do
    assert_enqueued_with(job: SyncProjectTransfersJob) { post sync_admin_transfers_path }
    assert_enqueued_with(job: FetchProjectTransferJob, args: [ project_transfers(:stardance) ]) { post refetch_admin_transfer_path(project_transfers(:stardance)) }
  end

  test "members can't see transfers" do
    sign_in_as users(:member)
    get admin_transfers_path
    assert_response :not_found
  end
end
