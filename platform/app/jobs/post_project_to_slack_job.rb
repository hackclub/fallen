# Posts the top-level message that becomes a web-started project's Slack thread. A project made before its owner
# connected Slack waits for SlackAuthController#create to enqueue this again.
class PostProjectToSlackJob < ApplicationJob
  queue_as :slack
  retry_on Slack::Web::Api::Errors::TooManyRequestsError, wait: :polynomially_longer, attempts: 5

  def perform(project)
    return if project.discarded? || project.slack_linked? || !SlackMessaging.configured? || !project.user.slack_connected?

    channel = SlackMessaging.journals_channel_id
    ts = SlackMessaging.post(project.user, channel: channel, **SlackMessages.project_anchor(project))
    project.update_columns(slack_channel_id: channel, slack_thread_ts: ts)
    journals = project.journals.kept.where(slack_ts: nil).order(:created_at)
    journals.each { |journal| SyncJournalToSlackJob.perform_later(journal, "create") }
  end
end
