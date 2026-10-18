# Someone who has finished onboarding and linked Slack (User#just_joined_fallen?) is added to the members channel
# (SLACK_MEMBERS_CHANNEL_ID). The bot has to be in that channel to invite anyone to it.
class JoinMembersChannelJob < ApplicationJob
  queue_as :slack
  retry_on Slack::Web::Api::Errors::TooManyRequestsError, wait: :polynomially_longer, attempts: 5
  discard_on Slack::Web::Api::Errors::AlreadyInChannel, Slack::Web::Api::Errors::CantInviteSelf

  def self.channel_id = ENV["SLACK_MEMBERS_CHANNEL_ID"].presence

  def perform(user)
    return unless SlackBot.configured? && self.class.channel_id && user.slack_id.present?

    SlackBot.client.conversations_invite(channel: self.class.channel_id, users: user.slack_id)
  end
end
