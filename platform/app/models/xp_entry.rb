# One line in the XP ledger; users.xp is the sum. A journal's entry follows its hours (Journal#sync_xp) and keeps
# the multiplier the person had when it was first saved. Everything else is granted once: by its source, or by kind
# and day, so a week can be closed again without paying twice. `day` is the person's own calendar day.
# == Schema Information
#
# Table name: xp_entries
#
#  id          :bigint           not null, primary key
#  amount      :integer          not null
#  day         :date             not null
#  kind        :string           not null
#  multiplier  :decimal(2, 1)
#  source_type :string
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#  source_id   :bigint
#  user_id     :bigint           not null
#
# Indexes
#
#  index_xp_entries_on_source_type_and_source_id  (source_type,source_id) UNIQUE WHERE (source_id IS NOT NULL)
#  index_xp_entries_on_user_id                    (user_id)
#  index_xp_entries_on_user_id_and_day            (user_id,day)
#  index_xp_entries_on_user_id_and_kind_and_day   (user_id,kind,day) UNIQUE WHERE (source_id IS NULL)
#
# Foreign Keys
#
#  fk_rails_...  (user_id => users.id)
#
class XpEntry < ApplicationRecord
  PER_HOUR = 8
  KINDS = %w[journal early_bird weekly_bonus team_win streak].freeze

  belongs_to :user
  belongs_to :source, polymorphic: true, optional: true

  validates :kind, inclusion: { in: KINDS }
  validates :amount, numericality: { only_integer: true }
  validates :day, presence: true

  scope :journals, -> { where(kind: "journal") }
  scope :during, ->(week) { where(day: week.days) }

  after_save :recount_user
  after_destroy :recount_user

  # Every journal with hours is worth at least 1 XP, so the first one always hatches the egg.
  def self.journal_xp(minutes, multiplier) = [ (minutes * PER_HOUR / 60.0 * multiplier).round, 1 ].max

  # Makes, updates or removes the journal's entry to match its hours.
  def self.sync(journal)
    entry = journal.xp_entry || journal.build_xp_entry(user: journal.user, kind: "journal", multiplier: journal.user.xp_multiplier, day: journal.user.local_date(journal.created_at))
    if journal.discarded? || !journal.hours_logged?
      entry.destroy if entry.persisted?
    else
      entry.update!(amount: journal_xp(journal.duration_minutes, entry.multiplier))
    end
  end

  # XP each team earned in the week, by pet name.
  def self.team_totals(week) = during(week).joins(:user).where.not(users: { pet: nil }).group("users.pet").sum(:amount)

  private

  def recount_user = User.recount_xp(user_id)
end
