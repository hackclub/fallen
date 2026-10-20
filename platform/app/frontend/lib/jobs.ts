import type { ColumnDef } from '@tanstack/table-core'
import JobActions from '@/components/admin/jobs/JobActions.svelte'
import JobCell from '@/components/admin/jobs/JobCell.svelte'
import JobErrorCell from '@/components/admin/jobs/JobErrorCell.svelte'
import { renderComponent } from '@/components/admin/ui/data-table'
import { timeAgo, timeFromNow } from '@/lib/format'
import type { AdminJob } from '@/types'

// JobBoard::STATUSES, and the tabs /admin/jobs adds for the queues, workers and recurring tasks.
export type JobStatus = 'failed' | 'in_progress' | 'queued' | 'scheduled' | 'blocked' | 'finished'
export type JobsView = JobStatus | 'queues' | 'workers' | 'recurring'

export const JOB_STATUSES: { value: JobStatus; label: string; empty: string }[] = [
  { value: 'failed', label: 'Failed', empty: 'Nothing has failed. Everything that ran, worked.' },
  { value: 'in_progress', label: 'Running', empty: 'No job is running right now.' },
  { value: 'queued', label: 'Queued', empty: 'The queues are empty: workers are keeping up.' },
  { value: 'scheduled', label: 'Scheduled', empty: 'Nothing is scheduled for later.' },
  { value: 'blocked', label: 'Blocked', empty: 'No job is waiting on a concurrency limit.' },
  { value: 'finished', label: 'Finished', empty: 'No finished jobs are kept right now.' },
]

export function statusLabel(status: string | null) {
  return JOB_STATUSES.find((s) => s.value === status)?.label ?? 'Gone'
}

export function statusVariant(status: string | null) {
  if (status === 'failed') return 'destructive' as const
  if (status === 'in_progress') return 'default' as const
  return status === 'finished' ? ('outline' as const) : ('secondary' as const)
}

// What a job action reloads: the table and the tab counts, not the whole page.
export const JOB_RELOAD = ['jobs', 'pagy', 'counts', 'queues', 'workers', 'recurring']

// JobBoard.queues, .processes and .recurring_tasks (app/models/job_board.rb).
export type JobQueue = { name: string; size: number; latency: number; paused: boolean }

export type JobProcess = {
  name: string
  kind: string
  hostname: string | null
  pid: number
  last_heartbeat_at: string
  alive: boolean
  queues: string | null
  threads: number | null
  claimed: number
}

export type RecurringTask = {
  key: string
  schedule: string
  job: string
  queue: string | null
  last_run_at: string | null
  next_run_at: string
}

export function jobColumns(status: JobStatus): ColumnDef<AdminJob>[] {
  const job: ColumnDef<AdminJob> = {
    accessorKey: 'class_name',
    header: 'Job',
    cell: ({ row }) => renderComponent(JobCell, { job: row.original }),
  }
  const queue: ColumnDef<AdminJob> = { accessorKey: 'queue_name', header: 'Queue' }
  const actions: ColumnDef<AdminJob> = {
    id: 'actions',
    header: '',
    enableSorting: false,
    cell: ({ row }) => renderComponent(JobActions, { job: row.original }),
  }
  const at = (key: keyof AdminJob, header: string, format = timeAgo) =>
    ({
      accessorKey: key,
      header,
      cell: ({ row }) => (row.original[key] ? format(row.original[key] as string) : '—'),
    }) satisfies ColumnDef<AdminJob>

  switch (status) {
    case 'failed':
      return [
        job,
        {
          id: 'error',
          header: 'Error',
          enableSorting: false,
          cell: ({ row }) => renderComponent(JobErrorCell, { job: row.original }),
        },
        at('failed_at', 'Failed'),
        actions,
      ]
    case 'in_progress':
      return [job, queue, at('started_at', 'Started'), { accessorKey: 'worker', header: 'Worker' }]
    case 'queued':
      return [
        job,
        queue,
        { accessorKey: 'priority', header: 'Priority' },
        at('created_at', 'Waiting since'),
        actions,
      ]
    case 'scheduled':
      return [job, queue, at('scheduled_at', 'Runs', timeFromNow), actions]
    case 'blocked':
      return [job, queue, at('created_at', 'Enqueued'), actions]
    case 'finished':
      return [job, queue, at('finished_at', 'Finished')]
  }
}
