# One line of a Submission's bill of materials, as the person submitted it, and what the reviewer decided about it.
# A line someone already owns is listed at its real price but asks for nothing. The funding is the sum of the
# approved lines (Submission#approved_cents).
# == Schema Information
#
# Table name: bom_items
#
#  id             :bigint           not null, primary key
#  approved_cents :integer
#  kind           :string           default("part"), not null
#  link           :string
#  name           :string           not null
#  owned          :boolean          default(FALSE), not null
#  position       :integer          not null
#  purpose        :string
#  quantity       :integer          default(1), not null
#  reason         :string
#  total_cents    :integer          not null
#  unit_cents     :integer
#  vendor         :string
#  verdict        :string
#  created_at     :datetime         not null
#  updated_at     :datetime         not null
#  submission_id  :bigint           not null
#
# Indexes
#
#  index_bom_items_on_submission_id  (submission_id)
#
# Foreign Keys
#
#  fk_rails_...  (submission_id => submissions.id)
#
class BomItem < ApplicationRecord
  include PublicIdentifiable

  set_public_id_prefix :bom
  has_paper_trail

  KINDS = %w[part shipping tax].freeze
  VERDICTS = %w[approved adjusted cut].freeze
  CUT_REASONS = [ "Extra or spare parts", "A devboard or module you should design yourself", "A pricier option than needed",
    "A tool you don't need", "Not needed for this project", "Already owned", "Other" ].freeze
  ADJUST_REASONS = [ "Fewer needed", "A cheaper option exists", "The price was wrong", "Shipping or tax was off", "Other" ].freeze
  MAX_NAME = 200
  MAX_PURPOSE = 300
  MAX_LINK = 1_000
  MAX_ITEMS = 200
  MAX_CENTS = 100_000_00
  FIELDS = %i[kind name purpose quantity unit_cents total_cents link vendor owned].freeze
  URL = %r{\Ahttps?://[^\s]+\z}

  belongs_to :submission

  # Nothing to buy for a part they already have, so a note like "Owned" in the link cell isn't an error.
  before_validation { self.link = nil if owned? && !link.to_s.strip.match?(URL) }

  validates :kind, inclusion: { in: KINDS }
  validates :name, presence: true, length: { maximum: MAX_NAME }
  validates :purpose, length: { maximum: MAX_PURPOSE }
  validates :vendor, length: { maximum: 100 }
  validates :quantity, numericality: { only_integer: true, in: 1..10_000 }
  validates :total_cents, numericality: { only_integer: true, in: 0..MAX_CENTS }
  validates :unit_cents, numericality: { only_integer: true, in: 0..MAX_CENTS }, allow_nil: true
  validates :link, length: { maximum: MAX_LINK }, format: { with: URL, message: "must start with http(s)://" }, allow_blank: true
  validates :verdict, inclusion: { in: VERDICTS }, allow_nil: true
  validates :approved_cents, numericality: { only_integer: true, in: 0..MAX_CENTS }, allow_nil: true

  scope :ordered, -> { order(:position, :id) }

  def requested_cents = owned? ? 0 : total_cents
  def part? = kind == "part"

  # What the reviewer let through: the whole line, a smaller amount, or nothing.
  def funded_cents
    case verdict
    when "approved" then requested_cents
    when "adjusted" then [ approved_cents.to_i, requested_cents ].min
    else 0
    end
  end
end
