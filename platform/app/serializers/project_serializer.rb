# frozen_string_literal: true

# Rows on /projects.
# == Schema Information
#
# Table name: projects
#
#  id                  :bigint           not null, primary key
#  approved_at         :datetime
#  demo_url            :string
#  description         :text
#  discarded_at        :datetime
#  join_token          :string
#  repo_url            :string
#  slack_posted_by_bot :boolean          default(FALSE), not null
#  slack_thread_ts     :string
#  title               :string           not null
#  created_at          :datetime         not null
#  updated_at          :datetime         not null
#  slack_channel_id    :string
#  user_id             :bigint           not null
#
# Indexes
#
#  index_projects_on_discarded_at                          (discarded_at)
#  index_projects_on_join_token                            (join_token) UNIQUE
#  index_projects_on_slack_channel_id_and_slack_thread_ts  (slack_channel_id,slack_thread_ts) UNIQUE WHERE (slack_thread_ts IS NOT NULL)
#  index_projects_on_updated_at                            (updated_at)
#  index_projects_on_user_id                               (user_id)
#
# Foreign Keys
#
#  fk_rails_...  (user_id => users.id)
#
class ProjectSerializer < ApplicationSerializer
  typelize_from Project
  typelize id: :string, slack_url: [ :string, nullable: true ], banner: "{ id: string; url: string } | null",
            cover_url: [ :string, nullable: true ],
            total_minutes: :number, journal_count: :number,
            role: "'owner' | 'member' | 'former' | null"
  attributes :title, :description, :repo_url, :demo_url, :created_at, :updated_at
  attribute(:id) { |project| project.public_id }
  attribute(:slack_url, &:slack_url)
  attribute(:banner) do |project|
    blob = project.banner.attachment&.blob
    blob && { id: blob.signed_id, url: blob_path(blob) }
  end
  # The banner, or else the newest journal's photo when the caller passes `covers:` (Project.journal_covers).
  attribute(:cover_url) do |project|
    blob = project.banner.attachment&.blob || params[:covers]&.dig(project.id)&.blob
    blob && blob_path(blob)
  end
  # Lists pass precomputed totals; projects missing from them have no journals.
  attribute(:total_minutes) { |project| params[:totals] ? params[:totals].fetch(project.id, 0) : project.total_minutes }
  attribute(:journal_count) { |project| params[:counts] ? params[:counts].fetch(project.id, 0) : project.journal_count }
  # Owner first. Lists preload them (Project.preload_teams).
  many :teammates, resource: PersonSerializer
  # Where the person looking stands, for lists of their projects (`viewer:`): "former" is one they have left but have
  # journals on (Project.involving).
  attribute(:role) do |project|
    viewer = params[:viewer] or next nil
    if project.user_id == viewer.id then "owner"
    elsif project.on_team?(viewer) then "member"
    else "former"
    end
  end

  helper do
    def blob_path(blob) = Rails.application.routes.url_helpers.rails_blob_path(blob, only_path: true)
  end
end
