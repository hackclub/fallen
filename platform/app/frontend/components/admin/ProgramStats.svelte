<script lang="ts">
  import { Deferred, router } from '@inertiajs/svelte'
  import LoaderCircle from '@lucide/svelte/icons/loader-circle'
  import FunnelChart from '@/components/admin/FunnelChart.svelte'
  import StatTile from '@/components/admin/StatTile.svelte'
  import TimeSeriesChart from '@/components/admin/TimeSeriesChart.svelte'
  import * as Card from '@/components/admin/ui/card'
  import { Skeleton } from '@/components/admin/ui/skeleton'
  import * as ToggleGroup from '@/components/admin/ui/toggle-group'
  import { formatCount } from '@/lib/format'

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
  type Source = { source: string | null; signups: number; builders: number }

  // The panels of /stats and /admin/stats (ProgramStats). `url` is the page's own URL for a range.
  let {
    range,
    ranges,
    active,
    daily,
    funnel,
    sources,
    writing,
    url,
  }: {
    range: string
    ranges: string[]
    active?: { day: number; week: number; month: number }
    daily?: { days: Day[]; totals: Totals }
    funnel?: { key: string; label: string; count: number }[]
    sources?: Source[]
    writing?: Writing
    url: (range: string) => string
  } = $props()

  let loading = $state(false)

  function visit(next: string) {
    router.visit(url(next), {
      preserveState: true,
      preserveScroll: true,
      onStart: () => (loading = true),
      onFinish: () => (loading = false),
    })
  }

  const hours = (minutes: number) => `${formatCount(Math.round(minutes / 6) / 10)}h`
  const percent = (part: number, whole: number) => (whole ? `${Math.round((part / whole) * 100)}%` : '–')

  const totals = $derived(daily?.totals)
  // Days are dates in New York; drawn at local midnight so the axis shows the same date.
  const points = $derived((daily?.days ?? []).map((day) => ({ ...day, at: `${day.date}T00:00:00` })))

  const nowTiles = $derived([
    { label: 'Active today', value: active?.day },
    { label: 'Active this week', value: active?.week },
    { label: 'Active this month', value: active?.month },
    { label: 'Daily / monthly', value: active && percent(active.day, active.month) },
  ])

  const rangeTiles = $derived([
    { label: 'Hours tracked', value: totals && hours(totals.tracked_minutes) },
    {
      label: 'Hours logged',
      value: totals && hours(totals.logged_minutes),
      hint: totals && `${percent(totals.logged_minutes, totals.tracked_minutes)} of tracked`,
    },
    {
      label: 'Builders',
      value: totals?.builders,
      hint: totals?.builders ? `${hours(totals.tracked_minutes / totals.builders)} each` : undefined,
    },
    { label: 'Visitors', value: totals?.visitors },
    { label: 'Signups', value: totals?.signups },
  ])

  const hourSeries = [
    { key: 'tracked_minutes', label: 'Tracked', color: 'var(--chart-1)' },
    { key: 'logged_minutes', label: 'Logged', color: 'var(--chart-2)' },
  ]
  const peopleSeries = [
    { key: 'visitors', label: 'Visitors', color: 'var(--chart-3)' },
    { key: 'builders', label: 'Builders', color: 'var(--chart-1)' },
  ]
  const aiSeries = [
    { key: 'checked', label: 'Checked', color: 'var(--chart-1)' },
    { key: 'flagged', label: 'Flagged', color: 'var(--chart-4)' },
  ]

  const topSignups = $derived(Math.max(1, ...(sources ?? []).map((row) => row.signups)))

  const ai = $derived(writing?.totals)
  const aiPoints = $derived((writing?.days ?? []).map((day) => ({ ...day, at: `${day.date}T00:00:00` })))
  const aiTiles = $derived([
    {
      label: 'Checked',
      value: ai?.checked,
      hint: ai && `${ai.skipped} too short · ${ai.limited} limited · ${ai.failed} failed`,
    },
    { label: 'Flagged', value: ai?.flagged, hint: ai && percent(ai.flagged, ai.checked) },
    { label: 'Posted anyway', value: ai?.posted_anyway, hint: ai && `${ai.insisted} insisted` },
    { label: 'Pangram cost', value: ai && `$${(ai.cost_cents / 100).toFixed(2)}` },
  ])
