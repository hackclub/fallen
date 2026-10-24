# frozen_string_literal: true

module Mcp
  module Tools
    # /admin/flags (Admin::FlagsController): Flipper features through FeatureFlag. Flipper keeps no history of its own,
    # so the action log is the record of a change made here.
    module FlagTools
      def self.tools = Tools.tools_in(self)

      def self.row(flag)
        { key: flag.key, state: flag.state.to_s, summary: flag.summary, everyone: flag.everyone?, groups: flag.groups, actors: flag.actors,
          percentageOfActors: flag.percentage_of_actors, percentageOfTime: flag.percentage_of_time }
      end

      def self.find(ctx, key, query)
        ctx.authorize!([ :admin, :flag ], query)
        FeatureFlag.find!(key)
      end

      class ListFlags < Mcp::Tool
        description "Every feature flag and who has it. Actors are user public ids."
        arguments
        reads!

        def self.run(ctx)
          ctx.authorize!([ :admin, :flag ], :index?)
          { flags: FeatureFlag.all.map { FlagTools.row(it) }, groups: FeatureFlag::GROUPS.transform_values { it[:description] } }
        end
      end

      class CreateFlag < Mcp::Tool
        description "Make a feature flag. It starts off for everyone."
        arguments({ key: { type: "string", description: "Lowercase letters, numbers and underscores, starting with a letter" } }, required: %w[key])
        writes!

        def self.run(ctx, key:)
          ctx.authorize!([ :admin, :flag ], :create?)
          flag = FeatureFlag.new(key.strip)
          ctx.refuse!(flag.errors.full_messages.to_sentence) unless flag.valid?(:create)
          FlagTools.row(flag.create!)
        end
      end

      class UpdateFlag < Mcp::Tool
        description "Change who has a flag, as /admin/flags/:key does. Keys left out stay as they are. Changing " \
                    "`everyone` clears every other rule, as Flipper does, and ignores the rest of the call. `groups` " \
                    "and `actors` replace the current lists; actors are user public ids (usr_…)."
        arguments({ key: { type: "string" }, everyone: { type: "boolean" },
                    groups: { type: "array", items: { type: "string", enum: FeatureFlag::GROUPS.keys.map(&:to_s) } },
                    actors: { type: "array", items: { type: "string" }, maxItems: 500 },
                    percentage_of_actors: { type: "integer", minimum: 0, maximum: 100 },
                    percentage_of_time: { type: "integer", minimum: 0, maximum: 100 } }, required: %w[key])
        writes! idempotent: true

        def self.run(ctx, key:, **changes)
          flag = FlagTools.find(ctx, key, :update?)
          ctx.refuse!("Say what to change.") if changes.empty?
          FlagTools.row(flag.update!(**changes))
        end
      end

      class DeleteFlag < Mcp::Tool
        description "Delete a feature flag and every rule on it. Code that still checks it will see it off."
        arguments({ key: { type: "string" } }, required: %w[key])
        writes! destructive: true

        def self.run(ctx, key:)
          flag = FlagTools.find(ctx, key, :destroy?)
          before = FlagTools.row(flag)
          flag.destroy!
          { deleted: before }
        end
      end
    end
  end
end
