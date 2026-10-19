# frozen_string_literal: true

# Whether someone can trade their pet, and so their team, for the other one. Free up to their first journal; after
# that once a week, the weeks counted from the weekday of their first journal like Team Lulu's. Deleted journals
# count for neither.
class PetSwitch
  FREE_JOURNALS = 1

  attr_reader :user, :today

  def initialize(user, today = user.local_date)
    @user = user
    @today = today
  end

  def free? = journal_count <= FREE_JOURNALS
  def allowed? = free? || last_switch.nil? || !week.days.cover?(last_switch)

  # The day the week's switch comes back, whether or not it has been used. None while switching is free.
  def resets_on = free? ? nil : week.finish + 1

  private

  def week = Week.new(start: first_journal_day + (today - first_journal_day).to_i / 7 * 7)
  def last_switch = user.pet_switched_at && user.local_date(user.pet_switched_at)
  def journal_count = journals.first
  def first_journal_day = journals.last

  def journals
    @journals ||= user.xp_entries.kept.journals.pick(Arel.sql("COUNT(*)"), Arel.sql("MIN(day)"))
  end
end
