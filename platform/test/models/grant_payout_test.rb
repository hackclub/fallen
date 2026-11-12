require "test_helper"

# == Schema Information
#
# Table name: grant_payouts
#
#  id                :bigint           not null, primary key
#  amount_cents      :integer          not null
#  error             :text
#  hcb_reference     :string
#  sent_at           :datetime
#  status            :string           default("pending"), not null
#  via               :string           default("auto"), not null
#  created_at        :datetime         not null
#  updated_at        :datetime         not null
#  hcb_grant_card_id :bigint
#  sent_by_id        :bigint
#  submission_id     :bigint           not null
#  user_id           :bigint           not null
#
# Indexes
#
#  index_grant_payouts_on_hcb_grant_card_id  (hcb_grant_card_id)
#  index_grant_payouts_on_sent_by_id         (sent_by_id)
#  index_grant_payouts_on_status             (status)
#  index_grant_payouts_on_submission_id      (submission_id)
#  index_grant_payouts_on_user_id            (user_id)
#  index_grant_payouts_one_per_submission    (submission_id) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (hcb_grant_card_id => hcb_grant_cards.id)
#  fk_rails_...  (sent_by_id => users.id)
#  fk_rails_...  (submission_id => submissions.id)
#  fk_rails_...  (user_id => users.id)
#
class GrantPayoutTest < ActiveSupport::TestCase
  setup do
    @submission = submit_design(projects(:station))
    @submission.update!(status: "approved", approved_cents: 700)
    @payout = GrantPayout.create!(submission: @submission, user: @submission.user, amount_cents: 700)
  end

  test "the first payout makes the person's card, the next one tops it up" do
    with_fake_hcb do |hcb|
      @payout.send!
      assert @payout.reload.sent?
      assert_equal "cdg_1", @payout.hcb_reference

      second = GrantPayout.create!(submission: submit_design(projects(:unlinked)), user: @submission.user, amount_cents: 300)
      second.send!
      assert second.reload.sent?
      assert_equal [ 1000 ], hcb[:grants].pluck(:amount_cents), "topped up, not a second card"
      assert_equal 1000, @payout.hcb_grant_card.reload.amount_cents
    end
  end

  test "not connected leaves it waiting" do
    @payout.send!
    assert @payout.reload.pending?
    assert_match "connected", @payout.error
  end

  test "a send that reached HCB but timed out is never sent again; Check HCB marks it sent" do
    with_fake_hcb do |hcb|
      hcb[:lose_reply] = true
      @payout.send!
      assert @payout.reload.failed?
      assert_match "Check HCB", @payout.error

      @payout.send!
      assert @payout.reload.failed?, "a failed send isn't tried again by itself"

      @payout.check_hcb!
      assert @payout.reload.sent?
      assert_equal "cdg_1", @payout.hcb_reference
      assert_equal 1, hcb[:grants].size
      assert_equal @payout.hcb_grant_card, @submission.user.hcb_grant_cards.active.sole, "adopts the card HCB made"
    end
  end

  test "a send that never reached HCB goes back to unsent on Check HCB" do
    with_fake_hcb do
      @payout.update!(status: "failed", error: "Faraday::TimeoutError")
      @payout.check_hcb!
      assert @payout.reload.pending?
    end
  end

  test "a send that is still in flight isn't checked" do
    with_fake_hcb do
      @payout.update!(status: "sending")
      @payout.check_hcb!
      assert @payout.reload.sending?
    end
  end

  test "nothing is sent while HCB shows money Fallen doesn't know about" do
    with_fake_hcb([ { id: "cdg_hand", email: @submission.user.email, amount_cents: 700, status: "active", purpose: "made by hand" } ]) do |hcb|
      @payout.send!
      assert @payout.reload.failed?
      assert_match "HCB shows $7", @payout.error
      assert_equal [ "cdg_hand" ], hcb[:grants].pluck(:id), "nothing new on HCB"

      @payout.check_hcb!
      assert @payout.reload.sent?, "the hand-made grant is exactly this payout, so it counts as sent"
    end
  end

  test "an expired card isn't topped up; a new one is made" do
    with_fake_hcb do |hcb|
      @payout.send!
      hcb[:grants].first[:status] = "expired"

      second = GrantPayout.create!(submission: submit_design(projects(:unlinked)), user: @submission.user, amount_cents: 300)
      second.send!
      assert second.reload.sent?
      assert_equal [ 700, 300 ], hcb[:grants].pluck(:amount_cents)
      assert_equal "expired", @payout.hcb_grant_card.reload.status
    end
  end

  test "a card about to expire isn't topped up either" do
    with_fake_hcb do |hcb|
      @payout.send!
      hcb[:grants].first[:expires_on] = Date.tomorrow.iso8601

      second = GrantPayout.create!(submission: submit_design(projects(:unlinked)), user: @submission.user, amount_cents: 300)
      second.send!
      assert_equal 2, hcb[:grants].size
    end
  end

  test "an admin marks one sent by hand, and the grant's link becomes its reference" do
    @payout.mark_sent!(by: users(:admin), reference: "https://hcb.hackclub.com/grants/cdg_hand")
    assert_equal %w[sent manual cdg_hand], @payout.reload.attributes.values_at("status", "via", "hcb_reference")
  end
end
