<script lang="ts" module>
  export { default as layout } from '@/layouts/AdminLayout.svelte'
</script>

<script lang="ts">
  import { Deferred, Link, router, usePoll } from '@inertiajs/svelte'
  import ArrowLeft from '@lucide/svelte/icons/arrow-left'
  import Gauge from '@lucide/svelte/icons/gauge'
  import LoaderCircle from '@lucide/svelte/icons/loader-circle'
  import BreakdownTable from '@/components/admin/insights/BreakdownTable.svelte'
  import SlowestList from '@/components/admin/insights/SlowestList.svelte'
  import EmptyState from '@/components/admin/EmptyState.svelte'
  import LinkTabs from '@/components/admin/LinkTabs.svelte'
  import StatTile from '@/components/admin/StatTile.svelte'
  import TimeSeriesChart from '@/components/admin/TimeSeriesChart.svelte'
  import * as Card from '@/components/admin/ui/card'
  import { Label } from '@/components/admin/ui/label'
  import { Skeleton } from '@/components/admin/ui/skeleton'
  import { Switch } from '@/components/admin/ui/switch'
  import * as ToggleGroup from '@/components/admin/ui/toggle-group'
  import { formatCount, formatMs } from '@/lib/format'
  import {
    latencyTone,
    type InsightsKind,
    type InsightsPoint,
    type InsightsRow,
    type InsightsSlow,
    type InsightsSummary,
  } from '@/lib/insights'
  import { adminInsights } from '@/routes'

  let {
    kind,
    range,
    ranges,
    name,
    summary,
    series,
    breakdown,
    slowest,
    statuses,
  }: {
    kind: InsightsKind
    range: string
    ranges: string[]
    name: string | null
    summary?: InsightsSummary
    series?: InsightsPoint[]
    breakdown?: InsightsRow[]
    slowest?: InsightsSlow[]
    statuses?: { status: string; count: number }[]
  } = $props()

  const RANGE_LABELS: Record<string, string> = {
    '1h': 'last hour',
    '24h': 'last 24 hours',
    '7d': 'last 7 days',
    '30d': 'last 30 days',
  }
  const DATA = ['summary', 'series', 'breakdown', 'slowest', 'statuses']

  const requests = $derived(kind === 'requests')
  const noun = $derived(requests ? 'requests' : 'jobs')
  const empty = $derived(summary?.count === 0)
  const errorRate = $derived(summary && summary.count ? ((summary.errors ?? 0) / summary.count) * 100 : 0)

  let loading = $state(false)
  let live = $state(false)
  const poll = usePoll(15_000, { only: DATA }, { autoStart: false })

  function url(next: { kind?: InsightsKind; range?: string; name?: string | null }) {
    const query = { range: next.range ?? range, name: next.name === undefined ? name : next.name }
    return adminInsights.show(
      { kind: next.kind ?? kind },
      { query: query.range === '24h' && !query.name ? {} : query },
    ).url
  }

  function visit(next: Parameters<typeof url>[0]) {
    router.visit(url(next), {
      preserveState: true,
      preserveScroll: true,
      onStart: () => (loading = true),
      onFinish: () => (loading = false),
    })
  }

  function setLive(on: boolean) {
    live = on
    if (on) poll.start()
    else poll.stop()
  }

  const tiles = $derived(
    requests
      ? [
          {
            label: 'Requests',
            value: summary && formatCount(summary.count, { compact: true }),
            hint: summary && `${summary.per_minute} a minute`,
          },
          { label: 'Median', value: summary && formatMs(summary.p50), tone: latencyTone(summary?.p50) },
          { label: 'p95', value: summary && formatMs(summary.p95), tone: latencyTone(summary?.p95) },
          { label: 'p99', value: summary && formatMs(summary.p99), tone: latencyTone(summary?.p99) },
          {
            label: 'Server errors',
            value: summary && `${errorRate.toFixed(errorRate && errorRate < 1 ? 2 : 1)}%`,
            hint: summary && `${formatCount(summary.errors ?? 0)} with a 5xx status`,
            tone: errorRate >= 1 ? ('bad' as const) : errorRate > 0 ? ('warn' as const) : ('good' as const),
          },
          { label: 'Database', value: summary && formatMs(summary.db), hint: 'average a request' },
        ]
      : [
          {
            label: 'Jobs run',
            value: summary && formatCount(summary.count, { compact: true }),
            hint: summary && `${summary.per_minute} a minute`,
          },
          { label: 'Median', value: summary && formatMs(summary.p50) },
          { label: 'p95', value: summary && formatMs(summary.p95) },
          { label: 'Longest', value: summary && formatMs(summary.max) },
          {
            label: 'Wait p95',
            value: summary && formatMs(summary.queue_p95),
            hint: 'from due to started',
            tone: waitTone(summary?.queue_p95),
          },
          { label: 'Database', value: summary && formatMs(summary.db), hint: 'average a run' },
        ],
  )

  // Jobs wait for a free worker, so seconds are normal; half a minute means the queues are backing up.
  function waitTone(ms: number | null | undefined) {
    if (ms == null) return 'default' as const
    return ms >= 30_000 ? ('bad' as const) : ms >= 5_000 ? ('warn' as const) : ('default' as const)
  }

  const statusTotal = $derived((statuses ?? []).reduce((sum, row) => sum + row.count, 0) || 1)
  const STATUS_COLORS: Record<string, string> = {
    '2xx': 'bg-emerald-500',
    '3xx': 'bg-sky-500',
    '4xx': 'bg-amber-500',
    '5xx': 'bg-destructive',
  }
