# frozen_string_literal: true

# One row per tool call the MCP server ran (Mcp::Invoke, docs/mcp.md): who, with which token, which tool, the
# scrubbed arguments, what came back and how long it took. Every PaperTrail version written during the call carries
# this row's id in `versions.mcp_action_id`. Reads are logged as well as writes, so an admin can see what an agent
# looked at. No has_paper_trail: the row is itself the audit record, and it is only ever closed with update_columns.
# == Schema Information
#
# Table name: mcp_actions
#
#  id             :bigint           not null, primary key
#  arguments      :jsonb            not null
#  duration_ms    :integer
#  error          :text
#  kind           :string           not null
#  result         :jsonb
#  status         :string           not null
#  subject_type   :string
#  tool           :string           not null
#  created_at     :datetime         not null
#  updated_at     :datetime         not null
#  admin_token_id :bigint           not null
#  subject_id     :bigint
#  user_id        :bigint           not null
#
# Indexes
#
#  index_mcp_actions_on_admin_token_id               (admin_token_id)
#  index_mcp_actions_on_created_at                   (created_at)
#  index_mcp_actions_on_subject_type_and_subject_id  (subject_type,subject_id)
#  index_mcp_actions_on_user_id                      (user_id)
#
# Foreign Keys
#
#  fk_rails_...  (admin_token_id => admin_tokens.id)
#  fk_rails_...  (user_id => users.id)
#
class McpAction < ApplicationRecord
  KINDS = %w[read write].freeze
  STATUSES = %w[running ok error refused].freeze

  belongs_to :user
  belongs_to :admin_token
  belongs_to :subject, polymorphic: true, optional: true

  validates :tool, presence: true
  validates :kind, inclusion: { in: KINDS }
  validates :status, inclusion: { in: STATUSES }

  scope :newest_first, -> { order(created_at: :desc, id: :desc) }

  def versions = PaperTrail::Version.where(mcp_action_id: id).order(:id)
end
