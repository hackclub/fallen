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
    stub_method(Hcb, :create_card_grant, { id: "cdg_1", email: "m@example.com" }) { @payout.send! }
    assert @payout.reload.sent?
    assert_equal "cdg_1", @payout.hcb_reference

    topped = []
    second = GrantPayout.create!(submission: submit_design(projects(:unlinked)), user: @submission.user, amount_cents: 300)
    Hcb.define_singleton_method(:topup_card_grant) { |id, amount_cents:| topped << [ id, amount_cents ] }
    second.send!
    assert second.reload.sent?
    assert_equal [ [ "cdg_1", 300 ] ], topped
    assert_equal 1000, @payout.hcb_grant_card.reload.amount_cents
  ensure
    Hcb.singleton_class.remove_method(:topup_card_grant) if Hcb.singleton_methods(false).include?(:topup_card_grant) && topped
    load Rails.root.join("app/services/hcb.rb")
  end

  test "not connected leaves it waiting; a failed call is never retried by itself" do
    @payout.send!
    assert @payout.reload.pending?
    assert_match "connected", @payout.error

    Hcb.define_singleton_method(:create_card_grant) { |**| raise Faraday::TimeoutError }
    @payout.send!
    assert @payout.reload.failed?
    assert_match "check there", @payout.error
    @payout.send!
    assert @payout.reload.failed?, "a failed send isn't tried again until an admin says it didn't go through"

    @payout.retry!
    assert @payout.reload.pending?
  ensure
    load Rails.root.join("app/services/hcb.rb")
  end

  test "an admin marks one sent by hand" do
    @payout.mark_sent!(by: users(:admin), reference: "cdg_hand")
    assert_equal %w[sent manual cdg_hand], @payout.reload.attributes.values_at("status", "via", "hcb_reference")
  end
end
