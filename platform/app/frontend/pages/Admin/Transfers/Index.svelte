<script lang="ts" module>
  export { default as layout } from '@/layouts/AdminLayout.svelte'
</script>

<script lang="ts">
  import { Deferred, router } from '@inertiajs/svelte'
  import type { ColumnDef } from '@tanstack/table-core'
  import RefreshCw from '@lucide/svelte/icons/refresh-cw'
  import DataTable from '@/components/admin/DataTable.svelte'
  import DataTableSkeleton from '@/components/admin/DataTableSkeleton.svelte'
  import LinkTabs from '@/components/admin/LinkTabs.svelte'
  import TransferCell from '@/components/admin/TransferCell.svelte'
  import UserCell from '@/components/admin/UserCell.svelte'
  import { Button } from '@/components/admin/ui/button'
  import { renderComponent } from '@/components/admin/ui/data-table'
  import { formatMinutes, timeAgo } from '@/lib/format'
  import { adminTransfers } from '@/routes'
  import type { AdminProjectTransfer, Pagy } from '@/types'

  let {
    transfers,
    pagy,
    counts,
    status,
    can,
  }: {
    transfers?: AdminProjectTransfer[]
    pagy?: Pagy
    counts?: Record<string, number>
    status: string
    can: { sync: boolean }
  } = $props()

  let syncing = $state(false)

  const tabs = [
    { value: 'pending', label: 'Pending' },
    { value: 'approved', label: 'Approved' },
    { value: 'rejected', label: 'Rejected' },
    { value: 'all', label: 'All' },
  ].map((tab) => ({
    ...tab,
    href: adminTransfers.index({ query: tab.value === 'pending' ? {} : { status: tab.value } }).url,
  }))

  const OWNER_CHECK: Record<string, string> = { matches: 'Slack ID matches', differs: 'Different Slack ID' }

  const columns: ColumnDef<AdminProjectTransfer>[] = $derived([
    {
      accessorKey: 'project_name',
      header: 'Project',
      cell: ({ row }) => renderComponent(TransferCell, { transfer: row.original }),
    },
    {
      id: 'person',
      header: 'Person',
      cell: ({ row }) =>
        row.original.user
          ? renderComponent(UserCell, { user: row.original.user })
          : `${row.original.email} (no account)`,
    },
    {
      accessorKey: 'claimed_minutes',
      header: 'Claimed',
      cell: ({ row }) => formatMinutes(row.original.claimed_minutes),
    },
    {
      accessorKey: 'snapshot_minutes',
      header: 'Logged there',
      cell: ({ row }) =>
        row.original.error
          ? 'Fetch failed'
          : row.original.source
            ? formatMinutes(row.original.snapshot_minutes)
            : '—',
    },
    {
      accessorKey: 'owner_check',
      header: 'Owner',
      cell: ({ row }) => (row.original.owner_check ? OWNER_CHECK[row.original.owner_check] : '—'),
    },
    {
      id: 'decision',
      header: status === 'pending' ? 'Submitted' : 'Decision',
      cell: ({ row }) =>
        row.original.status === 'approved'
          ? `${formatMinutes(row.original.approved_minutes)} · ${row.original.xp} XP`
          : row.original.status === 'rejected'
            ? 'Rejected'
            : timeAgo(row.original.submitted_at),
    },
  ])

  function sync() {
    syncing = true
    router.post(adminTransfers.sync(), {}, { preserveScroll: true, onFinish: () => (syncing = false) })
  }
</script>

<svelte:head><title>Transfers · Fallen Admin</title></svelte:head>

<div class="mb-5 flex flex-wrap items-start gap-3">
  <div class="min-w-0 basis-full sm:basis-0 sm:flex-1">
    <h1 class="text-2xl font-semibold tracking-tight">Transfers</h1>
    <p class="text-sm text-muted-foreground">
      Projects carried over from other Hack Club programs, from the transfer form's Airtable. Pulled every 10
      minutes.
    </p>
  </div>
  {#if can.sync}
    <Button variant="outline" size="sm" onclick={sync} disabled={syncing}>
      <RefreshCw data-icon="inline-start" /> Pull from Airtable
    </Button>
  {/if}
</div>

<LinkTabs {tabs} active={status} class="mb-4">
  {#snippet badge(value)}
    {@const count = value === 'all' ? null : counts?.[value]}
    {#if count}
      <span
        class={[
          'rounded-full px-1.5 py-0.5 text-[10px] leading-none font-medium tabular-nums',
          value === 'pending' ? 'bg-primary text-primary-foreground' : 'bg-muted text-muted-foreground',
        ]}>{count}</span
      >
    {/if}
  {/snippet}
</LinkTabs>

<Deferred data={['transfers', 'pagy']}>
  {#snippet fallback()}
    <DataTableSkeleton headers={['Project', 'Person', 'Claimed', 'Logged there', 'Owner', 'Submitted']} />
  {/snippet}
  <DataTable {columns} data={transfers ?? []} {pagy} noun="transfers" />
</Deferred>
