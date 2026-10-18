# Someone just finished signing up for Fallen while sitting in the huddle (User#just_joined_fallen?). Their pet
# welcomes them in the huddle's thread and in a DM, which points them at starting a project if they have none.
class HuddleWelcomeJob < ApplicationJob
  queue_as :slack
  retry_on Slack::Web::Api::Errors::TooManyRequestsError, wait: :polynomially_longer, attempts: 5

  def perform(user)
    session = HuddleSession.ongoing.joins(:huddle).merge(Huddle.live).find_by(slack_id: user.slack_id) or return
    huddle = session.huddle

    SlackBot.client.chat_postMessage(channel: huddle.channel_id, thread_ts: huddle.thread_ts, **SlackMessages.huddle_welcome(user))
    SlackBot.client.chat_postMessage(channel: user.slack_id, unfurl_links: false, **SlackMessages.huddle_welcome_dm(user))
  end
end
