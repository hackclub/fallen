# frozen_string_literal: true

# Rows on /projects.
# == Schema Information
#
# Table name: projects
#
#  id               :bigint           not null, primary key
#  demo_url         :string
#  description      :text
#  discarded_at     :datetime
#  repo_url         :string
#  slack_thread_ts  :string
#  title            :string           not null
#  created_at       :datetime         not null
#  updated_at       :datetime         not null
#  slack_channel_id :string
#  user_id          :bigint           not null
#
# Indexes
#
#  index_projects_on_discarded_at                          (discarded_at)
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
            total_minutes: :number, journal_count: :number
  attributes :title, :description, :repo_url, :demo_url, :created_at, :updated_at
  attribute(:id) { |project| project.public_id }
  attribute(:slack_url, &:slack_url)
  attribute(:banner) do |project|
    blob = project.banner.attachment&.blob
    blob && { id: blob.signed_id, url: blob_path(blob) }
  end
  # The banner, or else the first journal photo when the caller passes `covers:` (Project.journal_covers).
  attribute(:cover_url) do |project|
    blob = project.banner.attachment&.blob || params[:covers]&.dig(project.id)&.blob
    blob && blob_path(blob)
  end
  # Lists pass precomputed totals; projects missing from them have no journals.
  attribute(:total_minutes) { |project| params[:totals] ? params[:totals].fetch(project.id, 0) : project.total_minutes }
  attribute(:journal_count) { |project| params[:counts] ? params[:counts].fetch(project.id, 0) : project.journal_count }

  helper do
    def blob_path(blob) = Rails.application.routes.url_helpers.rails_blob_path(blob, only_path: true)
  end
end
