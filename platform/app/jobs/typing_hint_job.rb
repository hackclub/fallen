# A hidden hint for someone starting a top-level post in the journals channel (bin/slack-typing): projects start
# on Fallen, and journals go in a project's thread, so it links the threads they already have. bin/slack-typing is
# already a background process, so `hint` sends it inline; through the queue it arrived after they had posted.
class TypingHintJob < ApplicationJob
  queue_as :realtime

  # Typing events repeat every few seconds; one hint per person per stretch of typing is plenty. The hint comes
  # back sooner once it would say something different or anyone has posted a project or journal in the channel.
  HINT_EVERY = 15.minutes
  PROJECT_LINKS = 5

  def self.hint(slack_user_id, channel_id)
    user = User.kept.find_by(slack_id: slack_user_id)
    projects = threads_for(user, channel_id)
    state = Digest::SHA256.hexdigest(SlackMessages.typing_hint(projects, slack_user_id).merge(latest: latest_post(channel_id)).to_json)
    key = "typing_hint/#{channel_id}/#{slack_user_id}/#{state}"
    return if Rails.cache.exist?(key)

    Rails.cache.write(key, true, expires_in: HINT_EVERY)
    perform_now(slack_user_id, channel_id)
  end

  def self.threads_for(user, channel_id)
    return [] unless user

    user.projects.kept.where(slack_channel_id: channel_id).where.not(slack_thread_ts: nil).recent.limit(PROJECT_LINKS).to_a
  end

  # The newest message still in the channel that Fallen knows about: a project's thread or a journal in one.
  def self.latest_post(channel_id)
    [
      Journal.kept.where(slack_channel_id: channel_id).maximum(:slack_ts),
      Project.kept.where(slack_channel_id: channel_id).maximum(:slack_thread_ts)
    ].compact.max_by(&:to_f)
  end

  def perform(slack_user_id, channel_id)
    projects = self.class.threads_for(User.kept.find_by(slack_id: slack_user_id), channel_id)
    SlackBot.client.chat_postEphemeral(channel: channel_id, user: slack_user_id, **SlackMessages.typing_hint(projects, slack_user_id))
  rescue Slack::Web::Api::Errors::SlackError
    nil
  end
end
