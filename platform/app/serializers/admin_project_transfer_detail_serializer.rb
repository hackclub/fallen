# frozen_string_literal: true

# Admin-only. One transfer on /admin/transfers/:id: what the other program shows, and what the reviewer needs to
# decide it (ProjectTransfer#approve).
class AdminProjectTransferDetailSerializer < AdminProjectTransferSerializer
  typelize airtable_url: :string, suggested_minutes: [ :number, nullable: true ], suggested_xp: :number,
           named_project_id: [ :string, nullable: true ], slack_dm_url: [ :string, nullable: true ], fetched_at: [ :string, nullable: true ],
           draft_saved_at: [ :string, nullable: true ],
           project: "{ id: string; title: string } | null",
           user_projects: "Array<{ id: string; title: string; owner: string | null }>",
           snapshot: "{ title: string; description: string | null; repo_url: string | null; demo_url: string | null; hardware: boolean; " \
                     "owner: { name: string | null; avatar: string | null; slack_id: string | null }; entry_count: number; minutes: number; " \
                     "entries: Array<{ ref: string; at: string | null; minutes: number; body: string; images: string[] }> } | null"
  attributes :fallen_project_url, :note, :message, :draft_saved_at, :fetched_at, :snapshot, :lapse_seconds
  attribute(:airtable_url, &:airtable_url)
  attribute(:suggested_minutes, &:suggested_minutes)
  attribute(:suggested_xp) { |transfer| ProjectTransfer.suggested_xp(transfer.suggested_minutes) }
  # Their linked Slack, or else the one the project was written from in the other program.
  attribute(:slack_dm_url) do |transfer|
    (transfer.user&.slack_id.presence || transfer.snapshot&.dig("owner", "slack_id").presence)&.then { SlackMessaging.dm_url(it) }
  end
  attribute(:named_project_id) { |transfer| transfer.named_project&.public_id }
  attribute(:project) { |transfer| transfer.project && { id: transfer.project.public_id, title: transfer.project.title } }
  # Their own projects and the ones they are a member of; `owner` names whoever owns one of the latter.
  attribute(:user_projects) do |transfer|
    next [] unless transfer.user

    projects = Project.teamed_with(transfer.user).kept.recent.to_a
    others = projects.map(&:user_id).uniq - [ transfer.user_id ]
    owners = others.any? ? User.where(id: others).pluck(:id, :display_name).to_h : {}
    projects.map { |project| { id: project.public_id, title: project.title, owner: owners[project.user_id] } }
  end
end
