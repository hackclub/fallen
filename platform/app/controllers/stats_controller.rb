# The program's numbers (ProgramStats) for anyone. Each panel is cached for a few minutes, since anyone can ask.
class StatsController < ApplicationController
  allow_unauthenticated_access only: :show # Public page
  allow_trial_access only: :show # Public page
  skip_after_action :verify_authorized # Program-wide aggregates, no records
  skip_after_action :verify_policy_scoped # No index action (Rails raises on `only: :index` otherwise)

  CACHE_FOR = 5.minutes

  def show
    stats = ProgramStats.new(range: params[:range])
    panel = ->(key) { InertiaRails.defer(group: key.to_s) { Rails.cache.fetch([ "program_stats", stats.range, key ], expires_in: CACHE_FOR) { stats.public_send(key) } } }

    render inertia: "Stats/Show", props: {
      range: stats.range,
      ranges: ProgramStats::RANGES.keys,
      **%i[active daily funnel sources writing].index_with(&panel)
    }
  end
end
