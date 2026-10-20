<script lang="ts">
  import { Link, router } from '@inertiajs/svelte'
  import Pause from '@lucide/svelte/icons/pause'
  import Play from '@lucide/svelte/icons/play'
  import { Badge } from '@/components/admin/ui/badge'
  import { Button } from '@/components/admin/ui/button'
  import * as Table from '@/components/admin/ui/table'
  import { formatCount, formatSeconds } from '@/lib/format'
  import { JOB_RELOAD, type JobQueue } from '@/lib/jobs'
  import { adminJobQueue, adminJobs } from '@/routes'

  let { queues }: { queues: JobQueue[] } = $props()

  let busy = $state<string | null>(null)

  function setPaused(queue: JobQueue, paused: boolean) {
    router.patch(
      adminJobQueue(queue.name),
      { paused },
      {
        preserveScroll: true,
        preserveState: true,
        only: JOB_RELOAD,
        onStart: () => (busy = queue.name),
        onFinish: () => (busy = null),
      },
    )
  }
</script>

<div class="overflow-x-auto rounded-md border border-border">
  <Table.Root>
    <Table.Header>
      <Table.Row>
        <Table.Head>Queue</Table.Head>
        <Table.Head class="text-right">Waiting</Table.Head>
        <Table.Head class="text-right">Oldest waiting</Table.Head>
        <Table.Head>State</Table.Head>
        <Table.Head></Table.Head>
      </Table.Row>
    </Table.Header>
    <Table.Body>
      {#each queues as queue, i (queue.name)}
        <Table.Row class="t-row-enter" style="animation-delay: {Math.min(i, 10) * 20}ms">
          <Table.Cell>
            <Link
              href={adminJobs.index({ query: { status: 'queued', queue: queue.name } })}
              class="font-mono text-xs font-medium hover:underline"
            >
              {queue.name}
            </Link>
          </Table.Cell>
          <Table.Cell class="text-right tabular-nums">{formatCount(queue.size)}</Table.Cell>
          <Table.Cell
            class="text-right tabular-nums {queue.latency > 300
              ? 'text-destructive'
              : queue.latency > 30
                ? 'text-amber-600 dark:text-amber-400'
                : 'text-muted-foreground'}"
          >
            {queue.size ? formatSeconds(queue.latency) : '—'}
          </Table.Cell>
          <Table.Cell>
            {#if queue.paused}
              <Badge variant="outline" class="border-amber-500/50 text-amber-700 dark:text-amber-400"
                >Paused</Badge
              >
            {:else}
              <Badge variant="secondary">Running</Badge>
            {/if}
          </Table.Cell>
          <Table.Cell class="text-right">
            <Button
              variant="outline"
              size="sm"
              disabled={busy === queue.name}
              onclick={() => setPaused(queue, !queue.paused)}
            >
              {#if queue.paused}<Play data-icon="inline-start" /> Resume{:else}<Pause
                  data-icon="inline-start"
                /> Pause{/if}
            </Button>
          </Table.Cell>
        </Table.Row>
      {:else}
        <Table.Row>
          <Table.Cell colspan={5} class="h-24 text-center text-muted-foreground">No queues yet.</Table.Cell>
        </Table.Row>
      {/each}
    </Table.Body>
  </Table.Root>
</div>
<p class="mt-3 text-xs text-muted-foreground">
  Pausing a queue stops workers from taking its jobs. They wait in the queue until it's resumed.
</p>
