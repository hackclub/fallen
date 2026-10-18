# Someone in the huddle just finished onboarding or linked Slack (User#just_joined_fallen?). Their pet DMs them,
# pointing them at starting a project if they have none, and welcomes them in the huddle's thread only when the
# account was made during this visit: someone who already had one is not news.
class HuddleWelcomeJob < ApplicationJob
  queue_as :slack
  retry_on Slack::Web::Api::Errors::TooManyRequestsError, wait: :polynomially_longer, attempts: 5

  def perform(user)
    session = HuddleSession.ongoing.joins(:huddle).merge(Huddle.live).find_by(slack_id: user.slack_id) or return
    huddle = session.huddle

    if user.created_at >= session.joined_at
      SlackBot.client.chat_postMessage(channel: huddle.channel_id, thread_ts: huddle.thread_ts, **SlackMessages.huddle_welcome(user))
    end
    SlackBot.client.chat_postMessage(channel: user.slack_id, unfurl_links: false, **SlackMessages.huddle_welcome_dm(user))
  end
end
