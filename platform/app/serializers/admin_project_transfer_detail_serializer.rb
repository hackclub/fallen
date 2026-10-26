# frozen_string_literal: true

# Admin-only. One transfer on /admin/transfers/:id: what the other program shows, and what the reviewer needs to
# decide it (ProjectTransfer#approve).
class AdminProjectTransferDetailSerializer < AdminProjectTransferSerializer
  typelize airtable_url: :string, suggested_minutes: [ :number, nullable: true ], suggested_xp: :number,
           named_project_id: [ :string, nullable: true ], fetched_at: [ :string, nullable: true ],
           reviewer: "{ id: string; display_name: string } | null", project: "{ id: string; title: string } | null",
           user_projects: "Array<{ id: string; title: string }>",
           snapshot: "{ title: string; description: string | null; repo_url: string | null; demo_url: string | null; hardware: boolean; " \
                     "owner: { name: string | null; avatar: string | null; slack_id: string | null }; entry_count: number; minutes: number; " \
                     "entries: Array<{ ref: string; at: string | null; minutes: number; body: string; images: string[] }> } | null"
  attributes :fallen_project_url, :note, :message, :fetched_at, :snapshot
  attribute(:airtable_url, &:airtable_url)
  attribute(:suggested_minutes, &:suggested_minutes)
  attribute(:suggested_xp) { |transfer| ProjectTransfer.suggested_xp(transfer.suggested_minutes) }
  attribute(:named_project_id) { |transfer| transfer.named_project&.public_id }
  attribute(:reviewer) { |transfer| transfer.reviewer && { id: transfer.reviewer.public_id, display_name: transfer.reviewer.display_name } }
  attribute(:project) { |transfer| transfer.project && { id: transfer.project.public_id, title: transfer.project.title } }
  attribute(:user_projects) do |transfer|
    transfer.user ? transfer.user.projects.kept.recent.map { { id: it.public_id, title: it.title } } : []
  end
end
