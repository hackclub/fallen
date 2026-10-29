# Pays the team race's win for the week starting `start` (Team.reward_winners), from the button on /admin/teams.
# A week is paid once, so pressing twice pays once.
class TeamWinJob < ApplicationJob
  queue_as :default

  def perform(start)
    Team.reward_winners(Week.new(start: start))
  end
end
