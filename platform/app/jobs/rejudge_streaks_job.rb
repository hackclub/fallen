# Judges again everyone an incident's days touch (StreakAdjustment), when it's made or undone: Team Sami members with
# a judged week holding the days, and Team Lulu members who had journaled by then. One RejudgeStreakJob each, so a
# restart halfway leaves nobody judged twice; judging again changes nothing the second time.
class RejudgeStreaksJob < ApplicationJob
  queue_as :background

  def perform(adjustment, from, to)
    days = Date.parse(from)..Date.parse(to)
    sami = StreakWeek.where(start: (days.first - 6)..days.last).select(:user_id)
    lulu = User.on_a_team.where(pet: "lulu").where(id: XpEntry.kept.journals.where(day: ..days.last).select(:user_id))
    users = User.where(id: sami).or(User.where(id: lulu.select(:id)))
    users.select(:id).find_in_batches { |batch| ActiveJob.perform_all_later(batch.map { RejudgeStreakJob.new(it, adjustment, from, to) }) }
  end
end