</script>

{#snippet titled(title: string, series: { label: string; color: string }[] = [])}
  <Card.Header class="flex flex-wrap items-center gap-x-4 gap-y-1">
    <Card.Title class="flex-1">{title}</Card.Title>
    {#each series as item (item.label)}
      <span class="flex items-center gap-1.5 text-xs text-muted-foreground">
        <span class="size-2 rounded-[2px]" style="background: {item.color}"></span>{item.label}
      </span>
    {/each}
  </Card.Header>
{/snippet}

<div class="mb-5 flex flex-wrap items-center gap-3">
  <h1 class="flex flex-1 items-center gap-2 text-2xl font-semibold tracking-tight">
    Stats
    {#if loading}<LoaderCircle class="size-4 animate-spin text-muted-foreground" />{/if}
  </h1>
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
    <StatTile label={tile.label} value={tile.value} />
  {/each}
</div>

<div class="mt-3 grid grid-cols-2 gap-3 sm:grid-cols-3 xl:grid-cols-5">
  {#each rangeTiles as tile (tile.label)}
    <StatTile label={tile.label} value={tile.value} hint={tile.hint} />
  {/each}
</div>

<div class="mt-4 grid gap-4 lg:grid-cols-2">
  <Card.Root>
    {@render titled('Hours', hourSeries)}
    <Card.Content>
      <Deferred data="daily">
        {#snippet fallback()}<Skeleton class="h-[220px] w-full" />{/snippet}
        <TimeSeriesChart {points} format={hours} series={hourSeries} />
      </Deferred>
    </Card.Content>
  </Card.Root>
  <Card.Root>
    {@render titled('People', peopleSeries)}
    <Card.Content>
      <Deferred data="daily">
        {#snippet fallback()}<Skeleton class="h-[220px] w-full" />{/snippet}
        <TimeSeriesChart
          kind="line"
          {points}
          format={(value) => formatCount(Math.round(value))}
          series={peopleSeries}
        />
      </Deferred>
    </Card.Content>
  </Card.Root>
</div>

<div class="mt-4 grid gap-4 lg:grid-cols-3">
  <Card.Root class="lg:col-span-2">
    {@render titled('Funnel')}
    <Card.Content>
      <Deferred data="funnel">
        {#snippet fallback()}
          <div class="space-y-3">
            {#each { length: 9 }, i (i)}<Skeleton class="h-8 w-full" />{/each}
          </div>
        {/snippet}
        <FunnelChart steps={funnel ?? []} />
      </Deferred>
    </Card.Content>
  </Card.Root>
  <Card.Root>
    {@render titled('Signups')}
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
  {@render titled('Sources')}
  <Card.Content>
    <Deferred data="sources">
      {#snippet fallback()}
        <div class="space-y-2">
          {#each { length: 5 }, i (i)}<Skeleton class="h-6 w-full" />{/each}
        </div>
      {/snippet}
      <table class="w-full text-sm">
        <thead class="text-left text-xs text-muted-foreground">
          <tr>
            <th class="pb-2 font-normal">Source</th>
            <th class="w-1/2 pb-2"></th>
            <th class="pb-2 text-right font-normal">Signups</th>
            <th class="pb-2 pl-4 text-right font-normal">Built</th>
          </tr>
        </thead>
        <tbody class="tabular-nums">
          {#each sources ?? [] as row (row.source)}
            <tr>
              <td class={['truncate py-1 pr-3', row.source || 'text-muted-foreground']}>
                {row.source === null ? 'Other' : row.source || 'Direct'}
              </td>
              <td class="py-1">
                <div
                  class="h-2 rounded-full bg-chart-1"
                  style="width: {(row.signups / topSignups) * 100}%"
                ></div>
              </td>
              <td class="py-1 text-right font-medium">{formatCount(row.signups)}</td>
              <td class="py-1 pl-4 text-right text-muted-foreground">
                {formatCount(row.builders)} · {percent(row.builders, row.signups)}
              </td>
            </tr>
          {/each}
        </tbody>
      </table>
    </Deferred>
  </Card.Content>
</Card.Root>

<Card.Root class="mt-4">
  {@render titled('AI writing check', aiSeries)}
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
          series={aiSeries}
        />
      </Deferred>
    </div>
  </Card.Content>
</Card.Root>
