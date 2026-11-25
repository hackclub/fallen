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

  # Shown on the grant on HCB (and in the invite email when it's made), followed by the BOM lines its funding was
  # approved for. Sent when it's made and again on every top-up, so the list grows with each project.
  INSTRUCTIONS = Rails.root.join("config/hcb/grant_instructions.md").read.freeze
  PURPOSE_MAX_LENGTH = 30 # HCB's limit

  # "Fallen: Clock, Synth", the projects this card has funded, newest first, cut to HCB's limit.
  def self.purpose_for(submissions) = "Fallen: #{submissions.map { it.project.title }.uniq.join(", ")}".truncate(PURPOSE_MAX_LENGTH)

  def self.instructions_for(submissions)
    sections = submissions.filter_map do |submission|
      lines = submission.bom_items.select { it.funded_cents.positive? }.map { bom_line(it) }
      "**#{markdown_text(submission.project.title)}**\n\n#{lines.join("\n")}" if lines.any?
    end
    return INSTRUCTIONS if sections.empty?

    "#{INSTRUCTIONS.rstrip}\n\n## What you can buy with this card\n\nThe parts approved from your BOM, and how much each was approved for.\n\n#{sections.join("\n\n")}\n"
  end

  def self.bom_line(item)
    name = markdown_text(item.name)
    name = "[#{name}](#{item.link.gsub("(", "%28").gsub(")", "%29")})" if item.link.present?
    name = "#{item.quantity} × #{name}" if item.part? && item.quantity > 1
    "- #{name}: #{Money.format(item.funded_cents)}"
  end

  # Participant text, so markdown in it can't restyle the instructions or add links.
  def self.markdown_text(text) = text.to_s.squish.gsub(/[\\`*_\[\]<>#|]/) { "\\#{it}" }

  belongs_to :user
  has_many :grant_payouts, dependent: :restrict_with_error

  validates :status, inclusion: { in: %w[active canceled expired] }
  validates :amount_cents, numericality: { only_integer: true, greater_than: 0 }

  scope :active, -> { where(status: "active") }

  # The submissions this card's money came from, newest first.
  def funded_submissions = grant_payouts.where(status: "sent").includes(submission: [ :project, :bom_items ]).order(sent_at: :desc).map(&:submission)
end
