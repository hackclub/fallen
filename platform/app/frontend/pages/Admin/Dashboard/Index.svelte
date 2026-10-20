<script lang="ts" module>
  export { default as layout } from '@/layouts/AdminLayout.svelte'
</script>

<script lang="ts">
  import { Deferred, Link } from '@inertiajs/svelte'
  import ArrowUpRight from '@lucide/svelte/icons/arrow-up-right'
  import ActivityChart from '@/components/admin/ActivityChart.svelte'
  import NumberPopIn from '@/components/admin/NumberPopIn.svelte'
  import { Badge } from '@/components/admin/ui/badge'
  import { buttonVariants } from '@/components/admin/ui/button'
  import * as Card from '@/components/admin/ui/card'
  import { Skeleton } from '@/components/admin/ui/skeleton'
  import { formatMinutes } from '@/lib/format'
  import { adminInsights, adminJobs, adminProjects, adminUsers } from '@/routes'

  type ActivityPoint = { date: string; minutes: number; signups: number }

  let {
    stats,
    activity,
    slack_configured,
  }: {
    stats?: {
      users: number
      projects: number
      journals: number
      minutes_logged: number
      journals_missing_hours: number
      seen_today: number
    }
    activity?: ActivityPoint[]
    slack_configured: boolean
  } = $props()

  const tiles = $derived([
    { label: 'Users', value: stats?.users, href: adminUsers.index().url },
    { label: 'Projects', value: stats?.projects, href: adminProjects.index().url },
    { label: 'Hours logged', value: stats && formatMinutes(stats.minutes_logged), href: null },
    { label: 'Journals', value: stats?.journals, href: null },
    { label: 'Journals missing hours', value: stats?.journals_missing_hours, href: null },
    { label: 'Seen today', value: stats?.seen_today, href: null },
  ])

  const hours = (minutes: number) => `${Math.round((minutes / 60) * 10) / 10}h`
</script>

<svelte:head><title>Dashboard · Fallen Admin</title></svelte:head>

<h1 class="mb-6 text-2xl font-semibold tracking-tight">Dashboard</h1>

<div class="grid gap-4 sm:grid-cols-2 lg:grid-cols-3 xl:grid-cols-6">
  {#each tiles as tile (tile.label)}
    {#snippet body()}
      <Card.Header>
        <Card.Description class="flex items-center justify-between">
          {tile.label}
          {#if tile.href}<ArrowUpRight class="size-4" />{/if}
        </Card.Description>
        <Card.Title class="text-3xl tabular-nums">
          {#if tile.value === undefined}
            <Skeleton class="h-9 w-16" />
          {:else}
            <NumberPopIn value={tile.value} />
          {/if}
        </Card.Title>
      </Card.Header>
    {/snippet}
    {#if tile.href}
      <Link href={tile.href} prefetch cacheFor="30s" class="block">
        <Card.Root class="t-card-lift h-full">{@render body()}</Card.Root>
      </Link>
    {:else}
      <Card.Root class="h-full">{@render body()}</Card.Root>
    {/if}
  {/each}
</div>

<div class="mt-4 grid gap-4 lg:grid-cols-2">
  {#each [{ title: 'Hours logged', key: 'minutes' as const }, { title: 'Signups', key: 'signups' as const }] as chart (chart.key)}
    <Card.Root>
      <Card.Header>
        <Card.Title>{chart.title}</Card.Title>
        <Card.Description>Last 30 days</Card.Description>
      </Card.Header>
      <Card.Content>
        <Deferred data="activity">
          {#snippet fallback()}<Skeleton class="h-[220px] w-full" />{/snippet}
          {#if chart.key === 'minutes'}
            <ActivityChart
              points={(activity ?? []).map((point) => ({ date: point.date, value: point.minutes }))}
              label="Hours"
              color="var(--chart-1)"
              format={hours}
            />
          {:else}
            <ActivityChart
              points={(activity ?? []).map((point) => ({ date: point.date, value: point.signups }))}
              label="Signups"
              color="var(--chart-2)"
            />
          {/if}
        </Deferred>
      </Card.Content>
    </Card.Root>
  {/each}
</div>

<div class="mt-4 grid gap-4 sm:grid-cols-2">
  <Card.Root>
    <Card.Header>
      <Card.Title>Background jobs</Card.Title>
      <Card.Description>Failed, running and scheduled jobs, the queues and their workers.</Card.Description>
    </Card.Header>
    <Card.Footer class="gap-2">
      <Link href={adminJobs.index()} class={buttonVariants({ variant: 'outline', size: 'sm' })}>
        Open jobs <ArrowUpRight data-icon="inline-end" />
      </Link>
      <Link href={adminInsights.show({})} class={buttonVariants({ variant: 'ghost', size: 'sm' })}>
        Timings
      </Link>
    </Card.Footer>
  </Card.Root>
  <Card.Root>
    <Card.Header>
      <Card.Title class="flex items-center gap-2">
        Slack
        <Badge variant={slack_configured ? 'secondary' : 'destructive'}>
          {slack_configured ? 'Connected' : 'Not configured'}
        </Badge>
      </Card.Title>
      <Card.Description>
        {slack_configured
          ? 'Bot token and signing secret are set.'
          : 'Set SLACK_BOT_TOKEN and SLACK_SIGNING_SECRET.'}
      </Card.Description>
    </Card.Header>
  </Card.Root>
</div>
