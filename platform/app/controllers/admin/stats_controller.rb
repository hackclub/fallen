class Admin::StatsController < Admin::ApplicationController
  skip_after_action :verify_policy_scoped # No index action (Rails raises on `only: :index` otherwise)
  skip_after_action :verify_authorized # Same reason; #show authorizes explicitly

  def show
    authorize [ :admin, :stats ]
    stats = ProgramStats.new(range: params[:range])

    render inertia: "Admin/Stats/Show", props: {
      range: stats.range,
      ranges: ProgramStats::RANGES.keys,
      active: InertiaRails.defer(group: "active") { stats.active },
      daily: InertiaRails.defer(group: "daily") { stats.daily },
      funnel: InertiaRails.defer(group: "funnel") { stats.funnel }
    }
  end
end
