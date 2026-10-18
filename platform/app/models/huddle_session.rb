# One stretch of someone sitting in the huddle, from when Slack listed them to when it stopped. Their time in the
# huddle is the sum of these; nothing pays out for it yet. `mode` and `goal` are what they answered when asked
# what they were working on (HuddleGoalAction).
# == Schema Information
#
# Table name: huddle_sessions
#
#  id                :bigint           not null, primary key
#  goal              :text
#  joined_at         :datetime         not null
#  left_at           :datetime
#  mode              :string
#  prompted_at_count :integer
#  created_at        :datetime         not null
#  updated_at        :datetime         not null
#  huddle_id         :bigint           not null
#  slack_id          :string           not null
#  user_id           :bigint
#
# Indexes
#
#  index_huddle_sessions_on_huddle_id_and_slack_id  (huddle_id,slack_id)
#  index_huddle_sessions_on_slack_id                (slack_id)
#  index_huddle_sessions_on_user_id                 (user_id)
#  index_huddle_sessions_one_open_per_person        (huddle_id,slack_id) UNIQUE WHERE (left_at IS NULL)
#
# Foreign Keys
#
#  fk_rails_...  (huddle_id => huddles.id)
#  fk_rails_...  (user_id => users.id)
#
class HuddleSession < ApplicationRecord
  include PublicIdentifiable

  MODES = %w[working chilling].freeze

  set_public_id_prefix :hds

  belongs_to :huddle
  belongs_to :user, optional: true

  validates :slack_id, :joined_at, presence: true
  validates :mode, inclusion: { in: MODES }, allow_nil: true

  scope :ongoing, -> { where(left_at: nil) }

  def leave!(at) = update!(left_at: [ at, joined_at ].max)

  def minutes = (((left_at || Time.current) - joined_at) / 60).floor
end
