# Mirrors a web-written journal into the project's Slack thread: create, update or delete.
class SyncJournalToSlackJob < ApplicationJob
  queue_as :slack
  retry_on Slack::Web::Api::Errors::TooManyRequestsError, wait: :polynomially_longer, attempts: 5

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
    return if journal.discarded? || journal.on_slack?
    return PostProjectToSlackJob.perform_later(project) unless project.slack_linked?

    ts = SlackMessaging.post(journal.user, channel: project.slack_channel_id, thread_ts: project.slack_thread_ts, **SlackMessages.journal(journal))
    journal.update_columns(slack_channel_id: project.slack_channel_id, slack_ts: ts)
  end

  def update(journal)
    return create(journal) unless journal.on_slack?

    SlackMessaging.update(journal.user, channel: journal.slack_channel_id, ts: journal.slack_ts, **SlackMessages.journal(journal))
  rescue Slack::Web::Api::Errors::CantUpdateMessage, Slack::Web::Api::Errors::MessageNotFound
    nil
  end

  def delete(journal)
    return unless journal.on_slack?

    SlackMessaging.delete(journal.user, channel: journal.slack_channel_id, ts: journal.slack_ts)
  rescue Slack::Web::Api::Errors::CantDeleteMessage
    nil
  end
end
