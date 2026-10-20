<script lang="ts" module>
  export { default as layout } from '@/layouts/AdminLayout.svelte'
</script>

<script lang="ts">
  import { Link, usePoll } from '@inertiajs/svelte'
  import ArrowLeft from '@lucide/svelte/icons/arrow-left'
  import Check from '@lucide/svelte/icons/check'
  import Copy from '@lucide/svelte/icons/copy'
  import JobActions from '@/components/admin/jobs/JobActions.svelte'
  import { Badge } from '@/components/admin/ui/badge'
  import { Button } from '@/components/admin/ui/button'
  import * as Card from '@/components/admin/ui/card'
  import { formatDateTime, timeAgo, timeFromNow } from '@/lib/format'
  import { statusLabel, statusVariant, type JobStatus } from '@/lib/jobs'
  import { adminJobs } from '@/routes'
  import type { AdminJobDetail } from '@/types'

  let { job }: { job: AdminJobDetail } = $props()

  // A job that's still moving updates itself; a failed or finished one stays put.
  const moving = $derived(['queued', 'scheduled', 'blocked', 'in_progress'].includes(job.status))
  const poll = usePoll(3_000, { only: ['job'] }, { autoStart: false })
  $effect(() => {
    if (moving) poll.start()
    else poll.stop()
  })

  let copied = $state<string | null>(null)
  let allFrames = $state(false)

  // Lines from this app, not from gems or Ruby, are the ones worth reading first. The serializer makes app paths
  // relative to its root, so they start with its folders.
  const appFrame = (line: string) => /^(app|lib|config|db)\//.test(line)
  const frames = $derived(job.backtrace.map((line, index) => ({ line, index, app: appFrame(line) })))
  const shownFrames = $derived(
    allFrames ? frames : frames.filter((frame, i) => frame.app || i === 0).slice(0, 30),
  )
  const hiddenCount = $derived(frames.length - shownFrames.length)

  const backLink = $derived(
    adminJobs.index({ query: job.status === 'failed' || !job.status ? {} : { status: job.status } }),
  )

  const details = $derived(
    [
      { label: 'Queue', value: job.queue_name, mono: true },
      { label: 'Priority', value: String(job.priority) },
      // Active Job counts the runs before this one.
      { label: 'Attempt', value: String(job.attempts + 1) },
      { label: 'Enqueued', value: formatDateTime(job.created_at), hint: timeAgo(job.created_at) },
      job.scheduled_at && {
        label: job.status === 'scheduled' ? 'Runs' : 'Due',
        value: formatDateTime(job.scheduled_at),
        hint: timeFromNow(job.scheduled_at),
      },
      job.started_at && {
        label: 'Started',
        value: formatDateTime(job.started_at),
        hint: timeAgo(job.started_at),
      },
      job.worker && { label: 'Worker', value: job.worker, mono: true },
      job.failed_at && {
        label: 'Failed',
        value: formatDateTime(job.failed_at),
        hint: timeAgo(job.failed_at),
      },
      job.finished_at && {
        label: 'Finished',
        value: formatDateTime(job.finished_at),
        hint: timeAgo(job.finished_at),
      },
      job.recurring_task && { label: 'Recurring task', value: job.recurring_task, mono: true },
      job.concurrency_key && { label: 'Concurrency key', value: job.concurrency_key, mono: true },
      { label: 'Job ID', value: String(job.id), mono: true },
      { label: 'Active Job ID', value: job.active_job_id, mono: true },
    ].filter((detail) => !!detail),
  )

  async function copy(key: string, text: string) {
    await navigator.clipboard.writeText(text)
    copied = key
    setTimeout(() => copied === key && (copied = null), 1500)
  }
</script>

<svelte:head><title>{job.class_name} · Jobs · Fallen Admin</title></svelte:head>

<Link
  href={backLink}
  class="mb-4 inline-flex items-center gap-1 text-sm text-muted-foreground hover:text-foreground"
>
  <ArrowLeft class="size-4" />
  {job.status ? statusLabel(job.status) : 'All'} jobs
</Link>

