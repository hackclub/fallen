<script lang="ts" module>
  export { default as layout } from '@/layouts/AdminLayout.svelte'
</script>

<script lang="ts">
  import Link from '@/components/Link.svelte'
  import type { ColumnDef } from '@tanstack/table-core'
  import DataTable from '@/components/admin/DataTable.svelte'
  import DataTableSkeleton from '@/components/admin/DataTableSkeleton.svelte'
  import GrantActions from '@/components/admin/grants/GrantActions.svelte'
  import HcbGrantActions from '@/components/admin/grants/HcbGrantActions.svelte'
  import HcbGrantLedger from '@/components/admin/grants/HcbGrantLedger.svelte'
  import PayoutStatus from '@/components/admin/grants/PayoutStatus.svelte'
  import LinkTabs from '@/components/admin/LinkTabs.svelte'
  import * as Alert from '@/components/admin/ui/alert'
  import { Button } from '@/components/admin/ui/button'
  import * as Card from '@/components/admin/ui/card'
  import { renderComponent } from '@/components/admin/ui/data-table'
  import Deferred from '@/components/Deferred.svelte'
  import PersonChip from '@/components/review/PersonChip.svelte'
  import { formatDate, formatDateTime, timeAgo } from '@/lib/format'
  import { money } from '@/lib/submission'
  import { router } from '@inertiajs/svelte'
  import {
    adminFlag,
    adminGrants,
    hcbConnectAdminGrants,
    hcbSyncAdminGrants,
    reviewSubmissions,
  } from '@/routes'
  import type { AdminGrantPayout, AdminHcbOrgGrant, Pagy } from '@/types'

  type Ledger = {
    mismatch_count: number
    mismatches: {
      person: { id: string; name: string; avatar: string }
      email: string
      hcb_cents: number
      fallen_cents: number
    }[]
    unmatched_count: number
    hcb_total_cents: number
    hcb_balance_cents: number
    expiring_count: number
  }

  let {
    payouts,
    grants,
    pagy,
    totals,
    ledger,
    tab,
    hcb,
  }: {
    payouts?: AdminGrantPayout[]
    grants?: AdminHcbOrgGrant[]
    pagy?: Pagy
    totals?: { unsent: number; sent: number; unsent_count: number }
    ledger?: Ledger
    tab: string
    hcb: {
      configured: boolean
      connected: boolean
      expires_at: string | null
      connected_by: { name: string; avatar: string } | null
      writes: boolean
      automatic: boolean
      flag: string
      checked_at: string | null
      check_error: string | null
    }
  } = $props()

  const tabs = [
    { value: 'unsent', label: 'To send' },
    { value: 'sent', label: 'Sent' },
    { value: 'all', label: 'All' },
    { value: 'hcb', label: 'On HCB' },
  ].map((t) => ({
    ...t,
    href: adminGrants.index({ query: t.value === 'unsent' ? {} : { tab: t.value } }).url,
  }))

  const canSend = $derived(hcb.configured && hcb.connected)
  const checkNow = () => router.post(hcbSyncAdminGrants().url, {}, { preserveScroll: true })

  const grantColumns: ColumnDef<AdminHcbOrgGrant>[] = [
    {
      id: 'person',
      header: 'To',
      cell: ({ row }) =>
        row.original.person
          ? renderComponent(PersonChip, { person: row.original.person })
          : row.original.email,
    },
    { accessorKey: 'email', header: 'HCB email' },
    { id: 'purpose', header: 'Purpose', cell: ({ row }) => row.original.purpose ?? '' },
    { id: 'given', header: 'Given', cell: ({ row }) => money(row.original.amount_cents) },
    {
      id: 'left',
      header: 'Left',
      cell: ({ row }) => (row.original.balance_cents === null ? '' : money(row.original.balance_cents)),
    },
    {
      id: 'status',
      header: 'Status',
      cell: ({ row }) =>
        row.original.status === 'active' && row.original.expires_on
          ? `active until ${formatDate(row.original.expires_on)}`
          : row.original.status,
    },
    {
      id: 'ledger',
      header: 'Ledger',
      cell: ({ row }) => renderComponent(HcbGrantLedger, { grant: row.original }),
    },
    {
      id: 'actions',
      header: '',
      cell: ({ row }) => renderComponent(HcbGrantActions, { grant: row.original }),
    },
  ]

  const columns: ColumnDef<AdminGrantPayout>[] = $derived([
    {
      id: 'recipient',
      header: 'To',
      cell: ({ row }) => renderComponent(PersonChip, { person: row.original.recipient }),
    },
    { accessorKey: 'email', header: 'HCB email' },
    { id: 'project', header: 'Project', cell: ({ row }) => row.original.project_title },
    { id: 'amount', header: 'Amount', cell: ({ row }) => money(row.original.amount_cents) },
    {
      id: 'status',
      header: 'Status',
      cell: ({ row }) => renderComponent(PayoutStatus, { payout: row.original }),
    },
    {
      id: 'when',
      header: 'When',
      cell: ({ row }) =>
        row.original.sent_at
          ? formatDateTime(row.original.sent_at)
          : `approved ${timeAgo(row.original.created_at)}`,
    },
    {
      id: 'actions',
      header: '',
      cell: ({ row }) => renderComponent(GrantActions, { payout: row.original, canSend }),
    },
  ])
