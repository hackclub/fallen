# Streaks across everyone: the weeks that broke, newest first, to restore from; incidents, which excuse days for
# everyone; and every change admins made (StreakAdjustment).
class Admin::StreaksController < Admin::ApplicationController
  TABS = %w[broken incidents log].freeze

  def index
    tab = TABS.include?(params[:tab]) ? params[:tab] : "broken"
    authorize [ :admin, StreakAdjustment ]
    adjustments = policy_scope([ :admin, StreakAdjustment ])
    week = Date.iso8601(params[:week]) rescue nil # rubocop:disable Style/RescueModifier

    render inertia: "Admin/Streaks/Index", props: {
      tab: tab,
      week: week&.iso8601,
      weeks: InertiaRails.defer(group: "table") { StreakWeek.broken.group(:start).order(start: :desc).limit(12).count.map { |start, count| { start: start.iso8601, count: } } },
      counts: InertiaRails.defer(group: "table") { { broken: StreakWeek.broken.count, incidents: adjustments.incidents.kept.count } },
      can: { create: policy([ :admin, StreakAdjustment.new ]).create? },
      incident_preview: InertiaRails.optional { incident_preview },
      **table(tab, adjustments, week)
    }
  end

  private

  def table(tab, adjustments, week)
    case tab
    when "broken"
      weeks = StreakWeek.broken.includes(:user).order(start: :desc, id: :desc)
      deferred_table(week ? weeks.where(start: week) : weeks, AdminStreakWeekSerializer, :rows)
    when "incidents"
      deferred_table(adjustments.incidents.includes(:admin, :undone_by, :user).order(created_at: :desc), AdminStreakAdjustmentSerializer, :rows)
    else
      deferred_table(adjustments.includes(:admin, :undone_by, :user).order(created_at: :desc), AdminStreakAdjustmentSerializer, :rows)
    end
  end

  # How many judged weeks an incident's days fall in, and how many of those missed or broke, before it is made. The
  # exact count of people it changes is on the incident once their jobs run.
  def incident_preview
    adjustment = build_streak_adjustment(params.fetch(:preview, {}), user: nil).tap { it.kind = "excuse" }
    preview = streak_preview(adjustment)
    return preview if preview[:errors].any?

    weeks = StreakWeek.where(start: (adjustment.starts_on - 6)..adjustment.ends_on)
    { errors: [], plan: nil, weeks: weeks.count, missed: weeks.where("missed > 0").count, broken: weeks.broken.count,
      lulu: User.on_a_team.where(pet: "lulu").count }
  end
end
