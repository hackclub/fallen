require "test_helper"

# Streak restores: excused days, freezes and set values (StreakAdjustment), and judging weeks again (StreakReplay).
class StreakTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  WEEK = Week.of(Date.new(2026, 9, 7))

  test "the weekly close keeps the state before each week and counts excused days as journaled" do
    user = sami
    journal_on(user, WEEK.days.to_a - [ WEEK.start + 2 ])
    excuse(user, WEEK.start + 2)
    2.times { close(user, WEEK) }

    week = user.streak_weeks.sole
    assert_equal [ 1.0, 3, 0, 1, 1.15, 3 ], [ week.multiplier_before, week.freezes_before, week.missed, week.excused, week.multiplier, week.freezes ]
    assert_equal "kept", week.outcome
    assert_equal [ 1.15, 3 ], [ user.reload.xp_multiplier, user.streak_freezes ]
  end

  test "excusing a broken week's days restores it, carries through the weeks after and reprices their journals" do
    user = broken_sami
    assert_equal [ 1.15, 0 ], [ user.xp_multiplier, user.streak_freezes ]
    xp = user.xp

    adjustment = excuse(user, WEEK.start + 2, WEEK.start + 4, apply: false)
    plan = adjustment.preview
    assert_equal [ 1.15, 1.3 ], plan.multiplier.map(&:to_f)
    assert_equal [ 0, 1 ], plan.freezes
    assert_equal 1, plan.restored
    assert_equal 7 + 7, plan.xp, "week 2's journals go from 8 to 9 XP, week 3's from 9 to 10"
    assert_equal xp, user.reload.xp, "a preview changes nothing"

    travel_to(WEEK.start + 23) { assert adjustment.apply! }
    first, second = user.streak_weeks.order(:start)
    assert_equal [ 2, 3, 1.15, 1 ], [ first.missed, first.excused, first.multiplier, first.freezes ]
    assert_equal "frozen", first.outcome
    assert_equal [ 1.15, 1, 1.3, 1 ], [ second.multiplier_before, second.freezes_before, second.multiplier, second.freezes ]
    assert_equal [ 1.3, 1 ], [ user.reload.xp_multiplier, user.streak_freezes ]
    assert_equal xp + 14, user.xp
    assert_equal({ "multiplier" => [ 1.15, 1.3 ], "freezes" => [ 0, 1 ], "weeks" => 2, "restored" => 1, "broken" => 0, "journals" => 14, "bonuses" => 0, "xp" => 14 },
                 adjustment.reload.effect)

    travel_to(WEEK.start + 23) { assert adjustment.undo!(users(:admin)) }
    assert_equal [ 1.15, 0 ], [ user.reload.xp_multiplier, user.streak_freezes ]
    assert_equal xp, user.xp
    assert_equal "broken", user.streak_weeks.order(:start).first.outcome
    assert_equal users(:admin), adjustment.reload.undone_by
  end

  test "a pet switch after the break keeps its multiplier, but journals before it are repriced and freezes come back" do
    user = sami
    journal_on(user, [ WEEK.start, WEEK.start + 1 ])
    close(user, WEEK)
    journal_on(user, [ WEEK.start + 7 ])
    travel_to((WEEK.start + 9).in_time_zone(user.timezone).change(hour: 18)) { user.update!(pet: "lulu") }
    journal_on(user, [ WEEK.start + 10 ])
    xp = user.reload.xp

    adjustment = excuse(user, WEEK.start + 2, WEEK.start + 4)
    assert_equal [ 1.0, 1 ], [ user.reload.xp_multiplier, user.streak_freezes ], "Team Lulu has no multiplier"
    assert_equal [ 1.15, 1.0 ], user.xp_entries.journals.where(day: [ WEEK.start + 7, WEEK.start + 10 ]).order(:day).pluck(:multiplier)
    assert_equal xp + 1, user.xp
    assert_equal 0, adjustment.effect["bonuses"], "no Lulu bonus for a week spent on Team Sami"
  end

  test "excusing days pays Team Lulu's bonus for an ended week, and undoing takes it back" do
    user = users(:newcomer).tap { it.update_columns(pet: "lulu") }
    first = Date.new(2026, 9, 10)
    journal_on(user, (first..first + 3).to_a)
    travel_to(first + 9) { user.team.settle(first + 9) }
    assert_not user.xp_entries.exists?(kind: "weekly_bonus")

    adjustment = travel_to(first + 9) { excuse(user, first + 5) }
    assert_equal [ Team::Lulu::WEEKLY_BONUS ], user.xp_entries.kept.where(kind: "weekly_bonus").pluck(:amount)
    assert_equal 1, adjustment.effect["bonuses"]

    travel_to(first + 9) { adjustment.undo!(users(:admin)) }
    assert_not user.xp_entries.kept.exists?(kind: "weekly_bonus")
    travel_to(first + 9) { excuse(user, first + 4) }
    assert_equal 1, user.xp_entries.kept.where(kind: "weekly_bonus").count, "paid again on the same row"
  end

  test "an excuse in a week not judged yet counts when it closes" do
    user = sami
    journal_on(user, WEEK.days.to_a - [ WEEK.finish ])
    plan = excuse(user, WEEK.finish, apply: false).preview
    assert_equal [ WEEK.finish ], plan.open_days
    assert_not plan.changed?
  end

  test "freezes are given from now on and can be taken back while unspent" do
    user = sami
    given = adjust(user, kind: "freezes", freezes: 2)
    assert_equal 5, user.reload.streak_freezes
    assert_not adjust(user, kind: "freezes", freezes: -6, apply: false).valid?

    user.update!(streak_freezes: 1)
    assert_not given.undo!(users(:admin))
    assert_match "spent 1 of these", given.errors.full_messages.sole
    user.update!(streak_freezes: 5)
    assert given.undo!(users(:admin))
    assert_equal 3, user.reload.streak_freezes
  end

  test "setting the multiplier reprices journals since the last close, only on Team Sami, and undoes until a week closes" do
    user = broken_sami
    xp = user.xp
    set = travel_to(WEEK.start + 23) { adjust(user, kind: "set", multiplier: 1.45, freezes: 2) }
    assert_equal [ 1.45, 2 ], [ user.reload.xp_multiplier, user.streak_freezes ]
    assert_equal xp + 7 * 3, user.xp, "week 3's journals go from 9 to 12 XP"
    assert_equal [ 1.15, 1.45 ], set.effect["multiplier"]

    travel_to(WEEK.start + 23) { assert set.undo!(users(:admin)) }
    assert_equal [ 1.15, 0, xp ], [ user.reload.xp_multiplier, user.streak_freezes, user.xp ]

    assert_not adjust(users(:member), kind: "set", multiplier: 1.3, freezes: 3, apply: false).valid?
    assert_not adjust(user, kind: "set", multiplier: 1.2, freezes: 3, apply: false).valid?
    set = travel_to(WEEK.start + 23) { adjust(user, kind: "set", multiplier: 1.3, freezes: 3) }
    close(user, Week.of(WEEK.start + 21))
    assert_match "A week has closed", set.undo_error
  end

  test "an incident excuses everyone, judged one person per job, and is counted on it" do
    user = broken_sami
    other = sami(users(:banned).tap { it.update_columns(is_banned: false) })
    journal_on(other, WEEK.days.to_a - [ WEEK.start + 3 ])
    close(other, WEEK)

    incident = StreakAdjustment.new(kind: "excuse", admin: users(:admin), starts_on: WEEK.start + 2, ends_on: WEEK.start + 4, reason: "Slack was down")
    travel_to(WEEK.start + 23) do
      perform_enqueued_jobs(only: [ RejudgeStreaksJob, RejudgeStreakJob ]) { assert incident.apply! }
    end
    assert_equal [ 1.3, 1 ], [ user.reload.xp_multiplier, user.streak_freezes ]
    assert_equal [ 1.15, 3 ], [ other.reload.xp_multiplier, other.streak_freezes ], "the freeze it spent comes back"
    assert_equal({ "people" => 2, "restored" => 1, "journals" => 14, "bonuses" => 0, "xp" => 14 }, incident.reload.effect)
    assert_not StreakAdjustment.new(kind: "excuse", user: user, admin: users(:admin), starts_on: WEEK.start + 3, ends_on: WEEK.start + 3, reason: "x").valid?,
               "already excused for everyone"

    travel_to(WEEK.start + 23) do
      perform_enqueued_jobs(only: [ RejudgeStreaksJob, RejudgeStreakJob ]) { incident.undo!(users(:admin)) }
    end
    assert_equal [ 1.15, 0 ], [ user.reload.xp_multiplier, user.streak_freezes ]
  end

  test "excuses are checked" do
    user = sami
    assert_not adjust(user, kind: "excuse", starts_on: WEEK.start + 2, ends_on: WEEK.start, apply: false).valid?
    assert_not adjust(user, kind: "excuse", starts_on: WEEK.start, ends_on: WEEK.start + StreakAdjustment::MAX_EXCUSE_DAYS, apply: false).valid?
    excuse(user, WEEK.start, WEEK.start + 2)
    overlap = adjust(user, kind: "excuse", starts_on: WEEK.start + 2, ends_on: WEEK.start + 3, apply: false)
    assert_not overlap.valid?
    assert_includes overlap.errors.full_messages.sole, "is already excused"
    assert_not adjust(user, kind: "excuse", starts_on: WEEK.start + 5, ends_on: WEEK.start + 5, reason: "", apply: false).valid?
  end

  test "the person is DMed what changed with the admin's note, if asked to" do
    user = broken_sami
    user.update_columns(slack_id: "U0SAMI")
    with_fake_slack do |slack|
      perform_enqueued_jobs(only: StreakAdjustedJob) do
        travel_to(WEEK.start + 23) { excuse(user, WEEK.start + 2, WEEK.start + 4, notify: true, message: "Sorry about the outage <3") }
        excuse(user, WEEK.start + 5, notify: false)
      end
      message = slack.calls_to(:chat_postMessage).sole
      assert_equal "U0SAMI", message[:channel]
      assert_includes message[:text], "We excused September 9 to 11 for your streak"
      assert_includes message[:text], "You're on 1.30x with 1 freeze left."
      assert_includes message[:text], "That's +14 XP."
      assert_includes message[:text], "> Sorry about the outage &lt;3"
    end
  end

  private

  def sami(user = users(:newcomer)) = user.tap { it.update_columns(pet: "sami") }

  # Week 1: two journal days, so three freezes can't cover the five missed and it breaks. Week 2 every day at 1x,
  # kept. Week 3 every day at 1.15x, still open.
  def broken_sami
    user = sami
    journal_on(user, [ WEEK.start, WEEK.start + 1 ])
    close(user, WEEK)
    journal_on(user, WEEK.days.map { it + 7 })
    close(user, Week.of(WEEK.start + 7))
    journal_on(user, WEEK.days.map { it + 14 })
    user.reload
  end

  def close(user, week) = travel_to((week.finish + 1).in_time_zone("UTC").change(hour: 10)) { user.reload.team.close_week(week) }

  def excuse(user, from, to = from, apply: true, **attrs) = adjust(user, kind: "excuse", starts_on: from, ends_on: to, apply:, **attrs)

  def adjust(user, apply: true, **attrs)
    adjustment = StreakAdjustment.new(user: user, admin: users(:admin), reason: "Slack outage", **attrs)
    apply ? adjustment.tap { assert it.apply!, it.errors.full_messages.to_sentence } : adjustment
  end

  def journal_on(user, days, hours: "1h")
    project = user.projects.first || user.projects.create!(title: "Thing")
    days.each do |day|
      travel_to day.in_time_zone(user.timezone).change(hour: 12) do
        project.journals.create!(user: user, body: journal_text("on #{day}") * 2, duration: hours, images: Array.new(Journal.new(duration: hours).images_needed) { photo })
      end
    end
  end
end
