<script lang="ts">
  import { Badge } from '@/components/admin/ui/badge'
  import { formatMs, timeAgo } from '@/lib/format'
  import type { InsightsKind, InsightsSlow } from '@/lib/insights'

  // The slowest single requests or runs in the range, with where the time went.
  let { rows, kind, showName }: { rows: InsightsSlow[]; kind: InsightsKind; showName: boolean } = $props()

  const longest = $derived(Math.max(...rows.map((row) => row.duration), 1))

  function statusVariant(status: number | undefined) {
    if (status == null || status < 400) return 'secondary' as const
    return status >= 500 ? ('destructive' as const) : ('outline' as const)
  }

  // Database and view time as parts of the bar, scaled to the slowest row; the rest is Ruby, network and waiting.
  function parts(row: InsightsSlow) {
    const db = Math.min(row.db_runtime ?? 0, row.duration)
    const view = Math.min(row.view_runtime ?? 0, row.duration - db)
    const scale = (ms: number) => (ms / longest) * 100
    return { db: scale(db), view: scale(view), rest: scale(row.duration - db - view) }
  }
</script>

{#if rows.length === 0}
  <p class="py-6 text-center text-sm text-muted-foreground">Nothing recorded.</p>
{:else}
  <ul class="divide-y divide-border">
    {#each rows as row, i (i)}
      {@const bar = parts(row)}
      <li class="t-row-enter py-2.5" style="animation-delay: {Math.min(i, 10) * 20}ms">
        <div class="flex items-center gap-2 text-sm">
          {#if kind === 'requests'}
            <Badge variant={statusVariant(row.status)} class="font-mono text-[10px]">{row.status}</Badge>
            <span class="min-w-0 flex-1 truncate font-mono text-xs" title={row.path}>
              <span class="text-muted-foreground">{row.http_method}</span>
              {row.path}
            </span>
          {:else}
            <span class="min-w-0 flex-1 truncate font-mono text-xs">{row.name}</span>
            <span class="text-xs text-muted-foreground">waited {formatMs(row.queue_time)}</span>
          {/if}
          <span class="font-mono text-xs font-medium tabular-nums">{formatMs(row.duration)}</span>
        </div>
        <div class="mt-1.5 flex items-center gap-2">
          <div class="flex h-1.5 flex-1 overflow-hidden rounded-full bg-muted/60">
            <span
              class="h-full bg-chart-2"
              style="width: {bar.db}%"
              title="Database {formatMs(row.db_runtime)}"
            ></span>
            {#if kind === 'requests'}
              <span
                class="h-full bg-chart-4"
                style="width: {bar.view}%"
                title="Views {formatMs(row.view_runtime)}"
              ></span>
            {/if}
            <span class="h-full bg-chart-1" style="width: {bar.rest}%"></span>
          </div>
          <span class="w-24 shrink-0 text-right text-[11px] text-muted-foreground"
            >{timeAgo(row.started_at)}</span
          >
        </div>
        {#if showName && kind === 'requests'}
          <p class="mt-1 truncate font-mono text-[11px] text-muted-foreground">{row.name}</p>
        {/if}
      </li>
    {/each}
  </ul>
  <div class="mt-3 flex flex-wrap gap-3 text-[11px] text-muted-foreground">
    <span class="flex items-center gap-1"><span class="size-2 rounded-sm bg-chart-2"></span>Database</span>
    {#if kind === 'requests'}
      <span class="flex items-center gap-1"><span class="size-2 rounded-sm bg-chart-4"></span>Views</span>
    {/if}
    <span class="flex items-center gap-1"
      ><span class="size-2 rounded-sm bg-chart-1"></span>Everything else</span
    >
  </div>
{/if}
