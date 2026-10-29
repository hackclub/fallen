<script lang="ts" module>
  export { default as layout } from '@/layouts/AdminLayout.svelte'
</script>

<script lang="ts">
  import { Deferred, Link, router, usePoll } from '@inertiajs/svelte'
  import Trophy from '@lucide/svelte/icons/trophy'
  import LinkTabs from '@/components/admin/LinkTabs.svelte'
  import NumberPopIn from '@/components/admin/NumberPopIn.svelte'
  import TimeSeriesChart from '@/components/admin/TimeSeriesChart.svelte'
  import UserCell from '@/components/admin/UserCell.svelte'
  import * as AlertDialog from '@/components/admin/ui/alert-dialog'
  import { Badge } from '@/components/admin/ui/badge'
  import { Button } from '@/components/admin/ui/button'
  import { Label } from '@/components/admin/ui/label'
  import * as Card from '@/components/admin/ui/card'
  import * as Dialog from '@/components/admin/ui/dialog'
  import { Skeleton } from '@/components/admin/ui/skeleton'
  import { Switch } from '@/components/admin/ui/switch'
  import * as Table from '@/components/admin/ui/table'
  import { formatCount, formatMinutes } from '@/lib/format'
  import { PET_NAMES } from '@/lib/pet.svelte'
  import { adminProject, adminTeams } from '@/routes'
  import type { AdminUser, Pagy } from '@/types'

  type Team = { pet: string; xp: number; transferred: number; contributors: number; paid: number }
  type Leader = { user: AdminUser; pet: string; xp: number; minutes: number }
  type Project = { id: string; title: string; pet: string; xp: number; minutes: number; people: number }
  type Week = { start: string; finish: string; over: boolean }
  type Result = {
    start: string
    xp: Record<string, number>
    transferred: Record<string, number>
    paid: boolean
  }
  type Point = { at: string } & Record<string, number | string>

  let {
    week,
    transfers,
    weeks,
    current,
    over,
    paid,
    win_bonus,
    can,
    history,
    teams,
    timeline,
    overall_timeline,
    leaders,
    projects,
    contributors,
  }: {
    week: { start: string; finish: string }
    transfers: boolean
    weeks: Week[]
    current: boolean
    over: boolean
    paid: boolean
    win_bonus: number
    can: { pay: boolean }
    history?: Result[]
    teams?: Team[]
    timeline?: Point[]
    overall_timeline?: Point[]
    leaders?: Leader[]
    projects?: Project[]
    contributors?: { team: string; people: Leader[]; pagy: Pagy } | null
  } = $props()

  const PETS = Object.keys(PET_NAMES)
  const teamName = (pet: string) => `Team ${PET_NAMES[pet] ?? pet}`
  // The eggs' colours (components/hatch).
  const PET_COLORS: Record<string, string> = { lulu: '#F9AF3F', sami: '#353b7d' }

  let confirming = $state(false)
  let paying = $state(false)
  // The team whose whole list of contributors is open, a page at a time.
  let listed = $state<string | null>(null)
  let listing = $state(false)

  // The week still running updates as people journal; a past week only changes when someone pays it.
  // svelte-ignore state_referenced_locally
  usePoll(
    10_000,
    {
      only: [
        'history',
        'overall_timeline',
        'teams',
        'timeline',
        'leaders',
        'projects',
        'over',
        'paid',
        'can',
      ],
    },
    { autoStart: current },
  )

  // Weeks are calendar dates, not instants: shown as written, whatever the admin's time zone.
  const dayFormatter = new Intl.DateTimeFormat(undefined, { dateStyle: 'medium', timeZone: 'UTC' })
  const day = (iso: string) => dayFormatter.format(new Date(iso))

  // The teams with the most XP, or none when nobody earned any.
  const winners = (xp: Record<string, number>) => {
    const most = Math.max(0, ...Object.values(xp))
    return most > 0 ? PETS.filter((pet) => xp[pet] === most) : []
  }

  // Who wins is always without transfers; the totals shown add them when the switch is on.
  const raced = $derived(teams && Object.fromEntries(teams.map((team) => [team.pet, team.xp])))
  const thisWeek = $derived(
    teams &&
      Object.fromEntries(teams.map((team) => [team.pet, team.xp + (transfers ? team.transferred : 0)])),
  )
  const overall = $derived(
    history &&
      Object.fromEntries(
        PETS.map((pet) => [
          pet,
          history.reduce(
            (sum, row) => sum + (row.xp[pet] ?? 0) + (transfers ? (row.transferred[pet] ?? 0) : 0),
            0,
          ),
        ]),
      ),
  )
  const leading = $derived(raced ? winners(raced) : [])
  const payees = $derived(
    (teams ?? [])
      .filter((team) => leading.includes(team.pet))
      .reduce((sum, team) => sum + team.contributors, 0),
  )
  const series = PETS.map((pet) => ({ key: pet, label: teamName(pet), color: PET_COLORS[pet] }))

  function list(team: string, page = 1) {
    listed = team
    router.reload({
      only: ['contributors'],
      data: { team, page },
      preserveUrl: true,
      onStart: () => (listing = true),
      onFinish: () => (listing = false),
    })
  }

  const showTransfers = (on: boolean) =>
    router.visit(adminTeams.show({ query: { week: week.start, ...(on ? { transfers: 1 } : {}) } }), {
      preserveState: true,
      preserveScroll: true,
    })

  const tabs = $derived(
    weeks.map((row, i) => ({
      value: row.start,
      label: `Week ${i + 1}`,
      href: adminTeams.show({ query: { week: row.start, ...(transfers ? { transfers: 1 } : {}) } }).url,
    })),
  )

  function pay() {
    paying = true
    router.post(
      adminTeams.pay({ query: { week: week.start } }),
      {},
      { preserveScroll: true, onFinish: () => ((paying = false), (confirming = false)) },
    )
  }
