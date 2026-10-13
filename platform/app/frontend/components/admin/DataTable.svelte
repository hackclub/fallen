<script lang="ts" generics="TData">
  import { router } from '@inertiajs/svelte'
  import ArrowDown from '@lucide/svelte/icons/arrow-down'
  import ArrowUp from '@lucide/svelte/icons/arrow-up'
  import { getCoreRowModel, getSortedRowModel, type ColumnDef, type SortingState } from '@tanstack/table-core'
  import { Button } from '@/components/admin/ui/button'
  import { createSvelteTable, FlexRender } from '@/components/admin/ui/data-table'
  import * as Table from '@/components/admin/ui/table'
  import type { Pagy } from '@/types'

  let {
    columns,
    data,
    pagy,
    noun = 'results',
    rowClass,
  }: {
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    columns: ColumnDef<TData, any>[]
    data: TData[]
    pagy?: Pagy
    noun?: string
    rowClass?: (row: TData) => string | undefined
  } = $props()

  let sorting = $state<SortingState>([])

  // Sorting is client-side, within the current page.
  const table = createSvelteTable({
    get data() {
      return data
    },
    get columns() {
      return columns
    },
    state: {
      get sorting() {
        return sorting
      },
    },
    onSortingChange: (updater) => {
      sorting = typeof updater === 'function' ? updater(sorting) : updater
    },
    getCoreRowModel: getCoreRowModel(),
    getSortedRowModel: getSortedRowModel(),
  })

  const singular = $derived(noun.replace(/s$/, ''))

  function goToPage(pageNumber: number) {
    const url = new URL(window.location.href)
    url.searchParams.set('page', String(pageNumber))
    router.get(url.pathname + url.search, {}, { preserveState: true, preserveScroll: true })
  }
</script>

<div>
  <div class="overflow-hidden rounded-md border border-border">
    <Table.Root>
      <Table.Header>
        {#each table.getHeaderGroups() as headerGroup (headerGroup.id)}
          <Table.Row>
            {#each headerGroup.headers as header (header.id)}
              <Table.Head>
                {#if !header.isPlaceholder}
                  {#if header.column.getCanSort()}
                    <button
                      type="button"
                      class="inline-flex cursor-pointer items-center gap-1 hover:text-foreground"
                      onclick={header.column.getToggleSortingHandler()}
                    >
                      <FlexRender content={header.column.columnDef.header} context={header.getContext()} />
                      {#if header.column.getIsSorted() === 'asc'}<ArrowUp class="size-3" />{/if}
                      {#if header.column.getIsSorted() === 'desc'}<ArrowDown class="size-3" />{/if}
                    </button>
                  {:else}
                    <FlexRender content={header.column.columnDef.header} context={header.getContext()} />
                  {/if}
                {/if}
              </Table.Head>
            {/each}
          </Table.Row>
        {/each}
      </Table.Header>
      <Table.Body>
        {#each table.getRowModel().rows as row, i (row.id)}
          <Table.Row
            class="t-row-enter {rowClass?.(row.original) ?? ''}"
            style="animation-delay: {Math.min(i, 10) * 20}ms"
          >
            {#each row.getVisibleCells() as cell (cell.id)}
              <Table.Cell>
                <FlexRender content={cell.column.columnDef.cell} context={cell.getContext()} />
              </Table.Cell>
            {/each}
          </Table.Row>
        {:else}
          <Table.Row>
            <Table.Cell colspan={columns.length} class="h-24 text-center text-muted-foreground"
              >No {noun}.</Table.Cell
            >
          </Table.Row>
        {/each}
      </Table.Body>
    </Table.Root>
  </div>

  {#if pagy}
    <div class="flex items-center justify-between pt-4 text-sm text-muted-foreground">
      <span>
        {#if pagy.count === 0}
          No {noun}
        {:else if pagy.pages <= 1}
          {pagy.count} {pagy.count === 1 ? singular : noun}
        {:else}
          Showing {(pagy.page - 1) * pagy.limit + 1}–{Math.min(pagy.page * pagy.limit, pagy.count)} of {pagy.count}
          {noun}
        {/if}
      </span>
      {#if pagy.pages > 1}
        <div class="flex items-center gap-2">
          <Button
            variant="outline"
            size="sm"
            disabled={!pagy.prev}
            onclick={() => pagy.prev && goToPage(pagy.prev)}
          >
            Previous
          </Button>
          <span>{pagy.page} / {pagy.pages}</span>
          <Button
            variant="outline"
            size="sm"
            disabled={!pagy.next}
            onclick={() => pagy.next && goToPage(pagy.next)}
          >
            Next
          </Button>
        </div>
      {/if}
    </div>
  {/if}
</div>
