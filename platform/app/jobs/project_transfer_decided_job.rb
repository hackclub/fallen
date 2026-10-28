# DMs someone the decision on their project transfer (ProjectTransfer#approve and #reject), with the reviewer's
# message if they wrote one. An approval also tells the rest of the project's team (`to:`) that its journals were
# added. Nothing for someone without Slack linked.
class ProjectTransferDecidedJob < ApplicationJob
  queue_as :slack
  retry_on Slack::Web::Api::Errors::TooManyRequestsError, wait: :polynomially_longer, attempts: 5

  def perform(transfer, new_project: false, to: transfer.user)
    return if transfer.pending? || to.nil? || to.slack_id.blank? || !SlackBot.configured?
    # A deleted or banned account can still be on a team.
    return if to != transfer.user && (to.discarded? || to.is_banned?)

    message = if to == transfer.user
      SlackMessages.project_transfer_decided(transfer, new_project:)
    else
      SlackMessages.project_transfer_added_to_team(transfer)
    end
    SlackBot.client.chat_postMessage(channel: to.slack_id, **message)
  end
end