</script>

<svelte:head><title>Team stats · Fallen Admin</title></svelte:head>

<div class="mb-4 flex flex-wrap items-start gap-3">
  <h1 class="min-w-0 flex-1 text-2xl font-semibold tracking-tight">Team stats</h1>
  <div class="flex items-center gap-2 self-center">
    <Switch id="transfers" checked={transfers} onCheckedChange={showTransfers} />
    <Label for="transfers" class="text-sm text-muted-foreground">Include transfers</Label>
  </div>
  {#if can.pay && leading.length}
    <AlertDialog.Root bind:open={confirming}>
      <AlertDialog.Trigger>
        {#snippet child({ props })}
          <Button {...props}><Trophy data-icon="inline-start" /> Pay out the win</Button>
        {/snippet}
      </AlertDialog.Trigger>
      <AlertDialog.Content>
        <AlertDialog.Header>
          <AlertDialog.Title>Pay the win for {day(week.start)} – {day(week.finish)}?</AlertDialog.Title>
          <AlertDialog.Description>
            {leading.map(teamName).join(' and ')}
            {leading.length > 1 ? 'tied' : 'won'}: +{win_bonus} XP to {formatCount(payees)}
            {payees === 1 ? 'person' : 'people'}. A week is paid once: XP that lands afterwards can't change
            the winner.
          </AlertDialog.Description>
        </AlertDialog.Header>
        <AlertDialog.Footer>
          <AlertDialog.Cancel>Cancel</AlertDialog.Cancel>
          <AlertDialog.Action onclick={pay} disabled={paying}>Pay out</AlertDialog.Action>
        </AlertDialog.Footer>
      </AlertDialog.Content>
    </AlertDialog.Root>
  {/if}
</div>

<LinkTabs {tabs} active={week.start} class="mb-4">
  {#snippet badge(start)}
    {@const result =
      weeks.find((row) => row.start === start)?.over && history?.find((row) => row.start === start)}
    {#if result}
      {@const won = winners(result.xp)}
      {#if !won.length}
        <Badge variant="outline" class="text-[10px]">No XP</Badge>
      {:else}
        <Badge variant={result.paid ? 'outline' : 'destructive'} class="gap-1 text-[10px]">
          <Trophy class="size-3" />
          {won.map((pet) => PET_NAMES[pet]).join(' & ')}{won.length > 1 ? ' tied' : ''}
          {result.paid ? '· paid' : '· unpaid'}
        </Badge>
      {/if}
    {/if}
  {/snippet}
</LinkTabs>

{#snippet versus(
  title: string,
  hint: string,
  xp: Record<string, number> | undefined,
  points: Point[] | undefined,
  ahead: string[],
)}
  {@const total = xp ? PETS.reduce((sum, pet) => sum + (xp[pet] ?? 0), 0) : 0}
  <Card.Root>
    <Card.Header>
      <Card.Title>{title}</Card.Title>
      <Card.Description>{hint}</Card.Description>
    </Card.Header>
    <Card.Content class="space-y-3">
      <div class="flex items-end justify-between gap-4">
        {#each PETS as pet, i (pet)}
          {@const lead = ahead.includes(pet)}
          <div class={i ? 'text-right' : ''}>
            <p class="flex items-center gap-1.5 text-sm font-medium {i ? 'justify-end' : ''}">
              {#if lead}<Trophy class="size-4 text-emerald-600 dark:text-emerald-400" />{/if}
              {teamName(pet)}
            </p>
            <p
              class="text-3xl font-semibold tabular-nums {lead
                ? 'text-emerald-600 dark:text-emerald-400'
                : ''}"
            >
              {#if xp}<NumberPopIn value={`${formatCount(xp[pet] ?? 0)} XP`} />{:else}<Skeleton
                  class="h-9 w-28"
                />{/if}
            </p>
          </div>
        {/each}
      </div>
      <div class="flex h-3 overflow-hidden rounded-full bg-muted">
        {#if xp && total > 0}
          {#each PETS as pet (pet)}
            <div
              class="h-full transition-[width] duration-700"
              style:width="{((xp[pet] ?? 0) / total) * 100}%"
              style:background-color={PET_COLORS[pet]}
            ></div>
          {/each}
        {/if}
      </div>
      {#if points}
        <TimeSeriesChart
          yAxis={false}
          {points}
          {series}
          kind="line"
          format={(value) => `${formatCount(value)} XP`}
        />
      {:else}
        <Skeleton class="h-[220px] w-full" />
      {/if}
    </Card.Content>
  </Card.Root>
{/snippet}

<div class="grid gap-4 lg:grid-cols-2">
  {@render versus(
    current ? 'This week' : `Week ${weeks.findIndex((row) => row.start === week.start) + 1}`,
    `${day(week.start)} – ${day(week.finish)}${paid ? ', win paid' : ''}`,
    thisWeek,
    timeline,
    leading,
  )}
  {@render versus(
    'Overall',
    'Every week so far, added up',
    overall,
    overall_timeline,
    overall ? winners(overall) : [],
  )}
</div>

{#snippet people(rows: Leader[], offset: number)}
  <Table.Root>
    <Table.Header>
      <Table.Row>
        <Table.Head class="w-10">#</Table.Head>
        <Table.Head>Top contributors</Table.Head>
        <Table.Head class="text-right">XP</Table.Head>
        <Table.Head class="text-right">Hours</Table.Head>
      </Table.Row>
    </Table.Header>
    <Table.Body>
      {#each rows as leader, rank (leader.user.id)}
        <Table.Row>
          <Table.Cell class="text-muted-foreground tabular-nums">{offset + rank + 1}</Table.Cell>
          <Table.Cell><UserCell user={leader.user} /></Table.Cell>
          <Table.Cell class="text-right font-medium tabular-nums">{formatCount(leader.xp)}</Table.Cell>
          <Table.Cell class="text-right tabular-nums">{formatMinutes(leader.minutes)}</Table.Cell>
        </Table.Row>
      {/each}
    </Table.Body>
  </Table.Root>
{/snippet}

{#snippet loading()}
  <div class="space-y-3">
    {#each { length: 5 }, i (i)}<Skeleton class="h-9 w-full" />{/each}
  </div>
{/snippet}

<div class="mt-4 grid gap-4 lg:grid-cols-2">
  {#each PETS as pet (pet)}
    <Card.Root>
      <Card.Header>
        <Card.Title>{teamName(pet)}</Card.Title>
      </Card.Header>
      <Card.Content class="space-y-6">
        <Deferred data="leaders">
          {#snippet fallback()}{@render loading()}{/snippet}
          {@const rows = leaders?.filter((row) => row.pet === pet) ?? []}
          {@const count = teams?.find((team) => team.pet === pet)?.contributors ?? 0}
          {#if rows.length}
            {@render people(rows, 0)}
            {#if count > rows.length}
              <Button variant="outline" size="sm" class="mt-3 w-full" onclick={() => list(pet)}>
                View all {formatCount(count)} contributors
              </Button>
            {/if}
          {:else}
            <p class="py-6 text-center text-sm text-muted-foreground">
              Nobody on this team has earned XP yet.
            </p>
          {/if}
        </Deferred>

        <Deferred data="projects">
          {#snippet fallback()}{@render loading()}{/snippet}
          {@const rows = projects?.filter((row) => row.pet === pet) ?? []}
          {#if rows.length}
            <Table.Root>
              <Table.Header>
                <Table.Row>
                  <Table.Head class="w-10">#</Table.Head>
                  <Table.Head>Top projects</Table.Head>
                  <Table.Head class="text-right">People</Table.Head>
                  <Table.Head class="text-right">XP</Table.Head>
                  <Table.Head class="text-right">Hours</Table.Head>
                </Table.Row>
              </Table.Header>
              <Table.Body>
                {#each rows as project, rank (project.id)}
                  <Table.Row>
                    <Table.Cell class="text-muted-foreground tabular-nums">{rank + 1}</Table.Cell>
                    <Table.Cell>
                      <Link
                        href={adminProject(project.id)}
                        prefetch
                        cacheFor="30s"
                        class="block max-w-xs truncate font-medium hover:underline">{project.title}</Link
                      >
                    </Table.Cell>
                    <Table.Cell class="text-right tabular-nums">{formatCount(project.people)}</Table.Cell>
                    <Table.Cell class="text-right font-medium tabular-nums"
                      >{formatCount(project.xp)}</Table.Cell
                    >
                    <Table.Cell class="text-right tabular-nums">{formatMinutes(project.minutes)}</Table.Cell>
                  </Table.Row>
                {/each}
              </Table.Body>
            </Table.Root>
          {:else}
            <p class="py-6 text-center text-sm text-muted-foreground">No journals on this team yet.</p>
          {/if}
        </Deferred>
      </Card.Content>
    </Card.Root>
  {/each}
</div>

<Dialog.Root open={listed !== null} onOpenChange={(open) => !open && (listed = null)}>
  <Dialog.Content class="max-h-[85vh] overflow-y-auto sm:max-w-2xl">
    <Dialog.Header>
      <Dialog.Title>{listed && teamName(listed)}: every contributor</Dialog.Title>
      <Dialog.Description>{day(week.start)} – {day(week.finish)}</Dialog.Description>
    </Dialog.Header>
    {#if contributors && contributors.team === listed && !listing}
      {@const pagy = contributors.pagy}
      {@render people(contributors.people, (pagy.page - 1) * pagy.limit)}
      {#if pagy.pages > 1}
        <div class="flex items-center justify-between text-sm">
          <Button
            variant="outline"
            size="sm"
            disabled={!pagy.prev}
            onclick={() => pagy.prev && list(contributors.team, pagy.prev)}
          >
            Previous
          </Button>
          <span class="text-muted-foreground"
            >Page {pagy.page} of {pagy.pages} · {formatCount(pagy.count)} people</span
          >
          <Button
            variant="outline"
            size="sm"
            disabled={!pagy.next}
            onclick={() => pagy.next && list(contributors.team, pagy.next)}
          >
            Next
          </Button>
        </div>
      {/if}
    {:else}
      {@render loading()}
    {/if}
  </Dialog.Content>
</Dialog.Root>
