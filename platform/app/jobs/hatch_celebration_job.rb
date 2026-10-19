# The pet's welcome in the thread of the person's first journal, posted as the pet once they have watched it hatch
# on the site (User#hatch_seen!). Skipped when that thread is gone from Slack, top message and replies all deleted,
# since posting there would leave the welcome on its own.
class HatchCelebrationJob < ApplicationJob
  queue_as :slack
  retry_on Slack::Web::Api::Errors::TooManyRequestsError, wait: :polynomially_longer, attempts: 5

  def perform(user)
    project = user.first_journal_project
    return if user.pet.blank? || project.nil? || project.discarded? || project.slack_thread_ts.blank?
    return unless thread_exists?(project)

    SlackBot.client.chat_postMessage(channel: project.slack_channel_id, thread_ts: project.slack_thread_ts, unfurl_links: false, unfurl_media: false,
                                     **SlackMessages.hatch_celebration(user.pet))
  end

  private

  # A top message deleted under replies stays as a tombstone and still answers here.
  def thread_exists?(project)
    replies = SlackBot.client.conversations_replies(channel: project.slack_channel_id, ts: project.slack_thread_ts, limit: 1)
    Array(replies.messages).any?
  rescue Slack::Web::Api::Errors::ThreadNotFound, Slack::Web::Api::Errors::MessageNotFound
    false
  end
end
