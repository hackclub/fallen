# frozen_string_literal: true

module Mcp
  module Tools
    # /admin/projects (Admin::ProjectsController).
    module ProjectTools
      def self.tools = Tools.tools_in(self)

      def self.row(project, totals)
        { id: project.public_id, title: project.title, owner: Compact.person(project.user), approved: project.approved_at.present?,
          deleted: project.discarded?, journals: totals[:counts].fetch(project.id, 0), minutes: totals[:totals].fetch(project.id, 0),
          updatedAt: Compact.time(project.updated_at) }
      end

      class ListProjects < Mcp::Tool
        description "List projects, most recently updated first, 25 to a page. `query` matches the title or the owner's name or email."
        arguments({ query: { type: "string" }, include_deleted: { type: "boolean" }, **Compact.page_arguments })
        reads!

        def self.run(ctx, query: nil, include_deleted: false, page: nil, per: nil)
          ctx.authorize!([ :admin, Project ], :index?)
          scope = ctx.scope([ :admin, Project ]).includes(:user)
          scope = scope.kept unless include_deleted
          if query.present?
            pattern = "%#{Project.sanitize_sql_like(query)}%"
            scope = scope.joins(:user).where("projects.title ILIKE :q OR users.display_name ILIKE :q OR users.email ILIKE :q", q: pattern)
          end
          Compact.paginate(scope.order(updated_at: :desc), page:, per:) do |projects|
            totals = Project.journal_totals(projects)
            projects.map { ProjectTools.row(it, totals) }
          end
        end
      end

      class GetProject < Mcp::Tool
        description "One project as /admin/projects/:id shows it: the team and a page of journals, newest first. Journal " \
                    "bodies are clipped to 300 characters. `hoursSelfClaimed` means its hours go over what was tracked."
        arguments({ id: { type: "string", description: "A public id, prj_…" }, **Compact.page_arguments }, required: %w[id])
        reads!

        def self.run(ctx, id:, page: nil, per: nil)
          project = Project.includes(:user, memberships: :user).find_by_public_id!(id)
          ctx.authorize!([ :admin, project ], :show?)
          ctx.subject!(project)
          journals = project.journals.kept
          totals = Project.journal_totals([ project ])
          {
            project: ProjectTools.row(project, totals).merge(
              description: Compact.clip(project.description), repoUrl: project.repo_url, demoUrl: project.demo_url,
              slackUrl: project.slack_url, team: project.teammates.map { Compact.person(it) }, missingHours: journals.needing_hours.count
            ),
            journals: Compact.paginate(journals.newest_first.includes(:user, :lapse_timelapses, :images_attachments), page:, per:) do |rows|
              rows.map do |journal|
                { id: journal.public_id, author: Compact.person(journal.user), body: Compact.clip(journal.body), minutes: journal.duration_minutes,
                  trackedMinutes: journal.tracked_minutes, hoursSelfClaimed: journal.hours_self_claimed, images: journal.images_attachments.length,
                  timelapses: journal.lapse_timelapses.length, source: journal.source, createdAt: Compact.time(journal.created_at) }
              end
            end
          }
        end
      end

      class SetProjectApproved < Mcp::Tool
        description "Approve a finished project, or take its approval back, as the button on /admin/projects/:id does."
        arguments({ id: { type: "string" }, approved: { type: "boolean" } }, required: %w[id approved])
        writes! idempotent: true

        def self.run(ctx, id:, approved:)
          project = Project.find_by_public_id!(id)
          ctx.authorize!([ :admin, project ], :update?)
          ctx.subject!(project)
          project.update!(approved:)
          { id: project.public_id, approved: project.approved? }
        end
      end
    end
  end
end
