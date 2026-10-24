<script lang="ts" module>
  export { default as layout } from '@/layouts/AdminLayout.svelte'
</script>

<script lang="ts">
  import { Deferred, router } from '@inertiajs/svelte'
  import LoaderCircle from '@lucide/svelte/icons/loader-circle'
  import StatTile from '@/components/admin/StatTile.svelte'
  import TimeSeriesChart from '@/components/admin/TimeSeriesChart.svelte'
  import * as Card from '@/components/admin/ui/card'
  import { Skeleton } from '@/components/admin/ui/skeleton'
  import * as ToggleGroup from '@/components/admin/ui/toggle-group'
  import { formatCount } from '@/lib/format'
  import { adminStats } from '@/routes'

  type Day = {
    date: string
    visitors: number
    builders: number
    tracked_minutes: number
    logged_minutes: number
    signups: number
  }
  type Totals = Omit<Day, 'date'>
  type Writing = {
    days: { date: string; checked: number; flagged: number }[]
    totals: {
      checked: number
      flagged: number
      posted_anyway: number
      insisted: number
      skipped: number
      failed: number
      limited: number
      cost_cents: number
    }
  }

  let {
    range,
    ranges,
    active,
    daily,
    funnel,
    writing,
  }: {
    range: string
    ranges: string[]
    active?: { day: number; week: number; month: number }
    daily?: { days: Day[]; totals: Totals }
    funnel?: { key: string; label: string; count: number }[]
    writing?: Writing
  } = $props()

  const RANGE_LABELS: Record<string, string> = {
    '7d': 'last 7 days',
    '30d': 'last 30 days',
    '90d': 'last 90 days',
    all: 'whole program',
  }

  let loading = $state(false)

  function visit(next: string) {
    router.visit(adminStats.show({ query: next === '30d' ? {} : { range: next } }).url, {
      preserveState: true,
      preserveScroll: true,
      onStart: () => (loading = true),
      onFinish: () => (loading = false),
    })
  }

  const hours = (minutes: number) => `${formatCount(Math.round(minutes / 6) / 10)}h`
  const percent = (part: number, whole: number) => (whole ? `${Math.round((part / whole) * 100)}%` : '–')

  const totals = $derived(daily?.totals)
  // Days are UTC dates; drawn at local midnight so the axis shows the same date.
  const points = $derived((daily?.days ?? []).map((day) => ({ ...day, at: `${day.date}T00:00:00` })))

  const nowTiles = $derived([
    {
      label: 'Daily active builders',
      value: active?.day,
      hint: 'tracked time or journaled in the last 24 hours',
    },
    { label: 'Weekly active builders', value: active?.week, hint: 'in the last 7 days' },
    { label: 'Monthly active builders', value: active?.month, hint: 'in the last 30 days' },
    {
      label: 'Stickiness',
      value: active && percent(active.day, active.month),
      hint: 'daily active builders over monthly',
    },
  ])

  const rangeTiles = $derived([
    {
      label: 'Hours tracked',
      value: totals && hours(totals.tracked_minutes),
      hint: 'huddle and timer, overlaps once',
    },
    {
      label: 'Hours logged',
      value: totals && hours(totals.logged_minutes),
      hint: totals && `${percent(totals.logged_minutes, totals.tracked_minutes)} of tracked, in journals`,
    },
    {
      label: 'Builders',
      value: totals?.builders,
      hint:
        totals &&
        `tracked time or journaled, ${totals.builders ? hours(totals.tracked_minutes / totals.builders) : '0h'} tracked each`,
    },
    { label: 'Visitors', value: totals?.visitors, hint: 'opened the site at least once' },
    { label: 'Signups', value: totals?.signups, hint: 'accounts made' },
  ])

  const start = $derived(funnel?.[0]?.count ?? 0)

  const ai = $derived(writing?.totals)
  const aiPoints = $derived((writing?.days ?? []).map((day) => ({ ...day, at: `${day.date}T00:00:00` })))
  const aiTiles = $derived([
    {
      label: 'Checked',
      value: ai?.checked,
      hint: ai && `${ai.skipped} too short, ${ai.limited} over the daily limit, ${ai.failed} failed`,
    },
    { label: 'Flagged', value: ai?.flagged, hint: ai && `${percent(ai.flagged, ai.checked)} of checked` },
    {
      label: 'Posted anyway',
      value: ai?.posted_anyway,
      hint: ai && `${ai.insisted} held “I wrote this myself”, the rest never saw it`,
    },
    {
      label: 'Pangram cost',
      value: ai && `$${(ai.cost_cents / 100).toFixed(2)}`,
      hint: '5¢ per 100 words sent',
    },
  ])
</script>

<svelte:head><title>Stats · Fallen Admin</title></svelte:head>

