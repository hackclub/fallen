# frozen_string_literal: true

# == Schema Information
#
# Table name: journals
#
#  id                 :bigint           not null, primary key
#  body               :text             not null
#  discarded_at       :datetime
#  duration_minutes   :integer
#  lapse_url          :string
#  slack_parts        :jsonb            not null
#  slack_ts           :string
#  source             :string           default("web"), not null
#  created_at         :datetime         not null
#  updated_at         :datetime         not null
#  lapse_timelapse_id :bigint
#  project_id         :bigint           not null
#  slack_channel_id   :string
#  user_id            :bigint           not null
#
# Indexes
#
#  index_journals_needing_hours                     (project_id) WHERE ((discarded_at IS NULL) AND (duration_minutes IS NULL))
#  index_journals_on_created_at                     (created_at)
#  index_journals_on_discarded_at                   (discarded_at)
#  index_journals_on_lapse_timelapse_id             (lapse_timelapse_id) UNIQUE WHERE ((lapse_timelapse_id IS NOT NULL) AND (discarded_at IS NULL))
#  index_journals_on_project_id                     (project_id)
#  index_journals_on_slack_channel_id_and_slack_ts  (slack_channel_id,slack_ts) UNIQUE WHERE (slack_ts IS NOT NULL)
#  index_journals_on_slack_parts                    (slack_parts jsonb_path_ops) USING gin
#  index_journals_on_user_id                        (user_id)
#
# Foreign Keys
#
#  fk_rails_...  (lapse_timelapse_id => lapse_timelapses.id)
#  fk_rails_...  (project_id => projects.id)
#  fk_rails_...  (user_id => users.id)
#
class JournalSerializer < ApplicationSerializer
  typelize_from Journal
  typelize id: :string, slack_url: [ :string, nullable: true ], duration_text: [ :string, nullable: true ], xp: [ :number, nullable: true ],
           images: "Array<{ id: string; url: string; filename: string }>"
  attributes :body, :duration_minutes, :lapse_url, :source, :created_at, :updated_at
  attribute(:id) { |journal| journal.public_id }
  attribute(:slack_url, &:slack_url)
  attribute(:duration_text, &:duration_text)
  attribute(:xp, &:xp)
  one :lapse_timelapse, resource: LapseTimelapseSerializer
  attribute(:images) do |journal|
    journal.images.map do |image|
      { id: image.signed_id, url: Rails.application.routes.url_helpers.rails_blob_path(image, only_path: true), filename: image.filename.to_s }
    end
  end
end
