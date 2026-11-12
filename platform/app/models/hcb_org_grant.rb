# Fallen's copy of one card grant in the program's HCB organization, as HCB last reported it (GrantLedger.sync!).
# Every grant in the org is copied, including ones made by hand on HCB, so money Fallen doesn't know about shows up.
# amount_cents is HCB's running total: the first amount plus every top-up, minus withdrawals.
# == Schema Information
#
# Table name: hcb_org_grants
#
#  id            :bigint           not null, primary key
#  amount_cents  :integer          not null
#  balance_cents :integer
#  email         :string           not null
#  expires_on    :date
#  ignored_at    :datetime
#  purpose       :string
#  status        :string           not null
#  synced_at     :datetime         not null
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#  hcb_id        :string           not null
#  ignored_by_id :bigint
#  user_id       :bigint
#
# Indexes
#
#  index_hcb_org_grants_on_email          (email)
#  index_hcb_org_grants_on_hcb_id         (hcb_id) UNIQUE
#  index_hcb_org_grants_on_ignored_by_id  (ignored_by_id)
#  index_hcb_org_grants_on_user_id        (user_id)
#
# Foreign Keys
#
#  fk_rails_...  (ignored_by_id => users.id)
#  fk_rails_...  (user_id => users.id)
#
class HcbOrgGrant < ApplicationRecord
  has_paper_trail

  belongs_to :user, optional: true
  belongs_to :ignored_by, class_name: "User", optional: true

  # Grants that count towards what a person has been paid. An admin leaves one out when it isn't design funding.
  scope :counted, -> { where(ignored_at: nil) }
  scope :unmatched, -> { counted.where(user_id: nil) }

  def ignored? = ignored_at.present?
  def hcb_url = "#{Hcb.host}/grants/#{hcb_id}"
  def expires_soon? = expires_on.present? && expires_on <= GrantLedger::TOP_UP_MARGIN.from_now.to_date
end
