<script lang="ts" module>
  export { default as layout } from '@/layouts/AdminLayout.svelte'
</script>

<script lang="ts">
  import { Deferred, Link } from '@inertiajs/svelte'
  import type { ColumnDef } from '@tanstack/table-core'
  import Megaphone from '@lucide/svelte/icons/megaphone'
  import DataTable from '@/components/admin/DataTable.svelte'
  import DataTableSkeleton from '@/components/admin/DataTableSkeleton.svelte'
  import LinkTabs from '@/components/admin/LinkTabs.svelte'
  import UserCell from '@/components/admin/UserCell.svelte'
  import IncidentDialog from '@/components/admin/streaks/IncidentDialog.svelte'
  import RestoreLink from '@/components/admin/streaks/RestoreLink.svelte'
  import StreakLog from '@/components/admin/streaks/StreakLog.svelte'
  import { Button } from '@/components/admin/ui/button'
  import { renderComponent } from '@/components/admin/ui/data-table'
  import {
    addDays,
    dayLabel,
    describeAdjustment,
    effectChips,
    formatMultiplier,
    plural,
    rangeLabel,
  } from '@/lib/streaks'
  import { timeAgo } from '@/lib/format'
  import { adminStreaks } from '@/routes'
  import type { AdminStreakAdjustment, AdminStreakWeek, Pagy } from '@/types'

  let {
    tab,
    week,
    weeks,
    counts,
    rows,
    pagy,
    can,
  }: {
    tab: 'broken' | 'incidents' | 'log'
    week: string | null
    weeks?: { start: string; count: number }[]
    counts?: { broken: number; incidents: number }
    rows?: (AdminStreakWeek | AdminStreakAdjustment)[]
    pagy?: Pagy
    can: { create: boolean }
  } = $props()

  let creating = $state(false)

  const tabs = [
    { value: 'broken', label: 'Broken weeks' },
    { value: 'incidents', label: 'Incidents' },
    { value: 'log', label: 'Every change' },
  ].map((item) => ({
    ...item,
    href: adminStreaks.index({ query: item.value === 'broken' ? {} : { tab: item.value } }).url,
  }))

  const brokenColumns: ColumnDef<AdminStreakWeek>[] = [
    {
      id: 'person',
      header: 'Person',
      cell: ({ row }) => renderComponent(UserCell, { user: row.original.user }),
    },
    {
      accessorKey: 'start',
      header: 'Week',
      cell: ({ row }) => rangeLabel(row.original.start, addDays(row.original.start, 6)),
    },
    {
      id: 'missed',
      header: 'Missed',
      cell: ({ row }) =>
        `${plural(row.original.missed, 'day')}, ${plural(row.original.freezes_before, 'freeze')} going in`,
    },
    {
      id: 'lost',
      header: 'Lost',
      cell: ({ row }) =>
        `${formatMultiplier(row.original.multiplier_before)} → ${formatMultiplier(row.original.multiplier)}`,
    },
    {
      id: 'restore',
      header: '',
      enableSorting: false,
      cell: ({ row }) => renderComponent(RestoreLink, { userId: row.original.user.id }),
    },
  ]

  const adjustmentColumns: ColumnDef<AdminStreakAdjustment>[] = [
    {
      id: 'what',
      header: 'What',
      cell: ({ row }) =>
        `${describeAdjustment(row.original)}${row.original.discarded_at ? ` (undone by ${row.original.undone_by ?? 'someone'})` : ''}`,
    },
    {
      id: 'who',
      header: 'For',
      cell: ({ row }) =>
        row.original.user ? renderComponent(UserCell, { user: row.original.user }) : 'Everyone',
    },
    { accessorKey: 'reason', header: 'Why' },
    {
      id: 'effect',
      header: 'Changed',
      cell: ({ row }) => effectChips(row.original.effect).join(' · ') || '—',
    },
    {
      id: 'by',
      header: 'By',
      cell: ({ row }) => `${row.original.admin?.name ?? 'Someone'}, ${timeAgo(row.original.created_at)}`,
    },
  ]

  const pageHref = (page: number) =>
    adminStreaks.index({ query: { tab, ...(page > 1 && { page: String(page) }) } }).url
