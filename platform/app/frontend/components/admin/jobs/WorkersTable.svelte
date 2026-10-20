<script lang="ts">
  import { Badge } from '@/components/admin/ui/badge'
  import * as Table from '@/components/admin/ui/table'
  import { formatDateTime, timeAgo } from '@/lib/format'
  import type { JobProcess } from '@/lib/jobs'

  let { workers }: { workers: JobProcess[] } = $props()
</script>

<div class="overflow-x-auto rounded-md border border-border">
  <Table.Root>
    <Table.Header>
      <Table.Row>
        <Table.Head>Process</Table.Head>
        <Table.Head>Kind</Table.Head>
        <Table.Head>Queues</Table.Head>
        <Table.Head class="text-right">Running</Table.Head>
        <Table.Head>Heartbeat</Table.Head>
      </Table.Row>
    </Table.Header>
    <Table.Body>
      {#each workers as worker, i (worker.name)}
        <Table.Row class="t-row-enter" style="animation-delay: {Math.min(i, 10) * 20}ms">
          <Table.Cell>
            <span class="block font-mono text-xs font-medium">{worker.name}</span>
            <span class="block font-mono text-[11px] text-muted-foreground">
              {worker.hostname ?? 'unknown host'} · pid {worker.pid}
            </span>
          </Table.Cell>
          <Table.Cell><Badge variant="secondary">{worker.kind}</Badge></Table.Cell>
          <Table.Cell class="font-mono text-xs text-muted-foreground">{worker.queues ?? '—'}</Table.Cell>
          <Table.Cell class="text-right tabular-nums">
            {#if worker.threads}{worker.claimed} / {worker.threads}{:else}—{/if}
          </Table.Cell>
          <Table.Cell title={formatDateTime(worker.last_heartbeat_at)}>
            <span class="flex items-center gap-1.5 text-sm">
              <span
                class="size-2 rounded-full {worker.alive ? 'bg-emerald-500' : 'bg-destructive'}"
                aria-label={worker.alive ? 'Alive' : 'Not responding'}
              ></span>
              {timeAgo(worker.last_heartbeat_at)}
            </span>
          </Table.Cell>
        </Table.Row>
      {:else}
        <Table.Row>
          <Table.Cell colspan={5} class="h-24 text-center text-muted-foreground">
            No worker is running. Start one with <code class="font-mono">bin/jobs</code>.
          </Table.Cell>
        </Table.Row>
      {/each}
    </Table.Body>
  </Table.Root>
</div>
