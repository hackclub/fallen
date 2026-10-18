# One stretch of someone sitting in the huddle, from when Slack listed them to when it stopped. Their time in the
# huddle is the sum of these (`total_seconds`); nothing pays out for it yet. `mode` and `goal` are what they answered
# when asked what they were working on (HuddleGoalAction). The question also goes to their DMs on joining
# (`dm_channel_id`, `prompt_dm_ts`), and once they leave they are asked there what they got done (HuddleWrapUpJob,
# `wrap_up_asked_at`), which `done` keeps (HuddleDoneAction).
#
# `join_source` and `leave_source` say how exact each end is (SOURCES). `last_seen_at` is the last sync that found
# them in the huddle. `screenshare_seconds` and `camera_seconds` count time with either on, as often as the sync
# checks (every minute, and on every join and leave); `*_since` is when the current stretch of it began.
# == Schema Information
#
# Table name: huddle_sessions
#
#  id                  :bigint           not null, primary key
#  camera_seconds      :integer          default(0), not null
#  camera_since        :datetime
#  done                :text
#  goal                :text
#  join_source         :string
#  joined_at           :datetime         not null
#  last_seen_at        :datetime
#  leave_source        :string
#  left_at             :datetime
#  mode                :string
#  prompt_dm_ts        :string
#  prompted_at_count   :integer
#  screenshare_seconds :integer          default(0), not null
#  screenshare_since   :datetime
#  wrap_up_asked_at    :datetime
#  created_at          :datetime         not null
#  updated_at          :datetime         not null
#  dm_channel_id       :string
#  huddle_id           :bigint           not null
#  slack_id            :string           not null
#  user_id             :bigint
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

  has_paper_trail

  MODES = %w[working chilling].freeze
  # event: the time on Slack's own join or leave event (HuddleEvent), to the millisecond.
  # sync: when a sync first noticed, at most a minute late.
  # unseen: nothing was watching when they left (a deploy, Slack failing), so the last sync that saw them, which
  #   can only undercount.
  # huddle_end: the moment Slack ended the huddle.
  SOURCES = %w[event sync unseen huddle_end].freeze
  # Longer than this since a sync saw someone means syncs were not running, so "now" is not when they left.
  UNSEEN_AFTER = 3.minutes
  # How long after someone leaves to ask what they got done, long enough for a dropped connection to come back.
  WRAP_UP_AFTER = 2.minutes
  # A visit shorter than this is not worth asking about.
  WRAP_UP_MIN = 10.minutes

  set_public_id_prefix :hds

  belongs_to :huddle
  belongs_to :user, optional: true

  validates :slack_id, :joined_at, presence: true
  validates :mode, inclusion: { in: MODES }, allow_nil: true
  validates :join_source, :leave_source, inclusion: { in: SOURCES }, allow_nil: true

  scope :ongoing, -> { where(left_at: nil) }

  # Joining, leaving and answering change the pet's timer; the sync's every-minute last_seen_at does not.
  after_commit -> { TimerChannel.changed(user_id) }, if: -> { (previous_changes.keys & %w[id left_at mode user_id]).any? }
  after_update_commit -> { HuddleWrapUpJob.set(wait: WRAP_UP_AFTER).perform_later(self) }, if: -> { previous_changes.key?("left_at") && left_at }

  # Seconds in the huddle across these sessions, counting open ones up to now.
  def self.total_seconds
    sum(Arel.sql("EXTRACT(EPOCH FROM COALESCE(left_at, CURRENT_TIMESTAMP) - joined_at)")).to_i
  end

  def seconds = ((left_at || Time.current) - joined_at).to_i

  # A sync found them sharing their screen and with their camera on, or not. Writes only when either changed.
  def sharing!(at, screen:, camera:)
    changes = { **stretch(:screenshare, screen, at), **stretch(:camera, camera, at) }
    update!(changes) if changes.any?
  end

  def leave!(at, source)
    at = [ at, joined_at ].max
    update!(left_at: at, leave_source: source, **stretch(:screenshare, false, at), **stretch(:camera, false, at))
  end

  # Whether syncs stopped seeing them a while before `at`, so `at` cannot be when they left. Sessions from before
  # last_seen_at was kept have nothing to go on.
  def unseen_at?(at) = last_seen_at.present? && at - last_seen_at > UNSEEN_AFTER

  # Whether to ask what they got done now that this session has ended: they have not come back, were not just
  # dropped by Slack ending the huddle (HuddleHandoffJob asks them over instead), were not only chilling, and spent
  # WRAP_UP_MIN in it since they were last asked.
  def wrap_up_due?
    return false if left_at.nil? || wrap_up_asked_at || mode == "chilling"
    return false if HuddleSession.ongoing.exists?(slack_id: slack_id)
    return false if huddle.ended? && left_at >= huddle.ended_at - Huddle::END_GRACE

    visit.total_seconds >= WRAP_UP_MIN
  end

  # This person's sessions in this huddle since they were last asked what they got done.
  def visit
    mine = huddle.sessions.where(slack_id: slack_id)
    asked = mine.where.not(wrap_up_asked_at: nil).maximum(:left_at)
    mine.where(joined_at: (asked || huddle.started_at)..left_at)
  end

  private

  # Opens or closes a stretch of screenshare or camera time.
  def stretch(name, on, at)
    since = self["#{name}_since"]
    if on && since.nil?
      { "#{name}_since" => at }
    elsif !on && since
      { "#{name}_since" => nil, "#{name}_seconds" => self["#{name}_seconds"] + (at - since).to_i.clamp(0..) }
    else
      {}
    end
  end
end
