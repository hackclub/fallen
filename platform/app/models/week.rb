# frozen_string_literal: true

# Monday to Sunday on a person's own calendar (XpEntry#day), so a late night counts for the day it felt like.
# CloseWeekJob settles a week on the Monday after it, once Sunday has ended everywhere.
Week = Data.define(:start) do
  def self.of(day) = new(start: day.beginning_of_week)

  # The last week that has ended, for the day the clock says.
  def self.previous(today = Date.current) = of(today - 7)

  def finish = start + 6
  def days = start..finish
  def to_s = "week of #{start.to_fs(:long)}"
end
