# frozen_string_literal: true

# A write an MCP agent asked to make with query_sql, waiting for an admin to look at its preview and approve it
# (Mcp::Sql, /admin/sql_changes/:id, docs/mcp.md). Nothing is written until then. A change runs at most once, only
# while pending and not expired, and only if its rows still match the preview. No has_paper_trail: the row is itself
# the record of who asked, who decided and what ran.
# == Schema Information
#
# Table name: mcp_sql_changes
#
#  id             :bigint           not null, primary key
#  error          :text
#  expires_at     :datetime         not null
#  kind           :string           not null
#  preview        :jsonb            not null
#  resolved_at    :datetime
#  rows_affected  :integer
#  sql            :text             not null
#  status         :string           default("pending"), not null
#  table_name     :string           not null
#  created_at     :datetime         not null
#  updated_at     :datetime         not null
#  admin_token_id :bigint           not null
#  reviewer_id    :bigint
#  user_id        :bigint           not null
#
# Indexes
#
#  index_mcp_sql_changes_on_admin_token_id  (admin_token_id)
#  index_mcp_sql_changes_on_created_at      (created_at)
#  index_mcp_sql_changes_on_reviewer_id     (reviewer_id)
#  index_mcp_sql_changes_on_user_id         (user_id)
#
# Foreign Keys
#
#  fk_rails_...  (admin_token_id => admin_tokens.id)
#  fk_rails_...  (reviewer_id => users.id)
#  fk_rails_...  (user_id => users.id)
#
class McpSqlChange < ApplicationRecord
  include PublicIdentifiable

  set_public_id_prefix :sql

  LIFETIME = 30.minutes
  STATUSES = %w[pending done rejected failed].freeze

  belongs_to :user
  belongs_to :admin_token
  belongs_to :reviewer, class_name: "User", optional: true

  validates :sql, :kind, :table_name, presence: true
  validates :status, inclusion: { in: STATUSES }

  scope :newest_first, -> { order(created_at: :desc, id: :desc) }

  def self.request!(sql:, admin:, token:)
    preview = Mcp::Sql.preview(sql)
    create!(sql: sql.to_s.strip, kind: preview["kind"], table_name: preview["table"], preview:, user: admin, admin_token: token,
            expires_at: LIFETIME.from_now)
  end

  # "expired" is a pending change nobody decided on in time; it is never stored, so no sweeper is needed.
  def state = status == "pending" && expires_at.past? ? "expired" : status
  def pending? = state == "pending"

  def approve!(reviewer)
    decide!(reviewer) do
      # A leaked token's request dies with the token, even if someone opens its link.
      raise Mcp::Refused, "The token that asked for this has been revoked or has expired." unless admin_token.live?

      update!(status: "done", rows_affected: Mcp::Sql.execute!(self))
    rescue Mcp::Sql::Stale, Mcp::Refused => e
      update!(status: "failed", error: e.message)
    end
  end

  def reject!(reviewer) = decide!(reviewer) { update!(status: "rejected") }

  private

  # The row lock makes two clicks, or two admins, decide once.
  def decide!(reviewer)
    with_lock do
      raise Mcp::Refused, "This change is #{state}, so it can't be decided now." unless pending?

      self.reviewer = reviewer
      self.resolved_at = Time.current
      yield
    end
    Rails.logger.info({ event: "mcp_sql_change.#{status}", sql_change_id: id, reviewer_id: reviewer.id, rows: rows_affected }.to_json)
    self
  end
end
