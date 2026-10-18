# == Schema Information
#
# Table name: lapse_timelapses
#
#  id               :bigint           not null, primary key
#  duration_seconds :integer          default(0), not null
#  name             :string
#  playback_url     :string
#  recorded_at      :datetime
#  thumbnail_url    :string
#  visibility       :string
#  created_at       :datetime         not null
#  updated_at       :datetime         not null
#  journal_id       :bigint
#  lapse_id         :string           not null
#  user_id          :bigint           not null
#
# Indexes
#
#  index_lapse_timelapses_on_journal_id   (journal_id)
#  index_lapse_timelapses_on_lapse_id     (lapse_id) UNIQUE
#  index_lapse_timelapses_on_recorded_at  (recorded_at)
#  index_lapse_timelapses_on_user_id      (user_id)
#
# Foreign Keys
#
#  fk_rails_...  (journal_id => journals.id)
#  fk_rails_...  (user_id => users.id)
#
class LapseTimelapseSerializer < ApplicationSerializer
  typelize_from LapseTimelapse
  typelize id: :string, duration_minutes: :number, duration_text: [ :string, nullable: true ], url: :string, unusable_reason: [ :string, nullable: true ]
  attributes :name, :duration_minutes, :thumbnail_url, :recorded_at
  attribute(:id) { |timelapse| timelapse.public_id }
  attribute(:duration_text, &:duration_text)
  attribute(:url, &:url)
  attribute(:unusable_reason, &:unusable_reason)
end
