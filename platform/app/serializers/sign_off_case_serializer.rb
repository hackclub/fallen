# frozen_string_literal: true

# The decision in front of an admin on the sign-off desk: the reviewer's call next to everything it rests on, the
# copy check included. Admins only. `params[:journals]` as AdminSignOffSerializer.
class SignOffCaseSerializer < AdminSignOffSerializer
  CopyMatch = "{ repo: string; url: string; containment: number; mode: 'pcb' | 'cad'; blocks: { label: string; strength: 'near-conclusive' | 'strong' | 'moderate' | 'weak'; conclusive: boolean; containment: number; shared: number; meaning: string }[] }"
  typelize cut: [ :number, nullable: true ], note: [ :string, nullable: true ], ai_usage: [ :string, nullable: true ],
    made_with: "string[]", repo_url: :string, used_ai: :boolean, returns: :number, copy_check_holds: :boolean,
    project: "{ id: string; title: string; description: string | null; slack_url: string | null; team: { id: string; name: string; avatar: string }[] }",
    screenshots: "string[]",
    parts: "{ name: string; quantity: number; total_cents: number; owned: boolean; vendor: string | null; link: string | null }[]",
    copy_check_cleared: "{ by: { id: string; name: string; avatar: string } | null; at: string } | null",
    copy_check: "{ status: 'pending' | 'match' | 'clear' | 'unscreenable' | 'failed'; reason: 'same_repo' | 'not_github' | 'repo_not_found' | 'no_design_files' | 'too_large' | 'cad_not_checked' | null; mode?: 'pcb' | 'cad' | null; checked_at?: string; attempts?: number; error?: string; modes?: { mode: 'pcb' | 'cad'; verdict: string; files: number; corpus: number; match_count: number }[]; matches?: #{CopyMatch}[]; shared?: { repo: string; url: string; containment: number }[]; same_repo?: { project: string; title: string }[]; compared?: { copied: boolean; by: string; at: string } } | null"

  attributes :note, :used_ai, :ai_usage, :made_with, :repo_url, :copy_check
  attribute(:cut) { |submission| submission.proposed_review["cut"] }
  attribute(:copy_check_holds) { |submission| submission.copy_check_holds_approval? }
  attribute(:copy_check_cleared) do |submission|
    { by: submission.copy_check_cleared_by && PersonSerializer.render(submission.copy_check_cleared_by), at: submission.copy_check_cleared_at } if submission.copy_check_cleared_at
  end
  attribute(:returns) { |submission| params[:returns]&.[](submission.id).to_i }
  attribute(:project) do |submission|
    project = submission.project
    { id: project.public_id, title: project.title, description: project.description, slack_url: project.slack_url,
      team: PersonSerializer.render(project.teammates) }
  end
  attribute(:screenshots) do |submission|
    submission.screenshots.first(3).map { Rails.application.routes.url_helpers.rails_blob_path(it, only_path: true) }
  end
  attribute(:parts) do |submission|
    submission.bom_items.map { { name: it.name, quantity: it.quantity, total_cents: it.total_cents, owned: it.owned, vendor: it.vendor, link: it.link } }
  end
end