</script>

<svelte:head><title>Streaks · Fallen Admin</title></svelte:head>

<div class="mb-5 flex flex-wrap items-start gap-3">
  <div class="min-w-0 basis-full sm:basis-0 sm:flex-1">
    <h1 class="text-2xl font-semibold tracking-tight">Streaks</h1>
    <p class="text-sm text-muted-foreground">
      Team Sami weeks that broke, newest first. Open someone to excuse their days, give freezes or set their
      streak. An incident excuses days for everyone at once, like a Slack outage.
    </p>
  </div>
  {#if can.create}
    <Button size="sm" onclick={() => (creating = true)}>
      <Megaphone data-icon="inline-start" /> New incident
    </Button>
  {/if}
</div>

<LinkTabs {tabs} active={tab} class="mb-4">
  {#snippet badge(value)}
    {@const count = value === 'broken' ? counts?.broken : value === 'incidents' ? counts?.incidents : null}
    {#if count}
      <span
        class={[
          'rounded-full px-1.5 py-0.5 text-[10px] leading-none font-medium tabular-nums',
          value === 'broken' ? 'bg-primary text-primary-foreground' : 'bg-muted text-muted-foreground',
        ]}>{count}</span
      >
    {/if}
  {/snippet}
</LinkTabs>

{#if tab === 'broken'}
  <Deferred data="weeks">
    {#snippet fallback()}<div class="mb-4 h-7"></div>{/snippet}
    {#if weeks?.length}
      <div class="mb-4 flex flex-wrap gap-1.5">
        {#each [{ start: null, count: null }, ...weeks] as option (option.start ?? 'all')}
          <Link
            href={adminStreaks.index({ query: option.start ? { week: option.start } : {} }).url}
            preserveScroll
            class={[
              'rounded-full border px-3 py-1 text-xs transition-colors',
              week === option.start
                ? 'border-foreground bg-foreground text-background'
                : 'border-border text-muted-foreground hover:text-foreground',
            ]}
          >
            {option.start ? `Week of ${dayLabel(option.start)}` : 'All weeks'}
            {#if option.count}<span class="ml-1 tabular-nums opacity-70">{option.count}</span>{/if}
          </Link>
        {/each}
      </div>
    {/if}
  </Deferred>
  <Deferred data={['rows', 'pagy']}>
    {#snippet fallback()}
      <DataTableSkeleton headers={['Person', 'Week', 'Missed', 'Lost']} />
    {/snippet}
    <DataTable columns={brokenColumns} data={(rows ?? []) as AdminStreakWeek[]} {pagy} noun="broken weeks" />
  </Deferred>
{:else if tab === 'incidents'}
  <Deferred data={['rows', 'pagy']}>
    {#snippet fallback()}
      <DataTableSkeleton headers={['What', 'Why', 'Changed', 'By']} />
    {/snippet}
    <div class="rounded-xl border p-4">
      {#if rows?.length}
        <StreakLog adjustments={rows as AdminStreakAdjustment[]} canUndo={can.create} linkIncidents={false} />
      {:else}
        <p class="text-sm text-muted-foreground">
          No incidents yet. When something on our side stops people journaling, make one for the days it
          covers.
        </p>
      {/if}
    </div>
    {#if pagy && pagy.pages > 1}
      <div class="mt-3 flex justify-end gap-2">
        {#if pagy.prev}<Button variant="outline" size="sm" href={pageHref(pagy.prev)}>Newer</Button>{/if}
        {#if pagy.next}<Button variant="outline" size="sm" href={pageHref(pagy.next)}>Older</Button>{/if}
      </div>
    {/if}
  </Deferred>
{:else}
  <Deferred data={['rows', 'pagy']}>
    {#snippet fallback()}
      <DataTableSkeleton headers={['What', 'For', 'Why', 'Changed', 'By']} />
    {/snippet}
    <DataTable
      columns={adjustmentColumns}
      data={(rows ?? []) as AdminStreakAdjustment[]}
      {pagy}
      noun="changes"
    />
  </Deferred>
{/if}

<IncidentDialog bind:open={creating} />
