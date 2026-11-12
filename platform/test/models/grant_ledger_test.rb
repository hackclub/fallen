require "test_helper"

class GrantLedgerTest < ActiveSupport::TestCase
  setup do
    @member = users(:member)
    HcbConnection.create!(connected_by: users(:admin), access_token: "t", token_expires_at: 1.hour.from_now)
  end

  test "copies every grant in the org and matches people by email, card or payout reference" do
    grants = [
      { id: "cdg_a", email: @member.email.upcase, amount_cents: 500, status: "active", expires_on: "2026-12-11" },
      { id: "cdg_b", email: "nobody@example.com", amount_cents: 200, status: "expired" }
    ]
    with_fake_hcb(grants) do
      GrantLedger.sync!
      assert_equal @member, HcbOrgGrant.find_by!(hcb_id: "cdg_a").user
      assert_nil HcbOrgGrant.find_by!(hcb_id: "cdg_b").user
      assert_equal 1, HcbOrgGrant.unmatched.count
      assert HcbConnection.current.ledger_checked_at

      payout = GrantPayout.create!(submission: submit_design(projects(:station)), user: @member, amount_cents: 200)
      payout.mark_sent!(by: users(:admin), reference: "cdg_b")
      GrantLedger.sync!
      assert_equal @member, HcbOrgGrant.find_by!(hcb_id: "cdg_b").user, "a payout marked sent with the id claims the grant"
    end
  end

  test "lists people HCB and Fallen disagree about, and an ignored grant stops counting" do
    with_fake_hcb([ { id: "cdg_a", email: @member.email, amount_cents: 500, status: "active" } ]) do
      GrantLedger.sync!
      checked = HcbConnection.current.reload.ledger_checked_at
      assert_equal({ @member.id => [ 500, 0 ] }, GrantLedger.mismatches(checked))

      HcbOrgGrant.find_by!(hcb_id: "cdg_a").update!(ignored_at: Time.current)
      GrantLedger.sync!
      assert_empty GrantLedger.mismatches(checked), "ignoring survives a sync"
    end
  end

  test "an expired grant on HCB retires Fallen's card" do
    card = HcbGrantCard.create!(user: @member, hcb_id: "cdg_a", email: @member.email, amount_cents: 500)
    with_fake_hcb([ { id: "cdg_a", email: @member.email, amount_cents: 500, status: "expired" } ]) { GrantLedger.sync! }
    assert_equal "expired", card.reload.status
  end

  test "the scheduled check reports a disagreement to Sentry" do
    reported = []
    original = Sentry.method(:capture_message)
    Sentry.define_singleton_method(:capture_message) { |message, **| reported << message }
    with_fake_hcb([ { id: "cdg_a", email: @member.email, amount_cents: 500, status: "active" } ]) do
      stub_method(Hcb, :configured?, true) { GrantLedgerSyncJob.perform_now }
    end
    assert_equal [ "HCB and Fallen disagree on design funding" ], reported
  ensure
    Sentry.define_singleton_method(:capture_message, original)
  end
end
