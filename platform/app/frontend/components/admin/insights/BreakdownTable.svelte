<script lang="ts">
  import { Link } from '@inertiajs/svelte'
  import ArrowDown from '@lucide/svelte/icons/arrow-down'
  import ArrowUp from '@lucide/svelte/icons/arrow-up'
  import ChevronRight from '@lucide/svelte/icons/chevron-right'
  import SearchIcon from '@lucide/svelte/icons/search'
  import * as InputGroup from '@/components/admin/ui/input-group'
  import * as Table from '@/components/admin/ui/table'
  import { formatCount, formatMs } from '@/lib/format'
  import { latencyTone, toneClass, type InsightsKind, type InsightsRow } from '@/lib/insights'

  // Endpoints or jobs by the time they cost in total. Sorting and filtering happen here: the list is capped.
  let { rows, kind, href }: { rows: InsightsRow[]; kind: InsightsKind; href: (name: string) => string } =
    $props()

  type SortKey = 'name' | 'count' | 'total' | 'p50' | 'p95' | 'max' | 'errors' | 'queue_p95'
  let sortKey = $state<SortKey>('total')
  let descending = $state(true)
  let filter = $state('')

  const grandTotal = $derived(rows.reduce((sum, row) => sum + row.total, 0) || 1)
  const visible = $derived.by(() => {
    const needle = filter.trim().toLowerCase()
    const matching = needle ? rows.filter((row) => row.name.toLowerCase().includes(needle)) : rows
    return [...matching].sort((a, b) => {
      const order =
        sortKey === 'name' ? a.name.localeCompare(b.name) : (a[sortKey] ?? -1) - (b[sortKey] ?? -1)
      return descending ? -order : order
    })
  })

  const columns = $derived<{ key: SortKey; label: string; title?: string }[]>([
    { key: 'name', label: kind === 'requests' ? 'Endpoint' : 'Job' },
    { key: 'count', label: kind === 'requests' ? 'Requests' : 'Runs' },
    { key: 'total', label: 'Time spent', title: 'Share of all time spent in the range' },
    { key: 'p50', label: 'p50', title: 'Half took less than this' },
    { key: 'p95', label: 'p95', title: '95% took less than this' },
    { key: 'max', label: 'Max' },
    kind === 'requests'
      ? { key: 'errors', label: '5xx', title: 'Server errors' }
      : { key: 'queue_p95', label: 'Wait p95', title: 'Time between being due and starting' },
  ])

  function sortBy(key: SortKey) {
    if (sortKey === key) descending = !descending
    else {
      sortKey = key
      descending = key !== 'name'
    }
  }
</script>

<div class="mb-3 flex items-center gap-2">
  <InputGroup.Root class="max-w-xs">
    <InputGroup.Addon><SearchIcon /></InputGroup.Addon>
    <InputGroup.Input
      type="search"
      bind:value={filter}
      placeholder={kind === 'requests' ? 'Filter endpoints' : 'Filter jobs'}
    />
  </InputGroup.Root>
  <span class="ml-auto text-xs text-muted-foreground">
    {visible.length === rows.length ? `${rows.length} shown` : `${visible.length} of ${rows.length}`}
  </span>
</div>

<div class="overflow-x-auto rounded-md border border-border">
  <Table.Root>
    <Table.Header>
      <Table.Row>
        {#each columns as column (column.key)}
          <Table.Head class={column.key === 'name' ? '' : 'text-right'}>
            <button
              type="button"
              title={column.title}
              class="inline-flex cursor-pointer items-center gap-1 hover:text-foreground"
              onclick={() => sortBy(column.key)}
            >
              {column.label}
              {#if sortKey === column.key}
                {#if descending}<ArrowDown class="size-3" />{:else}<ArrowUp class="size-3" />{/if}
              {/if}
            </button>
          </Table.Head>
        {/each}
        <Table.Head class="w-6"></Table.Head>
      </Table.Row>
    </Table.Header>
    <Table.Body>
      {#each visible as row, i (row.name)}
        {@const share = row.total / grandTotal}
        <Table.Row class="group t-row-enter relative" style="animation-delay: {Math.min(i, 10) * 20}ms">
          <Table.Cell class="max-w-[22rem]">
            <Link
              href={href(row.name)}
              class="block truncate font-mono text-xs font-medium after:absolute after:inset-0"
              title={row.name}
            >
              {row.name}
            </Link>
            {#if row.queue}<span class="text-xs text-muted-foreground">{row.queue}</span>{/if}
          </Table.Cell>
          <Table.Cell class="text-right tabular-nums">{formatCount(row.count)}</Table.Cell>
          <Table.Cell class="text-right tabular-nums">
            <div class="flex items-center justify-end gap-2">
              <span class="text-xs text-muted-foreground">{(share * 100).toFixed(share < 0.1 ? 1 : 0)}%</span>
              <span class="hidden h-1.5 w-16 overflow-hidden rounded-full bg-muted sm:block">
                <span class="block h-full rounded-full bg-chart-1" style="width: {Math.max(share * 100, 2)}%"
                ></span>
              </span>
            </div>
          </Table.Cell>
          <Table.Cell class="text-right tabular-nums">{formatMs(row.p50)}</Table.Cell>
          <Table.Cell class="text-right tabular-nums {toneClass[latencyTone(row.p95)]}"
            >{formatMs(row.p95)}</Table.Cell
          >
          <Table.Cell class="text-right text-muted-foreground tabular-nums">{formatMs(row.max)}</Table.Cell>
          {#if kind === 'requests'}
            <Table.Cell
              class="text-right tabular-nums {row.errors
                ? 'font-medium text-destructive'
                : 'text-muted-foreground'}"
            >
              {row.errors ? formatCount(row.errors) : '—'}
            </Table.Cell>
          {:else}
            <Table.Cell class="text-right text-muted-foreground tabular-nums"
              >{formatMs(row.queue_p95)}</Table.Cell
            >
          {/if}
          <Table.Cell class="text-muted-foreground">
            <ChevronRight class="size-4 opacity-0 transition-opacity group-hover:opacity-100" />
          </Table.Cell>
        </Table.Row>
      {:else}
        <Table.Row>
          <Table.Cell colspan={columns.length + 1} class="h-24 text-center text-muted-foreground">
            Nothing matches “{filter}”.
          </Table.Cell>
        </Table.Row>
      {/each}
    </Table.Body>
  </Table.Root>
</div>
