require "test_helper"

# The race began on Monday 19 October and the deadline is Wednesday 9 December, 52 days in all.
class QualifyingPaceTest < ActiveSupport::TestCase
  test "each team's line reaches the final stage's XP on the deadline, Sami's slower at first" do
    User::PETS.each { assert_equal Evolution::STAGE_XP.last, QualifyingPace.on_track_xp(it, QualifyingPace.deadline) }

    assert_equal 200, QualifyingPace.on_track_xp("sami", Date.new(2026, 11, 1))
    assert_equal 273, QualifyingPace.on_track_xp("lulu", Date.new(2026, 11, 1)), "with two weekly bonuses"
    assert_in_delta 1.66, QualifyingPace.hours_per_day("sami"), 0.01
  end

  test "off track is out of reach at OFF_TRACK_HOURS a day, a Sami streak starting again" do
    assert_equal 0, QualifyingPace.off_track_xp("sami", Date.new(2026, 11, 1))
    assert_equal 1000 - QualifyingPace::OFF_TRACK_HOURS * XpEntry::PER_HOUR * 3, QualifyingPace.off_track_xp("lulu", Date.new(2026, 12, 6)),
      "three days left and no bonus to come"
  end

  test "checkpoints are the race's Sundays, then the deadline" do
    assert_equal Date.new(2026, 10, 25), QualifyingPace.checkpoints.first
    assert_equal [ Date.new(2026, 12, 6), Date.new(2026, 12, 9) ], QualifyingPace.checkpoints.last(2)
    assert_equal Date.new(2026, 11, 1), QualifyingPace.checkpoint(Date.new(2026, 10, 31))
    assert_equal Date.new(2026, 12, 9), QualifyingPace.checkpoint(Date.new(2026, 12, 8))
  end

  test "a projected finish carries on at the XP of the last PACE_DAYS" do
    day = Date.new(2026, 11, 10)
    member = users(:member)
    XpEntry.delete_all
    member.update_columns(xp: 100)
    member.xp_entries.create!(kind: "grant", amount: 70, day: day - 1)
    member.xp_entries.create!(kind: "grant", amount: 30, day: day - QualifyingPace::PACE_DAYS) # too long ago

    projected = QualifyingPace.with_status(User.on_a_team, day).find(member.id).pace_projected
    assert_equal 100 + (70.0 * (QualifyingPace.deadline - day) / QualifyingPace::PACE_DAYS).round, projected
  end

  test "someone who just started is projected at their pace since their first XP, over at least MIN_PACE_DAYS" do
    day = Date.new(2026, 11, 10)
    member = users(:member)
    XpEntry.delete_all
    member.update_columns(xp: 60)
    member.xp_entries.create!(kind: "grant", amount: 60, day: day - 1)

    projected = QualifyingPace.with_status(User.on_a_team, day).find(member.id).pace_projected
    assert_equal 60 + (60.0 * (QualifyingPace.deadline - day) / QualifyingPace::MIN_PACE_DAYS).round, projected
  end

  test "sorts everyone on a team by where they stand" do
    day = Date.new(2026, 11, 10)
    users(:admin).update_columns(xp: QualifyingPace.on_track_xp("sami", day - 1))
    users(:member).update_columns(xp: QualifyingPace.off_track_xp("lulu", day - 1) - 1)
    statuses = -> { QualifyingPace.with_status(User.on_a_team, day).pluck(:display_name, :pace_status).to_h }

    assert_equal({ "Admin Person" => "on_track", "Member Person" => "off_track" }, statuses.())
    assert_equal "on_track", QualifyingPace.with_status(User.on_a_team, day).find_by!(display_name: "Admin Person").pace_status,
      "on loaded records too, for the serializer"

    users(:member).update_columns(xp: QualifyingPace.off_track_xp("lulu", day - 1))
    assert_equal "behind", statuses.()["Member Person"]

    users(:admin).update_columns(xp: Evolution::STAGE_XP.last)
    assert_equal "on_track", statuses.()["Admin Person"], "the XP without an approved project"

    projects(:admins).update_columns(approved_at: Time.current)
    assert_equal "qualified", statuses.()["Admin Person"]

    users(:member).update_columns(xp: 0)
    assert_equal "not_started", statuses.()["Member Person"]
  end

  test "history counts where everyone stood at the end of each day from the ledger" do
    day = Date.new(2026, 11, 10)
    XpEntry.delete_all
    User.update_all(xp: 0)
    member = users(:member)
    member.xp_entries.create!(kind: "grant", amount: QualifyingPace.on_track_xp(member.pet, Date.new(2026, 11, 1)), day: Date.new(2026, 11, 1))

    history = QualifyingPace.history(User.on_a_team, day)[:all][:days].index_by { it[:date] }
    assert_equal "2026-10-19", history.keys.first
    assert_equal "2026-11-09", history.keys.last
    assert_equal 0, history["2026-10-31"]["on_track"]
    assert_equal 1, history["2026-11-01"]["on_track"], "on the line that day"
    assert_equal 0, history["2026-11-09"]["on_track"], "fallen behind since"
    assert_equal 1, history["2026-11-03"][:close], "just below the line a couple of days later"
    assert_equal 0, history["2026-11-01"][:close]
    assert_equal 1, history["2026-11-01"][:bands][QualifyingPace.spread(User.none, day)[:all].index { it[:from] == 1 }], "at the line"
    assert_equal history["2026-11-01"][:bands].sum, User.on_a_team.count

    member.xp_entries.create!(kind: "grant", amount: Evolution::STAGE_XP.last, day: Date.new(2026, 11, 5))
    history = QualifyingPace.history(User.on_a_team, day)[:all][:days].index_by { it[:date] }
    assert_equal 0, history["2026-11-04"][:reached]
    assert_equal 1, history["2026-11-05"][:reached], "the XP, with or without a project"
    assert_equal 0, history["2026-11-05"]["qualified"], "no approved project"

    all_history = QualifyingPace.history(User.on_a_team, day)
    moves = all_history[:all][:moves]
    assert_equal({ up: 1, down: 0 }, moves["7d"], "behind on Nov 3, to on track with the XP since")
    assert_equal({ up: 1, down: 0 }, moves["all"])

    builders = all_history[:builders][:days].index_by { it[:date] }
    first_journal = Journal.kept.where(user: member).minimum(:created_at).in_time_zone(ProgramStats::ZONE).to_date
    assert_equal 1, builders["2026-11-09"].values_at(*QualifyingPace::STATUSES).sum, "only the member has journaled"
    assert_equal 0, builders[(first_journal - 1).iso8601]&.values_at(*QualifyingPace::STATUSES)&.sum.to_i, "not before their first journal"
    assert_equal User.on_a_team.count, history["2026-11-09"].values_at(*QualifyingPace::STATUSES).sum
  end

  test "spread sorts people into bands around their team's line" do
    day = Date.new(2026, 11, 10)
    users(:admin).update_columns(xp: 0)
    users(:member).update_columns(xp: QualifyingPace.on_track_xp("lulu", day - 1) * 1.2)

    bands = QualifyingPace.spread(User.on_a_team, day)[:all]
    assert_equal({ from: nil, to: 0, count: 1 }, bands.first)
    assert_equal 1, bands.find { it[:from] == 1 }[:count]
    assert_nil bands.last[:to]
    assert_equal bands.index { it[:from] == 1 }, QualifyingPace.band(users(:member).xp, QualifyingPace.on_track_xp("lulu", day - 1)),
      "the same bands as the history's"
    assert_equal 0, QualifyingPace.band(0, 100)
  end
end
