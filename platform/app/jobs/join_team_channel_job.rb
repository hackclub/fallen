# Someone with Slack linked is added to their pet's channel (SLACK_LULU_CHANNEL_ID, SLACK_SAMI_CHANNEL_ID) when they
# pick it, switch to it or link Slack. A switch doesn't remove them from the old one. The bot has to be in both
# channels to invite anyone to them.
class JoinTeamChannelJob < ApplicationJob
  queue_as :slack
  retry_on Slack::Web::Api::Errors::TooManyRequestsError, wait: :polynomially_longer, attempts: 5
  discard_on Slack::Web::Api::Errors::AlreadyInChannel, Slack::Web::Api::Errors::CantInviteSelf
  discard_on Slack::Web::Api::Errors::UserIsRestricted, Slack::Web::Api::Errors::OrgUserNotInTeam

  def self.channel_id(pet) = pet.present? ? ENV["SLACK_#{pet.upcase}_CHANNEL_ID"].presence : nil

  def perform(user)
    channel = self.class.channel_id(user.pet)
    return unless SlackBot.configured? && channel && user.slack_id.present?

    SlackBot.client.conversations_invite(channel: channel, users: user.slack_id)
  end
end
