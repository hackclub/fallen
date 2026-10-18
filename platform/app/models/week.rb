# frozen_string_literal: true

# Seven days on a person's own calendar (XpEntry#day), so a late night counts for the day it felt like. Usually
# Monday to Sunday (`Week.of`), which CloseWeekJob settles on the Monday after, once Sunday has ended everywhere;
# Team Lulu's start on each person's first journal (Team::Lulu#week).
Week = Data.define(:start) do
  def self.of(day) = new(start: day.beginning_of_week)

  # The last week that has ended, for the day the clock says.
  def self.previous(today = Date.current) = of(today - 7)

  def finish = start + 6
  def days = start..finish
  def to_s = "week of #{start.to_fs(:long)}"
end
