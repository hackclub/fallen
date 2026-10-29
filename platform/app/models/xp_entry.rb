# One line in the XP ledger; users.xp is the sum of the kept ones. A journal's entry follows its hours
# (Journal#sync_xp) and keeps the multiplier the person had when it was first saved. Deleting its source discards the
# entry rather than removing it, so the ledger still shows what was earned and taken back. Everything else is granted once: by its source, or by kind
# and day, so a week can be closed again without paying twice. `day` is the person's own calendar day. A transfer's
# XP is the amount its reviewer set (ProjectTransfer#approve); its journals earn none of their own. `pet` is the team
# the person was on when it was made, which it counts for in the race whatever they switch to later.
# == Schema Information
#
# Table name: xp_entries
#
#  id           :bigint           not null, primary key
#  amount       :integer          not null
#  day          :date             not null
#  discarded_at :datetime
#  kind         :string           not null
#  multiplier   :decimal(3, 2)
#  pet          :string
#  source_type  :string
#  created_at   :datetime         not null
#  updated_at   :datetime         not null
#  source_id    :bigint
#  user_id      :bigint           not null
#
# Indexes
#
#  index_xp_entries_on_created_at_and_pet                  (created_at,pet)
#  index_xp_entries_on_discarded_at                        (discarded_at)
#  index_xp_entries_on_source_type_and_source_id_and_kind  (source_type,source_id,kind) UNIQUE WHERE (source_id IS NOT NULL)
#  index_xp_entries_on_user_id                             (user_id)
#  index_xp_entries_on_user_id_and_day                     (user_id,day)
#  index_xp_entries_on_user_id_and_kind_and_day            (user_id,kind,day) UNIQUE WHERE (source_id IS NULL)
#  index_xp_entries_one_stupendous_per_user                (user_id) UNIQUE WHERE ((kind)::text = 'stupendous'::text)
#
# Foreign Keys
#
#  fk_rails_...  (user_id => users.id)
#
class XpEntry < ApplicationRecord
  include Discardable

  has_paper_trail

  PER_HOUR = 8
  KINDS = %w[journal early_bird weekly_bonus team_win stupendous transfer grant].freeze
  # Once per person, for the first journal that says "stupendous", spelled right, in any case.
  STUPENDOUS_BONUS = 20
  STUPENDOUS = /stupendous/i

  belongs_to :user
  belongs_to :source, polymorphic: true, optional: true

  validates :kind, inclusion: { in: KINDS }
  validates :amount, numericality: { only_integer: true }
  validates :day, presence: true

  scope :journals, -> { where(kind: "journal") }
  # XP on the days of the week, on the person's calendar, for the teams' own weekly rewards.
  scope :during, ->(week) { kept.where(day: week.days) }
  # XP that counts in the team race. A transfer's was earned in another program (admins can look at it alongside, on
  # /admin/teams), the win is the race's prize (it lands on the last day of the week it was won for and must not add
  # to that week), and a grant is an admin's (StreakAdjustment), not the team's.
  scope :raced, ->(transfers: false) { kept.where.not(kind: transfers ? %w[team_win grant] : %w[transfer team_win grant]) }
  # XP made during the race's week (Week#race_times). A bonus made after a week has ended counts in the week it was
  # made, even when its `day` is in the one before, so a week that has been paid never changes.
  scope :raced_in, ->(week, transfers: false) { raced(transfers:).where(created_at: week.race_times) }

  before_create -> { self.pet ||= user.pet }
  after_save :recount_user
  after_create_commit -> { StupendousBonusJob.perform_later(self) }, if: -> { kind == "stupendous" }

  # Every journal with hours is worth at least 1 XP, so the first one always hatches the egg.
  def self.journal_xp(minutes, multiplier) = [ (minutes * PER_HOUR / 60.0 * multiplier).round, 1 ].max

  # Makes, updates, discards or brings back the journal's entry to match its hours.
  def self.sync(journal)
    entry = journal.xp_entry || journal.build_xp_entry(user: journal.user, kind: "journal", multiplier: journal.user.xp_multiplier, day: journal.user.local_date(journal.created_at))
    if journal.discarded? || !journal.hours_logged?
      entry.discard if entry.persisted? && !entry.discarded?
    else
      entry.update!(amount: journal_xp(journal.duration_minutes, entry.multiplier), discarded_at: nil)
    end
  end

  def self.grant_stupendous(journal)
    return unless Journal.written_text(journal.body).match?(STUPENDOUS)

    user = journal.user
    return if user.xp_entries.exists?(kind: "stupendous")

    user.xp_entries.create_or_find_by!(kind: "stupendous") do |entry|
      entry.assign_attributes(amount: STUPENDOUS_BONUS, day: user.local_date(journal.created_at), source: journal)
    end
  end

  # XP each team earned in the race's week, by pet name: each entry for the team it was made on, from people who can
  # still be paid (User.on_a_team), so a ban takes someone's XP out of the race.
  def self.team_totals(week) = raced_in(week).joins(:user).merge(User.on_a_team).where.not(pet: nil).group("xp_entries.pet").sum(:amount)

  private

  def recount_user = User.recount_xp(user_id)
end
