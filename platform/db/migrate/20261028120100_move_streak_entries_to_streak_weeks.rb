# Sami's judged weeks were 0 XP `streak` entries holding only the multiplier after the week. StreakWeek keeps the
# state before it too, so a week can be judged again. Every week so far was someone's first, which starts at 1x
# with the default freezes; the last one ends at the freezes they have now.
class MoveStreakEntriesToStreakWeeks < ActiveRecord::Migration[8.1]
  def up
    safety_assured { backfill }
  end

  def down
    safety_assured do
      execute(<<~SQL)
        INSERT INTO xp_entries (user_id, kind, day, amount, multiplier, created_at, updated_at)
        SELECT user_id, 'streak', start + 6, 0, multiplier, created_at, updated_at FROM streak_weeks
      SQL
      execute("DELETE FROM streak_weeks")
    end
  end

  private

  def backfill
    rows = select_all(<<~SQL).to_a
      SELECT e.user_id, e.day, e.multiplier, e.created_at, u.streak_freezes,
        (SELECT MIN(j.day) FROM xp_entries j WHERE j.user_id = e.user_id AND j.kind = 'journal' AND j.discarded_at IS NULL) AS first_day
      FROM xp_entries e JOIN users u ON u.id = e.user_id
      WHERE e.kind = 'streak'
      ORDER BY e.user_id, e.day
    SQL
    default_freezes = 3

    rows.group_by { it["user_id"] }.each do |user_id, weeks|
      multiplier = 1.0
      freezes = default_freezes
      weeks.each_with_index do |week, index|
        finish = week["day"].to_date
        start = finish - 6
        from = [ week["first_day"]&.to_date || start, start ].max
        journaled = select_value(<<~SQL).to_i
          SELECT COUNT(DISTINCT day) FROM xp_entries
          WHERE user_id = #{Integer(user_id)} AND kind = 'journal' AND discarded_at IS NULL AND day BETWEEN #{quote(from)} AND #{quote(finish)}
        SQL
        missed = [ (finish - from).to_i + 1 - journaled, 0 ].max
        after = index == weeks.size - 1 ? week["streak_freezes"].to_i : [ freezes - missed, 0 ].max
        execute(<<~SQL)
          INSERT INTO streak_weeks (user_id, start, multiplier_before, freezes_before, missed, excused, multiplier, freezes, created_at, updated_at)
          VALUES (#{Integer(user_id)}, #{quote(start)}, #{quote(multiplier)}, #{freezes}, #{missed}, 0, #{quote(week['multiplier'])}, #{after},
                  #{quote(week['created_at'])}, #{quote(week['created_at'])})
        SQL
        multiplier = week["multiplier"].to_f
        freezes = after
      end
    end
    execute("DELETE FROM xp_entries WHERE kind = 'streak'")
  end
end
