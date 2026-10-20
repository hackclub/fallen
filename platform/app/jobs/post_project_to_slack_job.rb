# Posts the top-level message that becomes a web-started project's Slack thread. A project made before its owner
# connected or skipped Slack waits for SlackAuthController to enqueue this again.
class PostProjectToSlackJob < ApplicationJob
  queue_as :slack
  retry_on Slack::Web::Api::Errors::TooManyRequestsError, wait: :polynomially_longer, attempts: 5

  def perform(project)
    return if project.discarded? || project.slack_linked? || !SlackMessaging.configured? || !project.user.slack_ready?

    channel = SlackMessaging.journals_channel_id
    posted = SlackMessaging.post(project.user, channel: channel, **SlackMessages.project_anchor(project))
    project.update_columns(slack_channel_id: channel, slack_thread_ts: posted.ts, slack_posted_by_bot: posted.by_bot)
    SlackMessaging.subscribe(project.user, channel: channel, thread_ts: posted.ts) if posted.by_bot
    journals = project.journals.kept.where(slack_ts: nil).order(:created_at)
    journals.each { |journal| SyncJournalToSlackJob.perform_later(journal, "create") }
  end
end
