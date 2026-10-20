<script lang="ts">
  import { router } from '@inertiajs/svelte'
  import Play from '@lucide/svelte/icons/play'
  import { Badge } from '@/components/admin/ui/badge'
  import { Button } from '@/components/admin/ui/button'
  import * as Table from '@/components/admin/ui/table'
  import { formatDateTime, timeAgo, timeFromNow } from '@/lib/format'
  import { JOB_RELOAD, type RecurringTask } from '@/lib/jobs'
  import { runAdminRecurringTask } from '@/routes'

  let { tasks }: { tasks: RecurringTask[] } = $props()

  let busy = $state<string | null>(null)

  function run(task: RecurringTask) {
    router.post(
      runAdminRecurringTask(task.key),
      {},
      {
        preserveScroll: true,
        preserveState: true,
        only: JOB_RELOAD,
        onStart: () => (busy = task.key),
        onFinish: () => (busy = null),
      },
    )
  }
</script>

<div class="overflow-x-auto rounded-md border border-border">
  <Table.Root>
    <Table.Header>
      <Table.Row>
        <Table.Head>Task</Table.Head>
        <Table.Head>Schedule</Table.Head>
        <Table.Head>Last run</Table.Head>
        <Table.Head>Next run</Table.Head>
        <Table.Head></Table.Head>
      </Table.Row>
    </Table.Header>
    <Table.Body>
      {#each tasks as task, i (task.key)}
        <Table.Row class="t-row-enter" style="animation-delay: {Math.min(i, 10) * 20}ms">
          <Table.Cell class="max-w-[24rem]">
            <span class="flex items-center gap-1.5">
              <span class="font-mono text-xs font-medium">{task.key}</span>
              {#if task.queue}<Badge variant="secondary" class="text-[10px]">{task.queue}</Badge>{/if}
            </span>
            <span class="block truncate font-mono text-[11px] text-muted-foreground" title={task.job}
              >{task.job}</span
            >
          </Table.Cell>
          <Table.Cell class="text-sm">{task.schedule}</Table.Cell>
          <Table.Cell class="text-sm text-muted-foreground" title={formatDateTime(task.last_run_at)}>
            {task.last_run_at ? timeAgo(task.last_run_at) : 'never'}
          </Table.Cell>
          <Table.Cell class="text-sm" title={formatDateTime(task.next_run_at)}
            >{timeFromNow(task.next_run_at)}</Table.Cell
          >
          <Table.Cell class="text-right">
            <Button variant="outline" size="sm" disabled={busy === task.key} onclick={() => run(task)}>
              <Play data-icon="inline-start" /> Run now
            </Button>
          </Table.Cell>
        </Table.Row>
      {:else}
        <Table.Row>
          <Table.Cell colspan={5} class="h-24 text-center text-muted-foreground">
            No recurring tasks. They're loaded from config/recurring.yml when the scheduler starts.
          </Table.Cell>
        </Table.Row>
      {/each}
    </Table.Body>
  </Table.Root>
</div>