</script>

<svelte:head><title>Grants · Fallen Admin</title></svelte:head>

<div class="mb-5">
  <h1 class="text-2xl font-semibold tracking-tight">Grants</h1>
  <p class="text-sm text-muted-foreground">
    Funding for approved designs, sent as HCB card grants: one card per person, topped up by each approval.
    <Link href={reviewSubmissions.reviewRoot().url} class="underline">Design review queue</Link>
  </p>
</div>

<div class="mb-6 grid gap-4 md:grid-cols-3">
  <Card.Root>
    <Card.Header>
      <Card.Description>HCB</Card.Description>
      <Card.Title class="text-base">
        {#if !hcb.configured}
          Not set up
        {:else if hcb.connected}
          Connected
        {:else}
          Not connected
        {/if}
      </Card.Title>
    </Card.Header>
    <Card.Content class="space-y-2 text-sm text-muted-foreground">
      {#if !hcb.configured}
        <p>Set HCB_CLIENT_ID, HCB_CLIENT_SECRET and HCB_ORGANIZATION_ID.</p>
      {:else if hcb.connected && hcb.connected_by}
        <p>By {hcb.connected_by.name}. The token renews by itself.</p>
      {/if}
      {#if !hcb.writes}
        <p class="text-amber-600">
          Not production: sends are logged, not made. Set HCB_ALLOW_WRITES to send for real.
        </p>
      {/if}
      {#if hcb.configured}
        <Button size="sm" variant="outline" href={hcbConnectAdminGrants().url}
          >{hcb.connected ? 'Reconnect' : 'Connect HCB'}</Button
        >
      {/if}
    </Card.Content>
  </Card.Root>
  <Card.Root>
    <Card.Header>
      <Card.Description>Sending</Card.Description>
      <Card.Title class="text-base">{hcb.automatic ? 'Automatic' : 'By hand'}</Card.Title>
    </Card.Header>
    <Card.Content class="space-y-2 text-sm text-muted-foreground">
      <p>
        {hcb.automatic
          ? 'Each approval is sent as soon as the review is in.'
          : 'Approvals wait here until someone presses Send. Turn on the flag to send them as soon as they’re approved.'}
      </p>
      <Button size="sm" variant="outline" href={adminFlag(hcb.flag).url}>The {hcb.flag} flag</Button>
    </Card.Content>
  </Card.Root>
  <Card.Root>
    <Card.Header>
      <Card.Description>Totals</Card.Description>
      <Card.Title class="font-mono text-base">
        {totals ? money(totals.sent) : '...'}
        <span class="text-sm font-normal text-muted-foreground">sent</span>
      </Card.Title>
    </Card.Header>
    <Card.Content class="text-sm text-muted-foreground">
      {totals ? `${money(totals.unsent)} in ${totals.unsent_count} still to send` : ''}
    </Card.Content>
  </Card.Root>
</div>

{#if hcb.connected}
  <Deferred data="ledger">
    {#snippet fallback()}<div class="mb-6 h-16"></div>{/snippet}
    {#if ledger && (ledger.mismatch_count > 0 || ledger.unmatched_count > 0)}
      <Alert.Root variant="destructive" class="mb-6">
        <Alert.Title>
          {ledger.mismatch_count > 0
            ? `HCB and Fallen disagree about ${ledger.mismatch_count} ${ledger.mismatch_count === 1 ? 'person' : 'people'}`
            : `${ledger.unmatched_count} card ${ledger.unmatched_count === 1 ? 'grant goes' : 'grants go'} to emails no Fallen account has`}
        </Alert.Title>
        <Alert.Description>
          {#if ledger.mismatch_count > 0}
            <p>
              Payouts to these people won't send until it's sorted. Find the grant on HCB that explains the
              difference: mark the payout it belongs to as sent with that grant's id, or mark the grant as not
              design funding.
            </p>
          {/if}
          {#if ledger.unmatched_count > 0}
            <p>
              {ledger.unmatched_count} card {ledger.unmatched_count === 1 ? 'grant goes' : 'grants go'} to emails
              no Fallen account has (On HCB tab). If one is someone's design funding, mark their payout sent with
              its id; if not, mark it not design funding.
            </p>
          {/if}
          {#if ledger.mismatches.length}
            <ul class="mt-2 space-y-1">
              {#each ledger.mismatches as row (row.person.id)}
                <li class="flex flex-wrap items-center gap-2">
                  <PersonChip person={row.person} />
                  <span>{row.email}</span>
                  <span class="font-mono"
                    >HCB {money(row.hcb_cents)}, Fallen sent {money(row.fallen_cents)}</span
                  >
                </li>
              {/each}
            </ul>
          {/if}
        </Alert.Description>
      </Alert.Root>
    {/if}
    <div class="mb-6 flex flex-wrap items-center gap-x-6 gap-y-2 text-sm text-muted-foreground">
      <span
        >HCB check: {hcb.checked_at ? `${timeAgo(hcb.checked_at)}` : 'never run'}{hcb.check_error
          ? ` (last try failed: ${hcb.check_error})`
          : ''}</span
      >
      {#if ledger}
        <span>On HCB: <span class="font-mono">{money(ledger.hcb_total_cents)}</span> given</span>
        <span>Unspent on live cards: <span class="font-mono">{money(ledger.hcb_balance_cents)}</span></span>
        {#if ledger.expiring_count}<span class="text-amber-600"
            >{ledger.expiring_count} with money left expire within a week</span
          >{/if}
      {/if}
      <Button size="sm" variant="outline" onclick={checkNow}>Check HCB now</Button>
    </div>
  </Deferred>
{/if}

<LinkTabs {tabs} active={tab} class="mb-4" />

{#if tab === 'hcb'}
  <Deferred data={['grants', 'pagy']}>
    {#snippet fallback()}
      <DataTableSkeleton headers={['To', 'HCB email', 'Purpose', 'Given', 'Left', 'Status', 'Ledger', '']} />
    {/snippet}
    <DataTable columns={grantColumns} data={grants ?? []} {pagy} noun="card grants" />
  </Deferred>
{:else}
  <Deferred data={['payouts', 'pagy']}>
    {#snippet fallback()}
      <DataTableSkeleton headers={['To', 'HCB email', 'Project', 'Amount', 'Status', 'When', '']} />
    {/snippet}
    <DataTable {columns} data={payouts ?? []} {pagy} noun="payouts" />
  </Deferred>
{/if}
