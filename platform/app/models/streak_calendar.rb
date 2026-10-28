# frozen_string_literal: true

# Someone's streak as /admin/users/:id draws it: a row for each of their team's weeks from the first journal to the
# one after this, with what each day counted as and how the week went. Team Sami's rows are Monday to Sunday and
# carry the StreakWeek judged for them; Team Lulu's start on the first journal's weekday and carry the bonus. Five
# or six queries, whatever the history.
class StreakCalendar
  # before (the first journal), journal, excused, missed, frozen (missed, covered by a freeze), today, future.
  Day = Data.define(:date, :state, :xp, :excuse_id)
  Row = Data.define(:start, :finish, :days, :status, :judged, :bonus_xp, :counted)

  attr_reader :user, :today

  def initialize(user, now: Time.current)
    @user = user
    @today = user.local_date(now)
  end

  def team = user.pet
  def first_day = journal_xp.keys.min

  def rows
    return [] if first_day.nil? || team.nil?

    starts = Enumerator.produce(first_start) { it + 7 }.take_while { it <= today + 7 }
    starts.map { row(Week.new(start: it)) }
  end

  # Team Sami's judged weeks, oldest first, including ones from before a switch to Lulu.
  def judged = @judged ||= user.streak_weeks.order(:start).to_a

  # The person's own changes and the incidents since their first journal, newest first.
  def adjustments
    @adjustments ||= StreakAdjustment.concerning(user).includes(:admin, :undone_by, :user).order(created_at: :desc).to_a.select do |adjustment|
      adjustment.user_id || first_day.nil? || adjustment.ends_on >= first_day
    end
  end

  private

  def row(week)
    judged_week = team == "sami" ? judged.find { it.start == week.start } : nil
    days = week.days.map { day(it, judged_week) }
    counted = days.count { %w[journal excused].include?(it.state) }
    Row.new(start: week.start, finish: week.finish, days:, status: status(week, judged_week, counted), judged: judged_week, bonus_xp: bonus(week)&.amount,
            counted:)
  end

  def day(date, judged_week)
    excuse = excuses.find { it.days.cover?(date) }
    state =
      if date < first_day then "before"
      elsif journal_xp.key?(date) then "journal"
      elsif excuse then "excused"
      elsif date > today then "future"
      elsif date == today then "today"
      elsif judged_week&.frozen? then "frozen"
      else "missed"
      end
    Day.new(date:, state:, xp: journal_xp[date], excuse_id: excuse&.public_id)
  end

  def status(week, judged_week, counted)
    return judged_week.outcome if judged_week
    return "open" if week.finish >= today
    return (bonus(week) ? "paid" : "unpaid") if team == "lulu"

    # A Sami week that ended and hasn't been judged: before CloseWeekJob on Monday, or not on Team Sami then.
    "unjudged"
  end

  def first_start = team == "lulu" ? user.team.week(first_day).start : first_day.beginning_of_week
  def bonus(week) = bonuses.find { it.day == week.finish }

  def journal_xp = @journal_xp ||= user.xp_entries.kept.journals.group(:day).sum(:amount)
  def bonuses = @bonuses ||= user.xp_entries.kept.where(kind: "weekly_bonus").to_a
  def excuses = @excuses ||= adjustments.select { it.excuse? && !it.discarded? }
end
