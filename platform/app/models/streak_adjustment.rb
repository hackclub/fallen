# frozen_string_literal: true

# An admin's change to someone's streak, kept with who made it and why, and undoable.
# - excuse: days (each person's own calendar days) that count as journaled for both teams' weekly rewards, for one
#   person or, as an incident, everyone. Weeks already judged are judged again (StreakReplay); ones still open count
#   them when they close.
# - freezes: freezes given (or taken), from now on. A week that already broke needs its days excused instead.
# - set: the multiplier and freezes set outright, for what nothing else covers.
# `effect` is what applying it changed, for the log. `notify` DMs the person (StreakAdjustedJob) with `message`;
# `reason` is for staff.
# == Schema Information
# Schema version: 20261028120100
#
# Table name: streak_adjustments
#
#  id           :bigint           not null, primary key
#  discarded_at :datetime
#  effect       :jsonb            not null
#  ends_on      :date
#  freezes      :integer
#  kind         :string           not null
#  message      :text
#  multiplier   :decimal(3, 2)
#  notify       :boolean          default(FALSE), not null
#  reason       :text             not null
#  reprice      :boolean          default(TRUE), not null
#  starts_on    :date
#  created_at   :datetime         not null
#  updated_at   :datetime         not null
#  admin_id     :bigint
#  undone_by_id :bigint
#  user_id      :bigint
#
# Indexes
#
#  index_streak_adjustments_on_admin_id                        (admin_id)
#  index_streak_adjustments_on_created_at                      (created_at)
#  index_streak_adjustments_on_discarded_at                    (discarded_at)
#  index_streak_adjustments_on_kind_and_starts_on_and_ends_on  (kind,starts_on,ends_on)
#  index_streak_adjustments_on_undone_by_id                    (undone_by_id)
#  index_streak_adjustments_on_user_id                         (user_id)
#
# Foreign Keys
#
#  fk_rails_...  (admin_id => users.id)
#  fk_rails_...  (undone_by_id => users.id)
#  fk_rails_...  (user_id => users.id)
#
class StreakAdjustment < ApplicationRecord
  include PublicIdentifiable
  include Discardable

  set_public_id_prefix :stk
  has_paper_trail

  KINDS = %w[excuse freezes set].freeze
  FIELDS = %i[kind starts_on ends_on freezes multiplier reason message notify reprice].freeze
  # Longer absences than this are better as several excuses with their own reasons.
  MAX_EXCUSE_DAYS = 14
  MAX_FREEZES = 20

  belongs_to :user, optional: true
  belongs_to :admin, class_name: "User", optional: true
  belongs_to :undone_by, class_name: "User", optional: true

  validates :kind, inclusion: { in: KINDS }
  validates :reason, presence: true, length: { maximum: 1000 }
  validates :message, length: { maximum: 2000 }
  validates :user, presence: true, unless: :excuse?
  validate :excuse_days, if: :excuse?
  validate :freezes_given, if: -> { kind == "freezes" }
  validate :state_set, if: -> { kind == "set" }

  scope :excuses, -> { where(kind: "excuse") }
  scope :incidents, -> { excuses.where(user_id: nil) }
  scope :concerning, ->(user) { where(user_id: [ nil, user.id ]) }
  scope :covering, ->(days) { where("starts_on <= ? AND ends_on >= ?", days.last, days.first) }

  # Days excused for the person, theirs and everyone's, as a Set. `adding` and `removing` are excuses not saved, or
  # not undone, yet.
  def self.excused_days(user, adding: nil, removing: nil)
    excuses = kept.excuses.concerning(user).to_a
    excuses.reject! { it == removing }
    excuses << adding if adding
    excuses.flat_map { it.days.to_a }.to_set
  end

  # What it did, for the admin who made it.
  def summary
    return "Excused #{days_text} for everyone. Everyone it touches is being judged again in the background." if incident?

    what =
      case kind
      when "excuse" then "Excused #{days_text}"
      when "freezes" then "#{freezes.positive? ? 'Gave' : 'Took'} #{freezes.abs} #{'freeze'.pluralize(freezes.abs)}"
      else "Set the streak"
      end
    changes = [ ("#{format('%.2f', effect['multiplier'].first)}x → #{format('%.2f', effect['multiplier'].last)}x" if effect["multiplier"]&.uniq&.size == 2),
                ("#{effect['freezes'].first} → #{effect['freezes'].last} freezes" if effect["freezes"]&.uniq&.size == 2),
                ("#{effect['xp'].positive? ? '+' : ''}#{effect['xp']} XP" if effect["xp"].to_i.nonzero?) ].compact
    "#{what} for #{user.display_name}#{changes.any? ? ": #{changes.join(', ')}" : ''}.#{' They will get a DM.' if notify?}"
  end

  def excuse? = kind == "excuse"
  def incident? = excuse? && user_id.nil?
  def days = starts_on..ends_on
  def days_text
    return starts_on.strftime("%B %-d") if starts_on == ends_on

    "#{starts_on.strftime('%B %-d')} to #{ends_on.strftime(ends_on.month == starts_on.month ? '%-d' : '%B %-d')}"
  end

  # What applying it would change, without changing anything. Nil for an incident, which is judged per person in jobs.
  def preview
    return if incident?

    excuse? ? replay(adding: self).plan : state_plan
  end

  # Saves it and changes the streak to match. An incident judges everyone it touches in the background.
  def apply!
    transaction do
      save!
      next RejudgeStreaksJob.perform_later(self, days.first.iso8601, days.last.iso8601) if incident?

      user.lock!
      update!(effect: excuse? ? replay.then { it.apply!(it.plan) } : apply_state!(state_plan))
    end
    StreakAdjustedJob.perform_later(self) if notify? && user
    true
  rescue ActiveRecord::RecordInvalid
    false
  end

  def undo_preview
    return if incident?

    excuse? ? replay(removing: self).plan : (undo_error || undo_state_plan)
  end

  # What stands in the way of undoing it, if anything.
  def undo_error
    return "Already undone." if discarded?
    return if excuse?

    if kind == "freezes"
      "They have spent #{freezes - user.streak_freezes} of these freezes already." if freezes > user.streak_freezes
    elsif user.streak_weeks.where("created_at > ?", created_at).exists?
      "A week has closed since, so the values before it are out of date. Set them again instead."
    end
  end

  def undo!(admin)
    if (error = undo_error)
      errors.add(:base, error)
      return false
    end

    transaction do
      update!(discarded_at: Time.current, undone_by: admin)
      next RejudgeStreaksJob.perform_later(self, days.first.iso8601, days.last.iso8601) if incident?

      user.lock!
      excuse? ? replay.run! : apply_state!(undo_state_plan)
    end
    true
  end

  private

  def replay(adding: nil, removing: nil)
    StreakReplay.new(user, changed: days, excused: StreakAdjustment.excused_days(user, adding:, removing:), reprice:)
  end

  # Freezes and set change the person from now on, repricing journals saved since the last week closed (or the
  # multiplier was set) when the multiplier changes.
  def state_plan
    multiplier = kind == "set" ? self.multiplier.to_d : user.xp_multiplier
    freezes = kind == "set" ? self.freezes : user.streak_freezes + self.freezes.to_i
    plan_to(multiplier, freezes)
  end

  # Back to the multiplier it replaced (a set) and the freezes less what it gave.
  def undo_state_plan
    multiplier = kind == "set" ? effect["multiplier"].first.to_d : user.xp_multiplier
    plan_to(multiplier, user.streak_freezes - (effect["freezes"].last - effect["freezes"].first))
  end

  def plan_to(multiplier, freezes)
    StreakReplay::Plan.new(changes: [], multiplier: [ user.xp_multiplier, multiplier ], freezes: [ user.streak_freezes, freezes ],
                           reprices: reprices_to(multiplier), bonuses: [], open_days: [])
  end

  def reprices_to(multiplier)
    return [] if !reprice || multiplier == user.xp_multiplier

    since = [ user.streak_weeks.maximum(:created_at), *user.streak_adjustments.where(kind: "set").where.not(id: id).pluck(:created_at) ].compact.max
    entries = user.xp_entries.journals.where(multiplier: user.xp_multiplier)
    entries = entries.where(created_at: since..) if since
    entries = entries.to_a
    minutes = Journal.where(id: entries.map(&:source_id)).pluck(:id, :duration_minutes).to_h
    entries.filter_map { StreakReplay::Reprice.new(it, multiplier, XpEntry.journal_xp(minutes[it.source_id], multiplier)) if minutes[it.source_id] }
  end

  def apply_state!(plan) = StreakReplay.new(user, changed: []).apply!(plan)

  def excuse_days
    return errors.add(:starts_on, "is required") if starts_on.nil? || ends_on.nil?
    return errors.add(:ends_on, "must be on or after the first day") if ends_on < starts_on
    return errors.add(:ends_on, "must be within #{MAX_EXCUSE_DAYS} days of the first") if (ends_on - starts_on).to_i >= MAX_EXCUSE_DAYS

    taken = StreakAdjustment.kept.excuses.covering(days).where.not(id: id)
    taken = user_id ? taken.concerning(user) : taken.incidents
    overlap = taken.first or return
    errors.add(:base, "#{overlap.days_text} #{overlap.incident? ? 'is already excused for everyone' : 'is already excused'}: #{overlap.reason}")
  end

  def freezes_given
    return errors.add(:freezes, "must be a whole number other than zero") unless freezes.is_a?(Integer) && freezes.nonzero?

    total = user.streak_freezes + freezes
    errors.add(:freezes, "would leave #{total}, which must be between 0 and #{MAX_FREEZES}") unless total.between?(0, MAX_FREEZES)
  end

  def state_set
    errors.add(:multiplier, "must be one of #{Team::Sami.multipliers.join(', ')}") unless Team::Sami.multipliers.include?(multiplier&.to_d)
    errors.add(:freezes, "must be between 0 and #{MAX_FREEZES}") unless freezes.is_a?(Integer) && freezes.between?(0, MAX_FREEZES)
    if user && multiplier && multiplier.to_d != user.xp_multiplier && user.pet != "sami"
      errors.add(:multiplier, "only counts on Team Sami; #{user.display_name} is on Team #{user.pet&.capitalize || 'nothing'}")
    end
  end
end
