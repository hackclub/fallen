namespace :slack do
  desc "Queue every web project and journal that never reached Slack (e.g. after a failed post)"
  task backfill: :environment do
    connected = User.where.not(slack_user_token: nil)
    projects = Project.kept.where(user: connected)

    unlinked = projects.where(slack_thread_ts: nil)
    unlinked.find_each { |project| PostProjectToSlackJob.perform_later(project) }

    # Unlinked projects queue their own journals once the anchor is posted.
    journals = Journal.kept.where(slack_ts: nil, user: connected, project: projects.where.not(slack_thread_ts: nil))
    journals.find_each { |journal| SyncJournalToSlackJob.perform_later(journal, "create") }

    puts "Queued #{unlinked.count} projects and #{journals.count} journals"
  end
end