<div class="mb-5 flex flex-wrap items-start gap-3">
  <div class="min-w-0 basis-full sm:basis-0 sm:flex-1">
    <h1 class="flex items-center gap-2 text-2xl font-semibold tracking-tight">
      Stats
      {#if loading}<LoaderCircle class="size-4 animate-spin text-muted-foreground" />{/if}
    </h1>
    <p class="text-sm text-muted-foreground">
      Who is building and how much, over the {RANGE_LABELS[range]}. Days are UTC.
    </p>
  </div>
  <ToggleGroup.Root
    type="single"
    variant="outline"
    size="sm"
    value={range}
    onValueChange={(value) => value && visit(value)}
  >
    {#each ranges as option (option)}
      <ToggleGroup.Item value={option} class="px-3 tabular-nums">{option}</ToggleGroup.Item>
    {/each}
  </ToggleGroup.Root>
</div>

<div class="grid grid-cols-2 gap-3 lg:grid-cols-4">
  {#each nowTiles as tile (tile.label)}
    <StatTile label={tile.label} value={tile.value} hint={tile.hint} />
  {/each}
</div>

<div class="mt-3 grid grid-cols-2 gap-3 sm:grid-cols-3 xl:grid-cols-5">
  {#each rangeTiles as tile (tile.label)}
    <StatTile label={tile.label} value={tile.value} hint={tile.hint} />
  {/each}
</div>

<div class="mt-4 grid gap-4 lg:grid-cols-2">
  <Card.Root>
    <Card.Header>
      <Card.Title>Hours</Card.Title>
      <Card.Description>Tracked by the huddle and timer, and logged in journals</Card.Description>
    </Card.Header>
    <Card.Content>
      <Deferred data="daily">
        {#snippet fallback()}<Skeleton class="h-[220px] w-full" />{/snippet}
        <TimeSeriesChart
          {points}
          format={hours}
          series={[
            { key: 'tracked_minutes', label: 'Tracked', color: 'var(--chart-1)' },
            { key: 'logged_minutes', label: 'Logged', color: 'var(--chart-2)' },
          ]}
        />
      </Deferred>
    </Card.Content>
  </Card.Root>
  <Card.Root>
    <Card.Header>
      <Card.Title>Active people</Card.Title>
      <Card.Description>
        Opened the site, and tracked time or journaled. Site visits are counted from Oct 21, 2026.
      </Card.Description>
    </Card.Header>
    <Card.Content>
      <Deferred data="daily">
        {#snippet fallback()}<Skeleton class="h-[220px] w-full" />{/snippet}
        <TimeSeriesChart
          kind="line"
          {points}
          format={(value) => formatCount(Math.round(value))}
          series={[
            { key: 'visitors', label: 'Visitors', color: 'var(--chart-3)' },
            { key: 'builders', label: 'Builders', color: 'var(--chart-1)' },
          ]}
        />
      </Deferred>
    </Card.Content>
  </Card.Root>
</div>

<div class="mt-4 grid gap-4 lg:grid-cols-3">
  <Card.Root class="lg:col-span-2">
    <Card.Header>
      <Card.Title>Funnel</Card.Title>
      <Card.Description>
        People who signed up in the {RANGE_LABELS[range]}, banned accounts left out. Each step counts those
        who also made every step above it.
      </Card.Description>
    </Card.Header>
    <Card.Content>
      <Deferred data="funnel">
        {#snippet fallback()}
          <div class="space-y-3">
            {#each { length: 9 }, i (i)}<Skeleton class="h-8 w-full" />{/each}
          </div>
        {/snippet}
        <ol class="space-y-2.5">
          {#each funnel ?? [] as step, i (step.key)}
            {@const previous = i > 0 ? funnel![i - 1].count : step.count}
            <li class="grid grid-cols-[minmax(0,14rem)_1fr_auto] items-center gap-3 text-sm">
              <span class="truncate text-muted-foreground" title={step.label}>{step.label}</span>
              <div class="h-6 overflow-hidden rounded bg-muted">
                <div
                  class="h-full rounded bg-chart-1 transition-[width] duration-500"
                  style="width: {start ? (step.count / start) * 100 : 0}%"
                ></div>
              </div>
              <span class="w-28 text-right tabular-nums">
                <span class="font-medium">{formatCount(step.count)}</span>
                <span class="text-muted-foreground">
                  · {i === 0 ? '100%' : percent(step.count, previous)}
                </span>
              </span>
            </li>
          {/each}
        </ol>
        <p class="mt-3 text-xs text-muted-foreground">
          The percentage is of the step before, so the biggest drop is where people get stuck.
        </p>
      </Deferred>
    </Card.Content>
  </Card.Root>
  <Card.Root>
    <Card.Header>
      <Card.Title>Signups</Card.Title>
      <Card.Description>Accounts made a day</Card.Description>
    </Card.Header>
    <Card.Content>
      <Deferred data="daily">
        {#snippet fallback()}<Skeleton class="h-[220px] w-full" />{/snippet}
        <TimeSeriesChart
          {points}
          format={(value) => formatCount(Math.round(value))}
          series={[{ key: 'signups', label: 'Signups', color: 'var(--chart-2)' }]}
        />
      </Deferred>
    </Card.Content>
  </Card.Root>
</div>

<Card.Root class="mt-4">
  <Card.Header>
    <Card.Title>AI writing check</Card.Title>
    <Card.Description>
      Journals Pangram read before posting, in the {RANGE_LABELS[range]}. Flagged ones also go to
      #fallen-ai-flags.
    </Card.Description>
  </Card.Header>
  <Card.Content>
    <div class="grid grid-cols-2 gap-3 lg:grid-cols-4">
      {#each aiTiles as tile (tile.label)}
        <StatTile label={tile.label} value={tile.value} hint={tile.hint} />
      {/each}
    </div>
    <div class="mt-4">
      <Deferred data="writing">
        {#snippet fallback()}<Skeleton class="h-[220px] w-full" />{/snippet}
        <TimeSeriesChart
          points={aiPoints}
          format={(value) => formatCount(Math.round(value))}
          series={[
            { key: 'checked', label: 'Checked', color: 'var(--chart-1)' },
            { key: 'flagged', label: 'Flagged', color: 'var(--chart-4)' },
          ]}
        />
      </Deferred>
    </div>
  </Card.Content>
</Card.Root>
