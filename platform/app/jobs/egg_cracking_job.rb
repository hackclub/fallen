# Someone's first journal from Slack just hatched their egg: tells them in a DM, or in their project's thread when
# given the project, with a button that plays the hatch on the site. JournalDraftAction enqueues one of each, so a
# retry of one never posts the other twice.
class EggCrackingJob < ApplicationJob
  queue_as :slack
  retry_on Slack::Web::Api::Errors::TooManyRequestsError, wait: :polynomially_longer, attempts: 5

  def perform(user, project = nil)
    return if user.slack_id.blank? || user.pet.blank?

    where = project ? { channel: project.slack_channel_id, thread_ts: project.slack_thread_ts } : { channel: user.slack_id }
    SlackBot.client.chat_postMessage(**where, unfurl_links: false, unfurl_media: false, **SlackMessages.egg_cracking(user.pet))
  end
end
