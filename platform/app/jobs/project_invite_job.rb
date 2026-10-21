# Tells someone in a Slack DM that they were invited to a project's team (ProjectInvitesController). The invite also
# waits on their home page, so someone without Slack linked still finds it.
class ProjectInviteJob < ApplicationJob
  queue_as :slack
  retry_on Slack::Web::Api::Errors::TooManyRequestsError, wait: :polynomially_longer, attempts: 5

  def perform(invite)
    return if !invite.project.kept? || invite.user.slack_id.blank? || !SlackBot.configured?

    SlackBot.client.chat_postMessage(channel: invite.user.slack_id, unfurl_links: false, unfurl_media: false, **SlackMessages.project_invite(invite))
  end
end