<div class="flex flex-wrap items-center gap-3">
  <div class="min-w-0">
    <div class="flex flex-wrap items-center gap-2">
      <h1 class="truncate font-mono text-xl font-semibold tracking-tight">{job.class_name}</h1>
      <Badge variant={statusVariant(job.status)}>
        {#if job.status === 'in_progress'}
          <span class="mr-1 inline-block size-1.5 animate-pulse rounded-full bg-current"></span>
        {/if}
        {statusLabel(job.status)}
      </Badge>
    </div>
    <p class="mt-0.5 truncate font-mono text-xs text-muted-foreground">{job.arguments || 'no arguments'}</p>
  </div>
  <div class="ml-auto">
    <JobActions job={{ ...job, status: job.status as JobStatus }} labels />
  </div>
</div>

{#if job.status === 'failed' && job.error}
  <Card.Root class="mt-6 border-destructive/40">
    <Card.Header>
      <Card.Title class="font-mono text-base text-destructive">{job.error.exception_class}</Card.Title>
      <Card.Description class="font-mono text-sm whitespace-pre-wrap text-foreground">
        {job.error_message ?? job.error.message}
      </Card.Description>
      <Card.Action>
        <Button
          variant="ghost"
          size="sm"
          onclick={() =>
            copy('error', `${job.error?.exception_class}: ${job.error_message}\n${job.backtrace.join('\n')}`)}
        >
          {#if copied === 'error'}<Check data-icon="inline-start" /> Copied{:else}<Copy
              data-icon="inline-start"
            /> Copy{/if}
        </Button>
      </Card.Action>
    </Card.Header>
    {#if frames.length}
      <Card.Content>
        <ol
          class="overflow-x-auto rounded-md border border-border bg-muted/40 py-2 font-mono text-[11px] leading-5"
        >
          {#each shownFrames as frame (frame.index)}
            <li
              class={[
                'px-3 whitespace-pre',
                frame.app ? 'text-foreground' : 'text-muted-foreground',
                frame.app && 'bg-destructive/5',
              ]}
            >
              <span class="mr-3 inline-block w-6 text-right text-muted-foreground/60 select-none"
                >{frame.index + 1}</span
              >{frame.line}
            </li>
          {/each}
        </ol>
        {#if hiddenCount > 0 || allFrames}
          <Button variant="link" size="sm" class="mt-1 px-0" onclick={() => (allFrames = !allFrames)}>
            {allFrames ? 'Show only app frames' : `Show ${hiddenCount} more frames from gems and Ruby`}
          </Button>
        {/if}
      </Card.Content>
    {/if}
  </Card.Root>
{/if}

<div class="mt-4 grid gap-4 lg:grid-cols-5">
  <Card.Root class="lg:col-span-2">
    <Card.Header><Card.Title>Details</Card.Title></Card.Header>
    <Card.Content>
      <dl class="grid grid-cols-2 gap-x-6 gap-y-4 text-sm">
        {#each details as detail (detail.label)}
          <div class="min-w-0">
            <dt class="text-muted-foreground">{detail.label}</dt>
            <dd class={['truncate', detail.mono && 'font-mono text-xs leading-5']} title={detail.value}>
              {detail.value}
            </dd>
            {#if 'hint' in detail && detail.hint}<dd class="text-xs text-muted-foreground">
                {detail.hint}
              </dd>{/if}
          </div>
        {/each}
      </dl>
    </Card.Content>
  </Card.Root>

  <Card.Root class="lg:col-span-3">
    <Card.Header>
      <Card.Title>Arguments</Card.Title>
      <Card.Description>Records show as Model#id.</Card.Description>
      <Card.Action>
        <Button variant="ghost" size="sm" onclick={() => copy('arguments', job.arguments_json)}>
          {#if copied === 'arguments'}<Check data-icon="inline-start" /> Copied{:else}<Copy
              data-icon="inline-start"
            /> Copy{/if}
        </Button>
      </Card.Action>
    </Card.Header>
    <Card.Content>
      <pre
        class="max-h-[28rem] overflow-auto rounded-md border border-border bg-muted/40 p-3 font-mono text-xs leading-5">{job.arguments_json}</pre>
    </Card.Content>
  </Card.Root>
</div>
