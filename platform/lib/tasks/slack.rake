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

  desc "Rewrite every project's Slack anchor in the current format (DRY_RUN=1 to only count what would change)"
  task rewrite_anchors: :environment do
    dry_run = ENV["DRY_RUN"].present?
    tally = Hash.new(0)
    skipped = Hash.new { |hash, key| hash[key] = [] }

    Project.kept.where.not(slack_thread_ts: nil).includes(:user).find_each do |project|
      outcome = begin
        RewriteProjectAnchorJob.new.perform(project, dry_run: dry_run)
      rescue Slack::Web::Api::Errors::TooManyRequestsError => e
        sleep e.retry_after.to_i.clamp(1, 60)
        retry
      end
      tally[outcome] += 1
      skipped[outcome] << project.public_id unless outcome.in?(%i[rewritten would_rewrite already_rewritten])
    end

    puts(dry_run ? "Dry run, nothing changed." : "Done.")
    tally.each { |outcome, count| puts "#{outcome}: #{count}" }
    skipped.each { |outcome, ids| puts "#{outcome}: #{ids.join(' ')}" }
  end
end
