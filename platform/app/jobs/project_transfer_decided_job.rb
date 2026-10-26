# DMs someone the decision on their project transfer (ProjectTransfer#approve and #reject), with the reviewer's
# message if they wrote one. Nothing for someone without Slack linked.
class ProjectTransferDecidedJob < ApplicationJob
  queue_as :slack
  retry_on Slack::Web::Api::Errors::TooManyRequestsError, wait: :polynomially_longer, attempts: 5

  def perform(transfer, new_project: false)
    user = transfer.user
    return if transfer.pending? || user.nil? || user.slack_id.blank? || !SlackBot.configured?

    SlackBot.client.chat_postMessage(channel: user.slack_id, **SlackMessages.project_transfer_decided(transfer, new_project:))
  end
end
