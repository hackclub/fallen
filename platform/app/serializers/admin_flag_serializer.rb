# frozen_string_literal: true

# Admin-only. A feature flag (FeatureFlag) on /admin/flags. `users:` maps actor public_ids to the users they name.
class AdminFlagSerializer < ApplicationSerializer
  typelize key: :string, state: "'on' | 'off' | 'conditional'", everyone: :boolean, groups: "string[]",
    actors: "{ id: string; name: string | null; avatar: string | null }[]", percentage_of_actors: :number, percentage_of_time: :number, expression: :boolean,
    summary: :string

  attributes :key, :groups, :percentage_of_actors, :percentage_of_time
  attribute(:state) { |flag| flag.state.to_s }
  attribute(:everyone, &:everyone?)
  attribute(:summary, &:summary)
  attribute(:expression) { |flag| flag.gates.expression.present? }
  attribute(:actors) do |flag|
    flag.actors.map do |id|
      user = params[:users]&.[](id)
      { id:, name: user&.display_name, avatar: user&.avatar_url }
    end
  end
end
