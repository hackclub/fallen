namespace :progress_reviews do
  desc "Put every project already over the journal review threshold in the queue (ProgressStatus.refresh)"
  task backfill: :environment do
    ids = Journal.kept.written_here.group(:project_id).having("SUM(duration_minutes) >= ?", ProgressStatus::FIRST_AT_MINUTES).pluck(:project_id)
    Project.kept.where(id: ids).find_each { ProgressStatus.refresh(it) }
    # Everything above would wait from now, in project order. Wait from when each crossed the threshold instead, so
    # the queue is worked oldest first, as it would have been had journal review been running.
    crossed = Journal.kept.written_here.where(project_id: ids)
      .select("project_id, created_at, SUM(duration_minutes) OVER (PARTITION BY project_id ORDER BY created_at, id) AS running")
    at = Journal.from(crossed, :journals).where("running >= ?", ProgressStatus::FIRST_AT_MINUTES).group(:project_id).minimum(:created_at)
    ProgressStatus.queued.where(due_reason: "first", project_id: at.keys).find_each { it.update_columns(due_since: at[it.project_id]) }
    puts "#{ProgressStatus.queued.count} projects waiting for journal review"
  end
end
