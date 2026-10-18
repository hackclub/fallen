# The pet's welcome in the thread of the person's first journal, posted as the pet once they have watched it hatch
# on the site (User#hatch_seen!).
class HatchCelebrationJob < ApplicationJob
  queue_as :slack
  retry_on Slack::Web::Api::Errors::TooManyRequestsError, wait: :polynomially_longer, attempts: 5

  def perform(user)
    project = user.first_journal_project
    return if user.pet.blank? || project.nil? || project.discarded? || project.slack_thread_ts.blank?

    SlackBot.client.chat_postMessage(channel: project.slack_channel_id, thread_ts: project.slack_thread_ts, unfurl_links: false, unfurl_media: false,
                                     **SlackMessages.hatch_celebration(user.pet))
  end
end
