<script lang="ts" module>
  export { default as layout } from '@/layouts/AdminLayout.svelte'
</script>

<script lang="ts">
  import { Deferred, Link, usePoll } from '@inertiajs/svelte'
  import CircleCheck from '@lucide/svelte/icons/circle-check'
  import Gauge from '@lucide/svelte/icons/gauge'
  import Inbox from '@lucide/svelte/icons/inbox'
  import DataTable from '@/components/admin/DataTable.svelte'
  import DataTableSkeleton from '@/components/admin/DataTableSkeleton.svelte'
  import EmptyState from '@/components/admin/EmptyState.svelte'
  import LinkTabs from '@/components/admin/LinkTabs.svelte'
  import JobsToolbar from '@/components/admin/jobs/JobsToolbar.svelte'
  import QueuesTable from '@/components/admin/jobs/QueuesTable.svelte'
  import RecurringTable from '@/components/admin/jobs/RecurringTable.svelte'
  import WorkersTable from '@/components/admin/jobs/WorkersTable.svelte'
  import { buttonVariants } from '@/components/admin/ui/button'
  import { Label } from '@/components/admin/ui/label'
  import { Switch } from '@/components/admin/ui/switch'
  import { formatCount } from '@/lib/format'
  import {
    JOB_RELOAD,
    JOB_STATUSES,
    jobColumns,
    type JobProcess,
    type JobQueue,
    type JobsView,
    type JobStatus,
    type RecurringTask,
  } from '@/lib/jobs'
  import { adminInsights, adminJobs } from '@/routes'
  import type { AdminJob, Pagy } from '@/types'

  let {
    status,
    queue,
    query,
    counts,
    queue_names,
    jobs,
    pagy,
    queues,
    workers,
    recurring,
  }: {
    status: JobsView
    queue: string
    query: string
    counts?: Record<JobStatus, number>
    queue_names?: string[]
    jobs?: AdminJob[]
    pagy?: Pagy
    queues?: JobQueue[]
    workers?: JobProcess[]
    recurring?: RecurringTask[]
  } = $props()

  const LIVE_KEY = 'admin-jobs-live'
  const tabs = [
    ...JOB_STATUSES.map(({ value, label }) => ({ value, label })),
    'divider' as const,
    { value: 'queues', label: 'Queues' },
    { value: 'workers', label: 'Workers' },
    { value: 'recurring', label: 'Recurring' },
  ].map((tab) =>
    tab === 'divider'
      ? tab
      : { ...tab, href: adminJobs.index({ query: tab.value === 'failed' ? {} : { status: tab.value } }).url },
  )

  const current = $derived(JOB_STATUSES.find((s) => s.value === status))
  const columns = $derived(current ? jobColumns(current.value) : [])
  const filtered = $derived(Boolean(queue || query))

  // Live by default: the page is mostly looked at to watch something happen.
  let live = $state(readLive())
  const poll = usePoll(5_000, { only: JOB_RELOAD }, { autoStart: false })
  $effect(() => {
    if (live) poll.start()
    else poll.stop()
  })

  function readLive() {
    try {
      return localStorage.getItem(LIVE_KEY) !== '0'
    } catch {
      return true
    }
  }

  function setLive(on: boolean) {
    live = on
    try {
      localStorage.setItem(LIVE_KEY, on ? '1' : '0')
    } catch {
      // Private windows can refuse storage; live just won't be remembered.
    }
  }

  function rowClass(job: AdminJob) {
    return job.status === 'failed' ? 'hover:bg-destructive/5' : undefined
  }
</script>

<svelte:head><title>Jobs · Fallen Admin</title></svelte:head>

<div class="mb-5 flex flex-wrap items-start gap-3">
  <div class="min-w-0 basis-full sm:basis-0 sm:flex-1">
    <h1 class="text-2xl font-semibold tracking-tight">Jobs</h1>
    <p class="text-sm text-muted-foreground">Everything Solid Queue is running, waiting on, or gave up on.</p>
  </div>
  <div class="flex items-center gap-3">
    <div class="flex items-center gap-2">
      <Switch id="live" checked={live} onCheckedChange={setLive} />
      <Label for="live" class="text-sm text-muted-foreground">
        {#if live}<span class="mr-0.5 inline-block size-1.5 animate-pulse rounded-full bg-emerald-500"
          ></span>{/if}
        Live
      </Label>
    </div>
    <Link
      href={adminInsights.show({ kind: 'jobs' })}
      class={buttonVariants({ variant: 'outline', size: 'sm' })}
    >
      <Gauge data-icon="inline-start" /> Timings
    </Link>
  </div>
</div>

<LinkTabs {tabs} active={status} class="mb-4">
  {#snippet badge(value)}
    {@const count = counts?.[value as JobStatus]}
    {#if count}
      <span
        class={[
          'rounded-full px-1.5 py-0.5 text-[10px] leading-none font-medium tabular-nums',
          value === 'failed' ? 'bg-destructive text-white' : 'bg-muted text-muted-foreground',
        ]}
      >
        {formatCount(count, { compact: true })}
      </span>
    {/if}
  {/snippet}
</LinkTabs>

{#if current}
  {#key current.value}
    <JobsToolbar
      status={current.value}
      {queue}
      {query}
      queueNames={queue_names ?? []}
      failedCount={counts?.failed}
    />
  {/key}

  <Deferred data={['jobs', 'pagy']}>
    {#snippet fallback()}
      <DataTableSkeleton headers={columns.map((column) => String(column.header ?? ''))} />
    {/snippet}
    {#if (jobs ?? []).length === 0}
      {#if filtered}
        <EmptyState
          icon={Inbox}
          title="No {current.label.toLowerCase()} jobs match"
          description="Try another queue or search."
        >
          <Link href={adminJobs.index({ query: { status } })} class="text-sm text-primary hover:underline">
            Clear filters
          </Link>
        </EmptyState>
      {:else}
        <EmptyState icon={current.value === 'failed' ? CircleCheck : Inbox} title={current.empty} />
      {/if}
    {:else}
      <DataTable {columns} data={jobs ?? []} {pagy} noun="jobs" {rowClass} />
    {/if}
  </Deferred>
{:else if status === 'queues'}
  <Deferred data="queues">
    {#snippet fallback()}<DataTableSkeleton
        headers={['Queue', 'Waiting', 'Oldest waiting', 'State', '']}
      />{/snippet}
    <QueuesTable queues={queues ?? []} />
  </Deferred>
{:else if status === 'workers'}
  <Deferred data="workers">
    {#snippet fallback()}<DataTableSkeleton
        headers={['Process', 'Kind', 'Queues', 'Running', 'Heartbeat']}
      />{/snippet}
    <WorkersTable workers={workers ?? []} />
  </Deferred>
{:else}
  <Deferred data="recurring">
    {#snippet fallback()}<DataTableSkeleton
        headers={['Task', 'Schedule', 'Last run', 'Next run', '']}
      />{/snippet}
    <RecurringTable tasks={recurring ?? []} />
  </Deferred>
{/if}
