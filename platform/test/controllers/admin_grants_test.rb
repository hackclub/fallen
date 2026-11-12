require "test_helper"

class AdminGrantsTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper

  setup do
    sign_in_as users(:admin)
    submission = submit_design(projects(:station))
    submission.update!(status: "approved", approved_cents: 700)
    @payout = GrantPayout.create!(submission:, user: submission.user, amount_cents: 700)
  end

  test "payouts to send, with HCB's state" do
    props = load_deferred(admin_grants_path, "Admin/Grants/Index", "payouts", "pagy", "totals")
    assert_equal [ @payout.public_id ], props["payouts"].pluck("id")
    assert_equal 700, props["totals"]["unsent"]
    refute inertia_props(admin_grants_path, "Admin/Grants/Index")["hcb"]["connected"]
  end

  test "marking one sent by hand, and checking HCB for a failed one" do
    post mark_sent_admin_grant_path(@payout), params: { reference: "cdg_x" }
    assert @payout.reload.sent?

    other = GrantPayout.create!(submission: submit_design(projects(:unlinked)), user: users(:member), amount_cents: 100, status: "failed")
    post check_admin_grant_path(other)
    assert_no_enqueued_jobs(only: GrantPayoutJob) # HCB isn't connected yet

    HcbConnection.create!(connected_by: users(:admin), access_token: "t", token_expires_at: 1.hour.from_now)
    with_env("HCB_CLIENT_ID" => "id", "HCB_CLIENT_SECRET" => "s", "HCB_ORGANIZATION_ID" => "org_x") do
      assert_enqueued_with(job: GrantPayoutJob, args: [ other, { check: true } ]) { post check_admin_grant_path(other) }
      assert_enqueued_with(job: GrantLedgerSyncJob) { post hcb_sync_admin_grants_path }
    end
  end

  test "the On HCB tab lists every grant in the org, with whoever HCB and Fallen disagree about" do
    HcbConnection.create!(connected_by: users(:admin), access_token: "t", token_expires_at: 1.hour.from_now, ledger_checked_at: Time.current)
    HcbOrgGrant.create!(hcb_id: "cdg_a", email: users(:member).email, user: users(:member), amount_cents: 500, status: "active", synced_at: Time.current)
    HcbOrgGrant.create!(hcb_id: "cdg_b", email: "nobody@example.com", amount_cents: 200, status: "active", synced_at: Time.current)

    props = load_deferred(admin_grants_path(tab: "hcb"), "Admin/Grants/Index", "grants", "pagy", "ledger")
    assert_equal %w[cdg_b cdg_a], props["grants"].pluck("id"), "unmatched first"
    assert_equal({ "hcb_cents" => 500, "fallen_cents" => 0 }, props["grants"].last["ledger"])
    assert_equal [ 1, 1 ], props["ledger"].values_at("mismatch_count", "unmatched_count")

    patch admin_hcb_grant_path("cdg_a"), params: { ignored: true }
    assert HcbOrgGrant.find_by!(hcb_id: "cdg_a").ignored?
    assert_equal users(:admin), HcbOrgGrant.find_by!(hcb_id: "cdg_a").ignored_by
  end

  test "sending needs HCB connected" do
    post send_now_admin_grant_path(@payout)
    assert_no_enqueued_jobs only: GrantPayoutJob
  end

  test "admins only" do
    sign_in_as users(:member)
    get admin_grants_path
    assert_response :not_found
    HcbOrgGrant.create!(hcb_id: "cdg_a", email: "x@example.com", amount_cents: 1, status: "active", synced_at: Time.current)
    patch admin_hcb_grant_path("cdg_a"), params: { ignored: true }
    refute HcbOrgGrant.find_by!(hcb_id: "cdg_a").ignored?
  end
end
