# The HCB card grant one person's design funding goes onto: made by their first GrantPayout, topped up by the rest.
# == Schema Information
#
# Table name: hcb_grant_cards
#
#  id             :bigint           not null, primary key
#  amount_cents   :integer          not null
#  balance_cents  :integer
#  email          :string
#  last_synced_at :datetime
#  status         :string           default("active"), not null
#  created_at     :datetime         not null
#  updated_at     :datetime         not null
#  hcb_id         :string
#  user_id        :bigint           not null
#
# Indexes
#
#  index_hcb_grant_cards_on_hcb_id            (hcb_id) UNIQUE
#  index_hcb_grant_cards_on_user_id           (user_id)
#  index_hcb_grant_cards_one_active_per_user  (user_id) UNIQUE WHERE ((status)::text = 'active'::text)
#
# Foreign Keys
#
#  fk_rails_...  (user_id => users.id)
#
class HcbGrantCard < ApplicationRecord
  has_paper_trail

  # Shown on the grant on HCB. Set when it's made and again on every top-up, so older cards get it too.
  INSTRUCTIONS = Rails.root.join("config/hcb/grant_instructions.md").read.freeze
  PURPOSE_MAX_LENGTH = 30 # HCB's limit

  # "Fallen: Clock, Synth", the projects this card has funded, newest first, cut to HCB's limit.
  def self.purpose_for(titles) = "Fallen: #{titles.uniq.join(", ")}".truncate(PURPOSE_MAX_LENGTH)

  belongs_to :user
  has_many :grant_payouts, dependent: :restrict_with_error

  validates :status, inclusion: { in: %w[active canceled expired] }
  validates :amount_cents, numericality: { only_integer: true, greater_than: 0 }

  scope :active, -> { where(status: "active") }

  def project_titles = grant_payouts.where(status: "sent").includes(submission: :project).order(sent_at: :desc).map { it.submission.project.title }
end
