<script lang="ts" module>
  export { default as layout } from '@/layouts/AdminLayout.svelte'
</script>

<script lang="ts">
  import Medal from '@lucide/svelte/icons/medal'
  import DataTableSkeleton from '@/components/admin/DataTableSkeleton.svelte'
  import EmptyState from '@/components/admin/EmptyState.svelte'
  import LinkTabs from '@/components/admin/LinkTabs.svelte'
  import * as Table from '@/components/admin/ui/table'
  import Deferred from '@/components/Deferred.svelte'
  import Link from '@/components/Link.svelte'
  import { adminReviewLeaderboard, adminUser } from '@/routes'

  type Row = { id: string; name: string; design: number; journal: number }

  let { range, ranges, rows }: { range: string; ranges: string[]; rows?: Row[] } = $props()

  const tabs = $derived(
    ranges.map((r) => ({
      value: r,
      label: r === 'all' ? 'All time' : `Last ${r.replace('d', ' days')}`,
      href: adminReviewLeaderboard.show({ query: r === 'all' ? {} : { range: r } }).url,
    })),
  )
</script>

<svelte:head><title>Review leaderboard · Fallen Admin</title></svelte:head>

<div class="mb-5">
  <h1 class="text-2xl font-semibold tracking-tight">Review leaderboard</h1>
  <p class="text-sm text-muted-foreground">
    Design reviews decided and journal reviews sent, by reviewer. Design reviews signed off by an admin count
    for the reviewer who made them; dismissals aren’t counted.
  </p>
</div>

<LinkTabs {tabs} active={range} class="mb-4" />

<Deferred data="rows">
  {#snippet fallback()}<DataTableSkeleton
      headers={['#', 'Reviewer', 'Design', 'Journal', 'Total']}
    />{/snippet}
  {#if rows?.length}
    <Table.Root>
      <Table.Header>
        <Table.Row>
          <Table.Head class="w-12">#</Table.Head>
          <Table.Head>Reviewer</Table.Head>
          <Table.Head class="text-right">Design</Table.Head>
          <Table.Head class="text-right">Journal</Table.Head>
          <Table.Head class="text-right">Total</Table.Head>
        </Table.Row>
      </Table.Header>
      <Table.Body>
        {#each rows as row, i (row.id)}
          <Table.Row>
            <Table.Cell class="text-muted-foreground tabular-nums">{i + 1}</Table.Cell>
            <Table.Cell>
              <Link href={adminUser(row.id)} class="font-medium hover:underline">{row.name}</Link>
            </Table.Cell>
            <Table.Cell class="text-right tabular-nums">{row.design}</Table.Cell>
            <Table.Cell class="text-right tabular-nums">{row.journal}</Table.Cell>
            <Table.Cell class="text-right font-medium tabular-nums">{row.design + row.journal}</Table.Cell>
          </Table.Row>
        {/each}
      </Table.Body>
    </Table.Root>
  {:else}
    <EmptyState icon={Medal} title="No reviews in this range" />
  {/if}
</Deferred>
