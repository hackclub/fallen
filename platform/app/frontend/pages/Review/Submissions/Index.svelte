<script lang="ts" module>
  export { default as layout } from '@/layouts/AdminLayout.svelte'
</script>

<script lang="ts">
  import Link from '@/components/Link.svelte'
  import type { ColumnDef } from '@tanstack/table-core'
  import Play from '@lucide/svelte/icons/play'
  import DataTable from '@/components/admin/DataTable.svelte'
  import DataTableSkeleton from '@/components/admin/DataTableSkeleton.svelte'
  import LinkTabs from '@/components/admin/LinkTabs.svelte'
  import Morph from '@/components/admin/Morph.svelte'
  import { Button } from '@/components/admin/ui/button'
  import { renderComponent } from '@/components/admin/ui/data-table'
  import Deferred from '@/components/Deferred.svelte'
  import PersonChip from '@/components/review/PersonChip.svelte'
  import QueueProjectCell from '@/components/review/QueueProjectCell.svelte'
  import StatusBadge from '@/components/review/StatusBadge.svelte'
  import { timeAgo } from '@/lib/format'
  import { money } from '@/lib/submission'
  import { adminSignOffs, reviewNext, reviewSubmissions } from '@/routes'
  import { shared } from '@/lib/shared.svelte'
  import type { Pagy, ReviewQueueRow } from '@/types'

  let {
    submissions,
    pagy,
    counts,
    tab,
  }: {
    submissions?: ReviewQueueRow[]
    pagy?: Pagy
    counts?: {
      queue: number
      sign_off: number
      flagged: number
      mine: number
      decided: number
      oldest: string | null
    }
    tab: string
  } = $props()

  const tabs = [
    { value: 'queue', label: 'Queue' },
    { value: 'sign_off', label: 'Awaiting sign-off' },
    { value: 'mine', label: 'My reviews' },
    { value: 'decided', label: 'All decided' },
    { value: 'flagged', label: 'Flagged' },
  ].map((t) => ({
    ...t,
    href: reviewSubmissions.reviewRoot({ query: t.value === 'queue' ? {} : { tab: t.value } }).url,
  }))

  const columns: ColumnDef<ReviewQueueRow>[] = $derived([
    {
      id: 'project',
      header: 'Project',
      cell: ({ row }) => renderComponent(QueueProjectCell, { row: row.original }),
    },
    {
      id: 'submitter',
      header: 'Submitted by',
      cell: ({ row }) => renderComponent(PersonChip, { person: row.original.submitter }),
    },
    { id: 'asked', header: 'Asked for', cell: ({ row }) => money(row.original.requested_cents) },
    tab === 'queue' || tab === 'flagged' || tab === 'sign_off'
      ? {
          id: 'waiting',
          header: 'Waiting',
          cell: ({ row }) =>
            timeAgo(tab === 'sign_off' ? row.original.proposed_at! : row.original.created_at),
        }
      : {
          id: 'funded',
          header: 'Funded',
          cell: ({ row }) => (row.original.approved_cents == null ? '—' : money(row.original.approved_cents)),
        },
    tab === 'queue'
      ? {
          id: 'claimed',
          header: 'Being reviewed by',
          // Someone working on it now, else the reviewer it was sent back to: it's still theirs.
          cell: ({ row }) =>
            row.original.claimed_by &&
            row.original.claim_expires_at &&
            new Date(row.original.claim_expires_at) > new Date()
              ? renderComponent(PersonChip, { person: row.original.claimed_by })
              : row.original.sent_back_to
                ? renderComponent(PersonChip, { person: row.original.sent_back_to })
                : '',
        }
      : tab === 'sign_off'
        ? {
            id: 'proposed_by',
            header: 'Proposed by',
            cell: ({ row }) =>
              row.original.proposed_by
                ? renderComponent(PersonChip, { person: row.original.proposed_by })
                : '',
          }
        : {
            id: 'reviewer',
            header: 'Reviewer',
            cell: ({ row }) =>
              row.original.reviewer ? renderComponent(PersonChip, { person: row.original.reviewer }) : '',
          },
    {
      id: 'status',
      header: tab === 'queue' || tab === 'sign_off' ? '' : 'Decision',
      cell: ({ row }) =>
        tab === 'queue' || tab === 'sign_off'
          ? ''
          : renderComponent(StatusBadge, { status: row.original.status }),
    },
  ])
</script>

<svelte:head><title>Design review · Fallen Admin</title></svelte:head>

<div>
  <div class="mb-6 flex flex-wrap items-end gap-4">
    <div class="min-w-0 flex-1">
      <h1 class="text-2xl font-semibold tracking-tight">Design review</h1>
      <p class="text-sm text-muted-foreground">
        {#if counts}
          {counts.queue} waiting{#if counts.oldest}, the oldest for {timeAgo(counts.oldest).replace(
              ' ago',
              '',
            )}{/if}.
        {:else}
          &nbsp;
        {/if}
      </p>
    </div>
    {#if tab === 'sign_off' && shared().auth.user?.is_admin}
      <Button size="lg" href={adminSignOffs.index().url} class="px-4">
        <Play data-icon="inline-start" /> Sign off
      </Button>
    {:else}
      <Button size="lg" href={reviewNext().url} class="px-4">
        <Play data-icon="inline-start" /> Start reviewing
      </Button>
    {/if}
  </div>

  <LinkTabs {tabs} active={tab} class="mb-4">
    {#snippet badge(value)}
      {@const count = counts?.[value as 'queue' | 'sign_off' | 'flagged' | 'mine']}
      {#if count && value !== 'decided'}
        <span
          class={[
            'rounded-full px-1.5 py-0.5 text-[10px] leading-none font-medium tabular-nums',
            value === 'queue'
              ? 'bg-primary text-primary-foreground'
              : value === 'flagged'
                ? 'bg-red-500 text-white'
                : value === 'sign_off'
                  ? 'bg-sky-100 text-sky-800 dark:bg-sky-950 dark:text-sky-300'
                  : 'bg-muted text-muted-foreground',
          ]}><Morph text={count} /></span
        >
      {/if}
    {/snippet}
  </LinkTabs>

  <Deferred data={['submissions', 'pagy']}>
    {#snippet fallback()}
      <DataTableSkeleton
        headers={['Project', 'Submitted by', 'Asked for', 'Waiting', 'Reviewer', 'Decision']}
      />
    {/snippet}
    <DataTable {columns} data={submissions ?? []} {pagy} noun="submissions" />
  </Deferred>

  <p class="mt-6 text-xs text-muted-foreground">
    Reviews go oldest first. <Link href={reviewNext().url} class="underline">Start reviewing</Link> claims the next
    one for you for 15 minutes while the page is open; skipping lets it go.
  </p>
</div>
