# Judges one person's streak again for an incident's days (RejudgeStreaksJob), and counts what it changed on the
# incident while it stands.
class RejudgeStreakJob < ApplicationJob
  queue_as :background

  def perform(user, adjustment, from, to)
    user.transaction do
      effect = StreakReplay.new(user, changed: Date.parse(from)..Date.parse(to), reprice: adjustment.reprice).run!
      tally(adjustment, effect) if effect && !adjustment.discarded?
    end
  end

  private

  TALLY = %w[people restored journals bonuses xp].map { "'#{it}', COALESCE((effect->>'#{it}')::int, 0) + ?" }.join(", ").freeze

  # Added in one statement, as these jobs run side by side.
  def tally(adjustment, effect)
    counts = [ 1, *effect.values_at("restored", "journals", "bonuses", "xp") ]
    StreakAdjustment.where(id: adjustment.id).update_all([ "effect = effect || jsonb_build_object(#{TALLY})", *counts ])
  end
end
