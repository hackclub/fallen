# frozen_string_literal: true

# How a pet grows with its person's XP: an egg until their first journal, then stages 1 to 4. The final stage also
# needs a finished project approved by staff (Project#approved?). Numbers are the program's, see program/the-plan.md.
module Evolution
  # XP needed to reach each stage, 1 to 4.
  STAGE_XP = [ 0, 200, 500, 1000 ].freeze
  FINAL_STAGE = STAGE_XP.size

  module_function

  # The block says whether a project is approved; it is only asked once the XP for the final stage is there.
  def stage(xp)
    stage = STAGE_XP.count { |needed| xp >= needed }
    stage == FINAL_STAGE && !yield ? FINAL_STAGE - 1 : stage
  end

  # XP for the stage after this much, or nil once the final stage's XP is reached.
  def next_stage_xp(xp) = STAGE_XP.find { |needed| needed > xp }

  # How far along the current stage is, 0 to 1.
  def progress(xp)
    reached = STAGE_XP.select { |needed| needed <= xp }.max
    (next_xp = next_stage_xp(xp)) ? (xp - reached).fdiv(next_xp - reached) : 1.0
  end
end
