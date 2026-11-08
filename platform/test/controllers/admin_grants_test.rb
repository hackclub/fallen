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

  test "marking one sent by hand, and putting a failed one back" do
    post mark_sent_admin_grant_path(@payout), params: { reference: "cdg_x" }
    assert @payout.reload.sent?

    other = GrantPayout.create!(submission: submit_design(projects(:unlinked)), user: users(:member), amount_cents: 100, status: "failed")
    post retry_admin_grant_path(other)
    assert other.reload.pending?
  end

  test "sending needs HCB connected" do
    post send_now_admin_grant_path(@payout)
    assert_no_enqueued_jobs only: GrantPayoutJob
  end

  test "admins only" do
    sign_in_as users(:member)
    get admin_grants_path
    assert_response :not_found
  end
end
