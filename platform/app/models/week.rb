# frozen_string_literal: true

# Seven days on a person's own calendar (XpEntry#day), so a late night counts for the day it felt like. Usually
# Monday to Sunday (`Week.of`), which CloseWeekJob settles on the Monday after, once Sunday has ended everywhere;
# Team Lulu's start on each person's first journal (Team::Lulu#week). The team race runs on one clock for everyone
# instead: Monday to Sunday anywhere on Earth (RACE_ZONE), from `starts_at` to `ends_at`, counted by when XP was made.
# Its last week ends early, on TeamRace::FINISH (`race_finish`).
Week = Data.define(:start) do
  # UTC-12, the last time zone, where Sunday ends latest. Postgres and tzinfo both read it as UTC-12.
  const_set(:RACE_ZONE, "Etc/GMT+12")

  def self.of(day) = new(start: day.beginning_of_week)

  # The last week that has ended, for the day the clock says.
  def self.previous(today = Date.current) = of(today - 7)

  # The race's week running at `now`: until Sunday has ended everywhere, the one before Monday. Its last week once the
  # race is over.
  def self.racing(now = Time.current) = of([ now.in_time_zone(self::RACE_ZONE).to_date, TeamRace::FINISH ].min)

  def finish = start + 6

  # The race's last day in the week: Sunday, or the race's last day if that comes first. Its win is paid on this day.
  def race_finish = [ finish, TeamRace::FINISH ].min

  # Monday has begun everywhere by noon UTC, and Sunday has ended everywhere by noon UTC on the Monday after.
  def starts_at = start.in_time_zone(Week::RACE_ZONE)
  def ends_at = (race_finish + 1).in_time_zone(Week::RACE_ZONE)
  def race_times = starts_at...ends_at
  def over?(now = Time.current) = now >= ends_at
  def days = start..finish
  def to_s = "week of #{start.to_fs(:long)}"
end
