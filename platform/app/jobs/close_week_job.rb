# Has Team Sami judge the week that just ended (config/recurring.yml, Monday noon UTC, after Sunday has ended everywhere).
# Takes a day in the week to settle for running again by hand.
class CloseWeekJob < ApplicationJob
  queue_as :background

  def perform(day = nil)
    Team.close_week(day ? Week.of(day) : Week.previous)
  end
end
