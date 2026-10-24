# frozen_string_literal: true

module Mcp
  module Tools
    # /admin/users (Admin::UsersController). Impersonation has no tool: it is a browser session, not an action.
    module UserTools
      def self.tools = Tools.tools_in(self)

      def self.row(user)
        { id: user.public_id, name: user.display_name, slackId: user.slack_id, roles: user.roles, banned: user.is_banned,
          deleted: user.discarded?, trial: user.trial?, createdAt: Compact.time(user.created_at), lastSeenAt: Compact.time(user.last_seen_at) }
      end

      class ListUsers < Mcp::Tool
        description "List people, newest first, 25 to a page. `query` searches name, email and Slack id. Rows leave out " \
                    "email; get_user has it."
        arguments({ query: { type: "string" }, include_deleted: { type: "boolean" }, **Compact.page_arguments })
        reads!

        def self.run(ctx, query: nil, include_deleted: false, page: nil, per: nil)
          ctx.authorize!(User, :index?)
          scope = ctx.scope(User)
          scope = scope.kept unless include_deleted
          scope = scope.search(query) if query.present?
          Compact.paginate(scope.reorder(created_at: :desc), page:, per:) { |users| users.map { UserTools.row(it) } }
        end
      end

      class GetUser < Mcp::Tool
        description "One person as /admin/users/:id shows them, with their projects."
        arguments({ id: { type: "string", description: "A public id, usr_…" } }, required: %w[id])
        reads!

        def self.run(ctx, id:)
          user = ctx.authorize!(User.find_by_public_id!(id), :show?)
          ctx.subject!(user)
          projects = Project.kept.involving(user).recent.to_a
          totals = Project.journal_totals(projects)
          {
            user: UserTools.row(user).merge(
              email: user.email, hcaId: user.hca_id, timezone: user.timezone, verificationStatus: user.verification_status,
              isAdult: user.is_adult, xp: user.xp, xpMultiplier: user.xp_multiplier.to_f, pet: user.pet,
              streakFreezes: user.streak_freezes, softSignup: user.soft_signup, signupSource: user.signup_source
            ),
            projects: projects.map do |project|
              { id: project.public_id, title: project.title, owner: project.user_id == user.id, approved: project.approved_at.present?,
                journals: totals[:counts].fetch(project.id, 0), minutes: totals[:totals].fetch(project.id, 0) }
            end
          }
        end
      end

      class UpdateUser < Mcp::Tool
        description "Set a person's roles or ban them, as the form on /admin/users/:id does. Roles are any of " \
                    "#{User::ROLES.join(', ')}. You can't change yourself. A banned person sees the ban page instead of the site."
        arguments({ id: { type: "string" }, roles: { type: "array", items: { type: "string", enum: User::ROLES }, minItems: 1 },
                    is_banned: { type: "boolean" } }, required: %w[id])
        writes! destructive: true, idempotent: true

        def self.run(ctx, id:, roles: nil, is_banned: nil)
          user = ctx.authorize!(User.find_by_public_id!(id), :update?)
          ctx.subject!(user)
          attrs = { roles:, is_banned: }.compact
          ctx.refuse!("Give roles or is_banned.") if attrs.empty?
          user.update!(attrs)
          { user: UserTools.row(user) }
        end
      end
    end
  end
end