</script>

<svelte:head><title>{name ?? 'Insights'} · Fallen Admin</title></svelte:head>

<div class="mb-5 flex flex-wrap items-start gap-3">
  <div class="min-w-0 basis-full sm:basis-0 sm:flex-1">
    {#if name}
      <Link
        href={url({ name: null })}
        preserveState
        class="mb-1 inline-flex items-center gap-1 text-sm text-muted-foreground hover:text-foreground"
      >
        <ArrowLeft class="size-4" /> All {noun}
      </Link>
      <h1 class="truncate font-mono text-xl font-semibold tracking-tight" title={name}>{name}</h1>
    {:else}
      <h1 class="flex items-center gap-2 text-2xl font-semibold tracking-tight">
        Insights
        {#if loading}<LoaderCircle class="size-4 animate-spin text-muted-foreground" />{/if}
      </h1>
      <p class="text-sm text-muted-foreground">
        How long {noun} take in production, over the {RANGE_LABELS[range]}.
      </p>
    {/if}
  </div>

  <div class="flex flex-wrap items-center gap-3">
    <div class="flex items-center gap-2">
      <Switch id="live" checked={live} onCheckedChange={setLive} />
      <Label for="live" class="text-sm text-muted-foreground">
        {#if live}<span class="mr-0.5 inline-block size-1.5 animate-pulse rounded-full bg-emerald-500"
          ></span>{/if}
        Live
      </Label>
    </div>
    <ToggleGroup.Root
      type="single"
      variant="outline"
      size="sm"
      value={range}
      onValueChange={(value) => value && visit({ range: value })}
    >
      {#each ranges as option (option)}
        <ToggleGroup.Item value={option} class="px-3 tabular-nums">{option}</ToggleGroup.Item>
      {/each}
    </ToggleGroup.Root>
  </div>
</div>

{#if !name}
  <LinkTabs
    class="mb-4"
    active={kind}
    tabs={[
      { value: 'requests', label: 'Requests', href: url({ kind: 'requests', name: null }) },
      { value: 'jobs', label: 'Jobs', href: url({ kind: 'jobs', name: null }) },
    ]}
  />
{/if}

<div class="grid grid-cols-2 gap-3 sm:grid-cols-3 xl:grid-cols-6">
  {#each tiles as tile (tile.label)}
    <StatTile label={tile.label} value={tile.value} hint={tile.hint} tone={tile.tone} />
  {/each}
</div>

{#if empty}
  <EmptyState
    class="mt-4"
    icon={Gauge}
    title="No {noun} recorded in the {RANGE_LABELS[range]}"
    description="Timings are recorded in production only. Try a longer range{name
      ? ', or go back to everything'
      : ''}."
  />
{:else}
  <div class="mt-4 grid gap-4 lg:grid-cols-2">
    <Card.Root>
      <Card.Header>
        <Card.Title>Throughput</Card.Title>
        <Card.Description
          >{requests ? 'Requests, with server errors in red' : 'Jobs finished'}</Card.Description
        >
      </Card.Header>
      <Card.Content>
        <Deferred data="series">
          {#snippet fallback()}<Skeleton class="h-[220px] w-full" />{/snippet}
          <TimeSeriesChart
            points={series ?? []}
            hourly={range === '1h' || range === '24h'}
            format={(value) => formatCount(Math.round(value), { compact: true })}
            series={requests
              ? [
                  { key: 'count', label: 'Requests', color: 'var(--chart-1)' },
                  { key: 'errors', label: '5xx', color: 'var(--destructive)' },
                ]
              : [{ key: 'count', label: 'Jobs', color: 'var(--chart-1)' }]}
          />
        </Deferred>
      </Card.Content>
    </Card.Root>
    <Card.Root>
      <Card.Header>
        <Card.Title>{requests ? 'Response time' : 'Run time'}</Card.Title>
        <Card.Description>Median and 95th percentile</Card.Description>
      </Card.Header>
      <Card.Content>
        <Deferred data="series">
          {#snippet fallback()}<Skeleton class="h-[220px] w-full" />{/snippet}
          <TimeSeriesChart
            kind="line"
            points={series ?? []}
            hourly={range === '1h' || range === '24h'}
            format={formatMs}
            series={[
              { key: 'p50', label: 'Median', color: 'var(--chart-2)' },
              { key: 'p95', label: 'p95', color: 'var(--chart-1)' },
            ]}
          />
        </Deferred>
      </Card.Content>
    </Card.Root>
  </div>

  <div class="mt-4 grid gap-4 xl:grid-cols-3">
    {#if !name}
      <Card.Root class="xl:col-span-2">
        <Card.Header>
          <Card.Title>{requests ? 'Endpoints' : 'Jobs'}</Card.Title>
          <Card.Description>Ordered by total time spent, where a speed-up pays off most.</Card.Description>
        </Card.Header>
        <Card.Content>
          <Deferred data="breakdown">
            {#snippet fallback()}
              <div class="space-y-2">
                {#each { length: 8 }, i (i)}<Skeleton class="h-9 w-full" />{/each}
              </div>
            {/snippet}
            <BreakdownTable rows={breakdown ?? []} {kind} href={(row) => url({ name: row })} />
          </Deferred>
        </Card.Content>
      </Card.Root>
    {/if}

    <div class={['flex flex-col gap-4', name && 'xl:col-span-3 xl:grid xl:grid-cols-3']}>
      {#if requests}
        <Card.Root>
          <Card.Header>
            <Card.Title>Responses</Card.Title>
            <Card.Description>By status</Card.Description>
          </Card.Header>
          <Card.Content>
            <Deferred data="statuses">
              {#snippet fallback()}<Skeleton class="h-12 w-full" />{/snippet}
              <div class="flex h-2.5 overflow-hidden rounded-full bg-muted">
                {#each statuses ?? [] as row (row.status)}
                  <span
                    class="h-full {STATUS_COLORS[row.status] ?? 'bg-muted-foreground'}"
                    style="width: {(row.count / statusTotal) * 100}%"
                  ></span>
                {/each}
              </div>
              <dl class="mt-3 grid grid-cols-2 gap-x-4 gap-y-1.5 text-sm">
                {#each statuses ?? [] as row (row.status)}
                  <div class="flex items-center justify-between gap-2">
                    <dt class="flex items-center gap-1.5 text-muted-foreground">
                      <span class="size-2 rounded-sm {STATUS_COLORS[row.status] ?? 'bg-muted-foreground'}"
                      ></span>
                      {row.status}
                    </dt>
                    <dd class="tabular-nums">{formatCount(row.count)}</dd>
                  </div>
                {/each}
              </dl>
            </Deferred>
          </Card.Content>
        </Card.Root>
      {/if}
      <Card.Root class={name ? 'xl:col-span-2' : ''}>
        <Card.Header>
          <Card.Title>Slowest {requests ? 'requests' : 'runs'}</Card.Title>
          <Card.Description>The {name ? '' : 'single '}longest in the range</Card.Description>
        </Card.Header>
        <Card.Content>
          <Deferred data="slowest">
            {#snippet fallback()}
              <div class="space-y-3">
                {#each { length: 5 }, i (i)}<Skeleton class="h-8 w-full" />{/each}
              </div>
            {/snippet}
            <SlowestList rows={(slowest ?? []).slice(0, name ? 25 : 10)} {kind} showName={!name} />
          </Deferred>
        </Card.Content>
      </Card.Root>
    </div>
  </div>
{/if}
