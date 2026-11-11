require "test_helper"

class AdminTransfersTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper

  setup { sign_in_as users(:admin) }

  test "pending transfers arrive in the deferred table, oldest first, with counts by status" do
    project_transfers(:stranger).update!(status: "rejected", reviewer: users(:admin))
    props = load_deferred(admin_transfers_path, "Admin/Transfers/Index", "transfers", "pagy", "counts")

    assert_equal [ project_transfers(:stardance).public_id ], props["transfers"].pluck("id")
    assert_equal({ "pending" => 1, "rejected" => 1 }, props["counts"])
    assert_equal [ "matches", 180 ], props["transfers"].first.values_at("owner_check", "snapshot_minutes")

    rows = load_deferred(admin_transfers_path(status: "all"), "Admin/Transfers/Index", "transfers")["transfers"]
    assert_equal 2, rows.size
    assert_nil rows.find { it["email"] == "stranger@example.com" }["user"]
    assert_equal "Admin Person", rows.find { it["email"] == "stranger@example.com" }.dig("reviewer", "name")
    assert_nil rows.find { it["status"] == "pending" }["reviewer"]
    assert inertia_props(admin_transfers_path, "Admin/Transfers/Index")["can"]["view_users"]
  end

  test "a transfer's page has the snapshot and suggests hours and XP" do
    props = inertia_props(admin_transfer_path(project_transfers(:stardance)), "Admin/Transfers/Show")
    assert_equal [ 180, XpEntry.journal_xp(180, 1) ], props["transfer"].values_at("suggested_minutes", "suggested_xp")
    assert_equal "Designed the legs.", props["transfer"].dig("snapshot", "entries", 0, "body")
    assert_equal [ projects(:station).public_id, projects(:unlinked).public_id ].sort, props["transfer"]["user_projects"].pluck("id").sort
    assert props["can"]["approve"]
    assert_equal "https://hackclub.slack.com/app_redirect?channel=#{users(:member).slack_id}", props["transfer"]["slack_dm_url"]
  end

  test "the note and message save as they're typed, without a version each time, until the transfer is decided" do
    transfer = project_transfers(:stardance)
    assert_no_difference -> { transfer.versions.count } do
      patch draft_admin_transfer_path(transfer), params: { transfer: { note: "Hours look high" }, was: { note: "" } }, as: :json
    end

    assert_response :ok
    assert_equal({ "result" => "saved", "note" => "Hours look high", "message" => nil }, response.parsed_body.except("draft_saved_at"))
    assert_equal [ "Hours look high", nil ], transfer.reload.values_at(:note, :message)
    assert_equal "Hours look high", inertia_props(admin_transfer_path(transfer), "Admin/Transfers/Show").dig("transfer", "note")

    transfer.update!(status: "rejected", reviewer: users(:admin), note: "Final")
    patch draft_admin_transfer_path(transfer), params: { transfer: { note: "Changed after" }, was: { note: "Final" } }, as: :json
    assert_response :conflict
    assert_equal "decided", response.parsed_body["result"]
    assert_nil flash[:alert]
    assert_equal "Final", transfer.reload.note
  end

  test "two reviewers typing at once keep each other's note and message" do
    transfer = project_transfers(:stardance)
    patch draft_admin_transfer_path(transfer), params: { transfer: { note: "Hours look high" }, was: { note: "" } }, as: :json
    assert_response :ok

    # The other reviewer opened it before that note: editing only the message leaves the note and hands it back.
    patch draft_admin_transfer_path(transfer), params: { transfer: { message: "Nice work" }, was: { message: "" } }, as: :json
    assert_response :ok
    assert_equal({ "result" => "saved", "note" => "Hours look high", "message" => "Nice work" }, response.parsed_body.except("draft_saved_at"))

    # Editing the note they never saw is refused rather than wiping it.
    patch draft_admin_transfer_path(transfer), params: { transfer: { note: "Looks fine" }, was: { note: "" } }, as: :json
    assert_response :conflict
    assert_equal "conflict", response.parsed_body["result"]
    assert_equal [ "Hours look high", "Nice work" ], transfer.reload.values_at(:note, :message)

    patch draft_admin_transfer_path(transfer), params: { transfer: { note: "" }, was: { note: "Hours look high" } }, as: :json
    assert_response :ok
    assert_equal [ nil, "Nice work" ], transfer.reload.values_at(:note, :message)
  end

  test "with no Fallen account, Slack opens the account the project was written from" do
    transfer = project_transfers(:stardance)
    transfer.update!(user: nil, snapshot: transfer.snapshot.deep_merge("owner" => { "slack_id" => "U0THERE" }))
    props = inertia_props(admin_transfer_path(transfer), "Admin/Transfers/Show")
    assert_equal "https://hackclub.slack.com/app_redirect?channel=U0THERE", props["transfer"]["slack_dm_url"]

    transfer.update!(snapshot: nil)
    assert_nil inertia_props(admin_transfer_path(transfer), "Admin/Transfers/Show").dig("transfer", "slack_dm_url")
  end

  test "the person's projects name the owner of the ones they are only a member of" do
    projects(:admins).memberships.create!(user: users(:member))
    owners = inertia_props(admin_transfer_path(project_transfers(:stardance)), "Admin/Transfers/Show")["transfer"]["user_projects"].to_h { [ it["id"], it["owner"] ] }

    assert_equal "Admin Person", owners[projects(:admins).public_id]
    assert_nil owners[projects(:station).public_id]
  end

  test "approving imports the journals and issues the XP the reviewer typed" do
    transfer = project_transfers(:stardance)
    post approve_admin_transfer_path(transfer), params: { transfer: { hours: "2.5", xp: "25", project_id: projects(:station).public_id, note: "Looks right", message: "Welcome!" } }

    assert_redirected_to admin_transfer_path(transfer)
    transfer.reload
    assert_equal [ "approved", 150, 25, projects(:station), users(:admin) ], transfer.values_at(:status, :approved_minutes, :xp, :project, :reviewer)
    assert_equal [ "Looks right", "Welcome!" ], transfer.values_at(:note, :message)
    assert_enqueued_with(job: ProjectTransferDecidedJob, args: [ transfer, { new_project: false, to: users(:member) } ])
    assert_equal 150, projects(:station).journals.where(source: "transfer").sum(:duration_minutes)
  end

  test "approving can write journals in by hand" do
    transfer = project_transfers(:stardance)
    transfer.update!(snapshot: nil)
    post approve_admin_transfer_path(transfer), params: { transfer: { hours: "8", xp: "40", journals: [ { body: "Made a hairpin", date: "2026-10-20", images: [] } ] } }

    assert_redirected_to admin_transfer_path(transfer)
    journal = transfer.reload.project.journals.sole
    assert_equal [ 480, "transfer" ], [ journal.duration_minutes, journal.source ]
    assert journal.body.start_with?("Made a hairpin")
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
    post reject_admin_transfer_path(transfer), params: { transfer: { note: "Not their project", message: "Send it from your own account" } }
    assert_redirected_to admin_transfers_path
    assert_equal [ "rejected", "Not their project", "Send it from your own account" ], transfer.reload.values_at(:status, :note, :message)
    assert_enqueued_with(job: ProjectTransferDecidedJob, args: [ transfer ])

    post approve_admin_transfer_path(transfer), params: { transfer: { hours: "1", xp: "8" } }
    assert_equal "You are not allowed to do that.", flash[:alert]
    assert_not Journal.exists?(source: "transfer")
  end

  test "pulling from Airtable and fetching again are jobs" do
    assert_enqueued_with(job: SyncProjectTransfersJob) { post sync_admin_transfers_path }
    assert_enqueued_with(job: FetchProjectTransferJob, args: [ project_transfers(:stardance) ]) { post refetch_admin_transfer_path(project_transfers(:stardance)) }
  end

  test "reviewers decide transfers but can't pull the form or open the rest of the panel" do
    reviewer = users(:newcomer).tap { it.update!(roles: %w[user reviewer]) }
    sign_in_as reviewer
    assert inertia_props(admin_transfer_path(project_transfers(:stardance)), "Admin/Transfers/Show")["can"]["reject"]

    post reject_admin_transfer_path(project_transfers(:stardance)), params: { transfer: { note: "Not theirs" } }
    assert_equal [ "rejected", reviewer ], project_transfers(:stardance).reload.values_at(:status, :reviewer)

    assert_not inertia_props(admin_transfers_path, "Admin/Transfers/Index")["can"]["view_users"]
    assert_no_enqueued_jobs { post sync_admin_transfers_path }
    get admin_users_path
    assert_response :not_found
  end

  test "members can't see transfers" do
    sign_in_as users(:member)
    get admin_transfers_path
    assert_response :not_found
  end

  test "saving the note says when, so the page can show when it was last saved" do
    transfer = project_transfers(:stardance)
    patch draft_admin_transfer_path(transfer), params: { transfer: { note: "Hours look high" }, was: { note: "" } }, as: :json

    saved_at = response.parsed_body["draft_saved_at"]
    assert saved_at
    assert_equal transfer.reload.draft_saved_at.as_json, saved_at
    assert_equal saved_at, inertia_props(admin_transfer_path(transfer), "Admin/Transfers/Show").dig("transfer", "draft_saved_at")
  end

  test "reaching out records who did it, and the first one keeps it" do
    transfer = project_transfers(:stardance)
    post reach_out_admin_transfer_path(transfer)

    assert_redirected_to admin_transfers_path
    assert_equal users(:admin), transfer.reload.reached_out_by
    assert transfer.reached_out_at

    reviewer = users(:newcomer).tap { it.update!(roles: %w[user reviewer]) }
    sign_in_as reviewer
    post reach_out_admin_transfer_path(transfer)
    assert_equal users(:admin), transfer.reload.reached_out_by

    row = load_deferred(admin_transfers_path, "Admin/Transfers/Index", "transfers")["transfers"].find { it["id"] == transfer.public_id }
    assert_equal "Admin Person", row.dig("reached_out_by", "name")
    assert_equal "Admin Person", inertia_props(admin_transfer_path(transfer), "Admin/Transfers/Show").dig("transfer", "reached_out_by", "name")
  end

  test "marking reached out isn't versioned, and a discarded transfer offers no button and refuses it" do
    transfer = project_transfers(:stardance)
    assert inertia_props(admin_transfer_path(transfer), "Admin/Transfers/Show")["can"]["reach_out"]
    assert_no_difference -> { transfer.versions.count } do
      post reach_out_admin_transfer_path(transfer)
      delete reach_out_admin_transfer_path(transfer)
    end

    transfer.discard
    assert_not inertia_props(admin_transfer_path(transfer), "Admin/Transfers/Show")["can"]["reach_out"]
    post reach_out_admin_transfer_path(transfer)
    assert_nil transfer.reload.reached_out_by
  end

  test "reaching out from a transfer's page goes back to it" do
    transfer = project_transfers(:stardance)
    post reach_out_admin_transfer_path(transfer), headers: { "HTTP_REFERER" => admin_transfer_url(transfer) }

    assert_redirected_to admin_transfer_url(transfer)
    assert_equal users(:admin), transfer.reload.reached_out_by
  end

  test "anyone reviewing transfers can take a reach out back off, and then reach out again" do
    transfer = project_transfers(:stardance)
    post reach_out_admin_transfer_path(transfer)

    sign_in_as users(:newcomer).tap { it.update!(roles: %w[user reviewer]) }
    delete reach_out_admin_transfer_path(transfer), headers: { "HTTP_REFERER" => admin_transfer_url(transfer) }
    assert_redirected_to admin_transfer_url(transfer)
    assert_nil transfer.reload.reached_out_by
    assert_nil transfer.reached_out_at

    post reach_out_admin_transfer_path(transfer)
    assert_equal users(:newcomer), transfer.reload.reached_out_by
  end

  test "members can't reach out" do
    sign_in_as users(:member)
    post reach_out_admin_transfer_path(project_transfers(:stardance))
    assert_response :not_found
    assert_nil project_transfers(:stardance).reload.reached_out_by

    project_transfers(:stardance).reach_out(by: users(:admin))
    delete reach_out_admin_transfer_path(project_transfers(:stardance))
    assert_response :not_found
    assert_equal users(:admin), project_transfers(:stardance).reload.reached_out_by
  end
end
