# Mirrors a web-written journal into the project's Slack thread: create, update or delete. Transferred journals
# (ProjectTransfer) were written in another program and stay off Slack.
class SyncJournalToSlackJob < ApplicationJob
  queue_as :slack
  retry_on Slack::Web::Api::Errors::TooManyRequestsError, wait: :polynomially_longer, attempts: 5
  # Their token stopped working or they never connected; SlackAuthController queues the journal again once they
  # connect or skip.
  discard_on SlackMessaging::NotConnected

  def perform(journal, action)
    return unless SlackMessaging.configured?

    case action
    when "create" then create(journal)
    when "update" then update(journal)
    when "delete" then delete(journal)
    end
  end

  private

  def create(journal)
    project = journal.project
    return if journal.discarded? || journal.on_slack? || journal.transferred?
    return PostProjectToSlackJob.perform_later(project) unless project.slack_linked?

    posted = SlackMessaging.post(journal.user, channel: project.slack_channel_id, thread_ts: project.slack_thread_ts, **SlackMessages.journal(journal))
    journal.update_columns(slack_channel_id: project.slack_channel_id, slack_ts: posted.ts, slack_posted_by_bot: posted.by_bot)
  end

  # A journal spanning several Slack replies has no one message to rewrite, so web edits stay on the web.
  def update(journal)
    return create(journal) unless journal.on_slack?
    return if journal.multi_part?

    SlackMessaging.update(journal.user, channel: journal.slack_channel_id, ts: journal.slack_ts, by_bot: journal.slack_posted_by_bot, **SlackMessages.journal(journal))
  rescue Slack::Web::Api::Errors::CantUpdateMessage, Slack::Web::Api::Errors::MessageNotFound
    nil
  end

  def delete(journal)
    return unless journal.on_slack?

    SlackMessaging.delete(journal.user, channel: journal.slack_channel_id, ts: journal.slack_ts, by_bot: journal.slack_posted_by_bot)
  rescue Slack::Web::Api::Errors::CantDeleteMessage
    nil
  end
end
