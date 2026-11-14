# frozen_string_literal: true

# Admin-only. A transfer's Lapse review on /admin/transfers/:id/lapse (TransferLapseReview). `counted` says where else
# each recording was counted, keyed like the recordings.
class AdminTransferLapseSerializer < ApplicationSerializer
  typelize_from ProjectTransfer
  typelize id: :string, title: :string, slack_id: [ :string, nullable: true ], snapshot_minutes: [ :number, nullable: true ],
           lapse_fetched_at: [ :string, nullable: true ], fetching: :boolean,
           entries: "Array<{ ref: string; at: string | null; minutes: number; body: string; images: string[] }>",
           recordings: "Array<{ key: string; kind: 'lapse' | 'lookout'; name: string | null; missing: boolean; seconds: number; " \
                       "started_at?: string | null; playback_url?: string | null; thumbnail_url?: string | null; url?: string | null; " \
                       "project: string; heartbeats: number; first_heartbeat_at: string; last_heartbeat_at: string; visibility?: string; " \
                       "owner_hackatime_id?: string | null; owner_slack_id?: string | null; status?: string; program?: string; counted: string[] }> | null",
           lapse_annotations: "Record<string, { reviewed?: boolean; description?: string; video_seconds?: number; " \
                              "segments?: Array<{ type: 'removed' | 'deflated'; start: number; end: number; reason: string; percent?: number }> }>"
  attributes :status, :source_url, :claimed_minutes, :hackatime_user_id, :hackatime_projects, :lapse_annotations, :lapse_seconds,
             :lapse_fetched_at, :lapse_error
  attribute(:id) { |transfer| transfer.public_id }
  attribute(:title) { |transfer| transfer.snapshot&.dig("title") || transfer.project_name || "Untitled" }
  attribute(:slack_id) { |transfer| transfer.user&.slack_id }
  attribute(:snapshot_minutes, &:snapshot_minutes)
  attribute(:fetching, &:lapse_fetching?)
  attribute(:entries) do |transfer|
    Array(transfer.snapshot&.dig("entries")).map { it.slice("ref", "at", "minutes", "body").merge("images" => Array(it["images"])) }
  end
  attribute(:recordings) do |transfer|
    transfer.lapse_recordings&.map { it.merge("counted" => params.fetch(:counted, {}).fetch(it["key"], [])) }
  end
end
