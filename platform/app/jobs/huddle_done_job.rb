# Tells the huddle what someone got done once they say (HuddleDoneAction), in the thread of the huddle running now in
# the channel they were in, as their pet.
class HuddleDoneJob < ApplicationJob
  queue_as :slack
  retry_on Slack::Web::Api::Errors::TooManyRequestsError, wait: :polynomially_longer, attempts: 5

  def perform(session)
    return if session.done.blank?

    huddle = Huddle.current(session.huddle.channel_id) || session.huddle
    return if huddle.thread_ts.nil?

    SlackBot.client.chat_postMessage(channel: huddle.channel_id, thread_ts: huddle.thread_ts, unfurl_links: false, unfurl_media: false, **SlackMessages.huddle_done(session))
  end
end
