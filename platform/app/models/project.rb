# One build. Anchored to a Slack thread in the journals channel: the top-level message is the project,
# every reply from the owner is a Journal. Projects started on the web get their anchor posted by
# PostProjectToSlackJob.
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
class Project < ApplicationRecord
  include PublicIdentifiable
  include Discardable

  set_public_id_prefix :prj
  has_paper_trail

  belongs_to :user
  has_many :journals, dependent: :destroy

  validates :title, presence: true, length: { maximum: 120 }
  validates :description, length: { maximum: 5_000 }
  validates :repo_url, :demo_url, format: { with: %r{\Ahttps?://\S+\z}, message: "must be a link starting with http(s)://" }, allow_blank: true
  validates :slack_thread_ts, uniqueness: { scope: :slack_channel_id }, allow_nil: true

  scope :recent, -> { order(updated_at: :desc) }

  def self.find_by_slack_thread(channel_id, thread_ts)
    return nil if channel_id.blank? || thread_ts.blank?

    kept.find_by(slack_channel_id: channel_id, slack_thread_ts: thread_ts)
  end

  def slack_linked? = slack_channel_id.present? && slack_thread_ts.present?

  def slack_url = slack_linked? ? SlackMessaging.permalink(slack_channel_id, slack_thread_ts) : nil

  def total_minutes = journals.kept.sum(:duration_minutes)

  def journal_count = journals.kept.count

  def discard
    transaction do
      journals.kept.includes(images_attachments: :blob).find_each(&:discard)
      super
    end
  end
end
