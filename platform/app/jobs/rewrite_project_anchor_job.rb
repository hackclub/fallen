# Rewrites a project's anchor in the current SlackMessages.project_anchor format, as the owner who posted it. Fallen
# never edited anchors before this, so one Slack marks as edited was changed by the person there, and their words are
# left alone. Returns what it did, for `slack:rewrite_anchors`.
class RewriteProjectAnchorJob < ApplicationJob
  queue_as :slack
  retry_on Slack::Web::Api::Errors::TooManyRequestsError, wait: :polynomially_longer, attempts: 5

  def perform(project, dry_run: false)
    return :not_linked if project.discarded? || !project.slack_linked?
    return :already_rewritten if project.slack_posted_by_bot?
    return :not_connected unless project.user.slack_connected?

    message = find_anchor(project) or return :gone
    return :not_theirs if message.user != project.user.slack_id
    return :already_rewritten if message.text.to_s.start_with?("Project name:")
    return :edited_in_slack if message.edited.present?
    return :would_rewrite if dry_run

    SlackMessaging.update(project.user, channel: project.slack_channel_id, ts: project.slack_thread_ts, by_bot: false, **SlackMessages.project_anchor(project))
    :rewritten
  rescue SlackMessaging::NotConnected
    :not_connected
  rescue Slack::Web::Api::Errors::CantUpdateMessage, Slack::Web::Api::Errors::MessageNotFound, Slack::Web::Api::Errors::EditWindowClosed
    :cant_edit
  end

  private

  def find_anchor(project)
    replies = SlackBot.client.conversations_replies(channel: project.slack_channel_id, ts: project.slack_thread_ts, limit: 1)
    Array(replies.messages).find { |message| message.ts == project.slack_thread_ts }
  rescue Slack::Web::Api::Errors::ThreadNotFound, Slack::Web::Api::Errors::MessageNotFound
    nil
  end
end
