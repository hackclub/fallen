class Admin::InsightsController < Admin::ApplicationController
  skip_after_action :verify_policy_scoped # No index action (Rails raises on `only: :index` otherwise)
  skip_after_action :verify_authorized # Same reason; #show authorizes explicitly

  # One endpoint (`name`) or all of them, over a range. Every panel is its own deferred request.
  def show
    authorize [ :admin, :insights ]
    insights = Insights.new(kind: params[:kind], range: params[:range], name: params[:name])

    render inertia: "Admin/Insights/Show", props: {
      kind: insights.kind,
      range: insights.range,
      ranges: Insights::RANGES.keys,
      name: insights.name,
      summary: InertiaRails.defer(group: "summary") { insights.summary },
      series: InertiaRails.defer(group: "series") { insights.series },
      breakdown: InertiaRails.defer(group: "table") { insights.name ? [] : insights.breakdown },
      slowest: InertiaRails.defer(group: "table") { insights.slowest },
      statuses: InertiaRails.defer(group: "summary") { insights.statuses }
    }
  end
end
