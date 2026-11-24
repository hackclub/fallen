# One line in the XP ledger; users.xp is the sum of the kept ones. A journal's entry follows its hours, less any a
# design reviewer took off (Journal#counted_minutes, Journal#sync_xp), and keeps the multiplier the person had when it was first saved (with any FlashBoost). Deleting its source discards the
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
#  index_xp_entries_one_email_signup_per_user              (user_id) UNIQUE WHERE ((kind)::text = 'email_signup'::text)
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
  KINDS = %w[journal early_bird weekly_bonus team_win stupendous transfer grant email_signup review_hold review_release].freeze
  # Once per person, for the first journal that says "stupendous", spelled right, in any case.
  STUPENDOUS_BONUS = 20
  STUPENDOUS = /stupendous/i
  # Once per person, for signing up from the big email (its UTM source) by the end of Sunday, Nov 1 anywhere on Earth
  # (UTC-12, the last timezone to finish the day).
  EMAIL_SIGNUP_BONUS = 20
  EMAIL_SIGNUP_SOURCE = "bigemailthing"
  EMAIL_SIGNUP_UNTIL = Time.utc(2026, 11, 2, 12)
  # Kinds that aren't the team's doing, so they never count in the race. XP a journal review holds back
  # (ProgressXpHold) comes back later as a release, so neither side of it moves the race.
  UNRACED = %w[team_win grant email_signup review_hold review_release].freeze

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
  # to that week), a grant is an admin's (StreakAdjustment), not the team's, and the email signup bonus is for signing up.
  scope :raced, ->(transfers: false) { kept.where.not(kind: transfers ? UNRACED : UNRACED + %w[transfer]) }
  # XP made during the race's week (Week#race_times). A bonus made after a week has ended counts in the week it was
  # made, even when its `day` is in the one before, so a week that has been paid never changes.
  scope :raced_in, ->(week, transfers: false) { raced(transfers:).where(created_at: week.race_times) }

  before_create -> { self.pet ||= user.pet }
  after_save :recount_user
  after_create_commit -> { StupendousBonusJob.perform_later(self) }, if: -> { kind == "stupendous" }
  after_create_commit -> { EmailSignupBonusJob.perform_later(self) }, if: -> { kind == "email_signup" }
  # A day starting or stopping to count crosses them off, or back onto, the evening's ping (DayEndReminder).
  after_commit -> { DayEndReminder.journal_changed(self) }, if: -> { kind == "journal" && previous_changes.keys.intersect?(%w[id discarded_at]) }

  # Every journal with hours is worth at least 1 XP, so the first one always hatches the egg.
  def self.journal_xp(minutes, multiplier) = [ (minutes * PER_HOUR / 60.0 * multiplier).round, 1 ].max

  # Makes, updates, discards or brings back the journal's entry to match its hours. A journal a design review counted
  # no time for (SubmissionReview) is worth nothing.
  def self.sync(journal)
    entry = journal.xp_entry || journal.build_xp_entry(user: journal.user, kind: "journal", multiplier: multiplier_for(journal), day: journal.user.local_date(journal.created_at))
    if journal.discarded? || !journal.hours_logged? || journal.counted_minutes.zero?
      entry.discard if entry.persisted? && !entry.discarded?
    else
      entry.update!(amount: journal_xp(journal.counted_minutes, entry.multiplier), discarded_at: nil)
    end
  end

  # The person's multiplier now, as the entry is first made, with any flash event the journal was written in (FlashBoost).
  def self.multiplier_for(journal)
    FlashBoost.multiplier(journal.user, written_at: journal.created_at || Time.current)
  end

  def self.grant_stupendous(journal)
    return unless Journal.written_text(journal.body).match?(STUPENDOUS)

    user = journal.user
    return if user.xp_entries.exists?(kind: "stupendous")

    user.xp_entries.create_or_find_by!(kind: "stupendous") do |entry|
      entry.assign_attributes(amount: STUPENDOUS_BONUS, day: user.local_date(journal.created_at), source: journal)
    end
  end

  def self.email_signup?(user)
    user.signup_source["utm_source"] == EMAIL_SIGNUP_SOURCE && user.created_at <= EMAIL_SIGNUP_UNTIL
  end

  def self.grant_email_signup(user)
    return unless email_signup?(user)
    return if user.xp_entries.exists?(kind: "email_signup")

    user.xp_entries.create_or_find_by!(kind: "email_signup") do |entry|
      entry.assign_attributes(amount: EMAIL_SIGNUP_BONUS, day: user.local_date(user.created_at))
    end
  end

  # A trial account handed over to the account someone already had (User#hand_over_to!) brings its bonus along, unless
  # that one has it already. The DM goes now if the trial had no Slack to send it to.
  def self.hand_over_email_signup(trial, user)
    entry = trial.xp_entries.kept.find_by(kind: "email_signup")
    return if entry.nil? || user.xp_entries.exists?(kind: "email_signup")

    entry.update!(user: user, pet: user.pet)
    User.recount_xp(trial.id)
    EmailSignupBonusJob.perform_later(entry) if trial.slack_id.blank?
  end

  # XP each team earned in the race's week, by pet name: each entry for the team it was made on, from people who can
  # still be paid (User.on_a_team), so a ban takes someone's XP out of the race.
  def self.team_totals(week) = raced_in(week).joins(:user).merge(User.on_a_team).where.not(pet: nil).group("xp_entries.pet").sum(:amount)

  private

  def recount_user = User.recount_xp(user_id)
end
