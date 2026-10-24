# frozen_string_literal: true

module Mcp
  module Tools
    # The read-only admin pages: the dashboard, /admin/stats and /admin/insights.
    module OpsTools
      def self.tools = Tools.tools_in(self)

      class GetDashboard < Mcp::Tool
        description "The counts on the admin dashboard: people, projects, journals, minutes logged, journals missing hours, seen today."
        arguments
        reads!

        def self.run(ctx)
          ctx.authorize!([ :admin, :stats ], :show?)
          Admin::DashboardController.stats
        end
      end

      class GetStats < Mcp::Tool
        description "What /admin/stats shows over a range: who is active, the daily series, the signup funnel and the " \
                    "AI-writing checks. Days are New York days. Ask for only the sections you need."
        arguments({ range: { type: "string", enum: ProgramStats::RANGES.keys },
                    sections: { type: "array", items: { type: "string", enum: %w[active daily funnel writing] } } })
        reads!

        def self.run(ctx, range: nil, sections: %w[active funnel writing])
          ctx.authorize!([ :admin, :stats ], :show?)
          stats = ProgramStats.new(range:)
          { range: stats.range, **sections.uniq.to_h { [ it.to_sym, stats.public_send(it) ] } }
        end
      end

      class GetInsights < Mcp::Tool
        description "Request or job timings from /admin/insights: totals, status classes, the 20 endpoints or jobs that " \
                    "cost the most time, and the slowest single runs. `name` narrows it to one endpoint or job."
        arguments({ kind: { type: "string", enum: Insights::KINDS }, range: { type: "string", enum: Insights::RANGES.keys },
                    name: { type: "string" } }, required: %w[kind])
        reads!

        def self.run(ctx, kind:, range: nil, name: nil)
          ctx.authorize!([ :admin, :insights ], :show?)
          insights = Insights.new(kind:, range:, name: name.presence)
          { kind: insights.kind, range: insights.range, name: insights.name, summary: insights.summary, statuses: insights.statuses,
            breakdown: insights.name ? [] : insights.breakdown.first(20), slowest: insights.slowest.first(10) }
        end
      end
    end
  end
end
