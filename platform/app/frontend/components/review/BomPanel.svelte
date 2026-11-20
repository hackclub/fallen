<script lang="ts">
  import { Button } from '@/components/admin/ui/button'
  import Morph from '@/components/admin/Morph.svelte'
  import BomLineCard from '@/components/review/BomLineCard.svelte'
  import Segmented from '@/components/review/Segmented.svelte'
  import { reveal } from '@/components/review/motion'
  import {
    itemDecided,
    itemFunded,
    itemRequested,
    RAISED,
    type ItemCall,
    type ItemVerdict,
    type ReviewDraft,
    type ReviewPage,
  } from '@/lib/review.svelte'
  import { money } from '@/lib/submission'

  // The parts list, line by line, and what the funding comes to. Approve funds a line as asked, Lower funds less
  // (how much, and why), Cut funds none of it (why). Lines they already own ask for nothing and need no call.
  let {
    page,
    draft = $bindable(),
    readonly,
    focused = $bindable(),
  }: { page: ReviewPage; draft: ReviewDraft; readonly: boolean; focused: number } = $props()

  let showCsv = $state(false)
  let filter = $state<'all' | 'open' | 'changed'>('all')
  const cards: BomLineCard[] = $state([])
  const EMPTY: ItemCall = { verdict: null, reason: null, cents: null }

  const items = $derived(page.submission.bom_items)
  const requested = $derived(items.reduce((sum, item) => sum + itemRequested(item), 0))
  const funded = $derived(items.reduce((sum, item) => sum + (itemFunded(item, draft.bom[item.id]) ?? 0), 0))
  const decidable = $derived(items.filter((item) => !item.owned))
  const open = $derived(decidable.filter((item) => !itemDecided(item, draft.bom[item.id])).length)
  const carried = $derived(decidable.filter((item) => draft.bom[item.id]?.carried).length)
  const counts = $derived({
    approved: decidable.filter((i) => draft.bom[i.id]?.verdict === 'approved').length,
    adjusted: decidable.filter((i) => draft.bom[i.id]?.verdict === 'adjusted').length,
    cut: decidable.filter((i) => draft.bom[i.id]?.verdict === 'cut').length,
  })
  const shown = $derived(
    items
      .map((item, index) => ({ item, index }))
      .filter(({ item }) => {
        const call = draft.bom[item.id]
        if (filter === 'open') return !itemDecided(item, call)
        if (filter === 'changed') return call?.verdict === 'adjusted' || call?.verdict === 'cut'
        return true
      }),
  )
  const share = $derived(requested ? Math.min(funded / requested, 1) : 0)

  function approveRest() {
    for (const item of decidable) {
      if (!draft.bom[item.id]?.verdict)
        draft.bom[item.id] = { verdict: 'approved', reason: null, cents: null }
    }
  }

  function confirmCarried() {
    for (const item of decidable) {
      const call = draft.bom[item.id]
      if (call?.carried) draft.bom[item.id] = { ...call, carried: false }
    }
  }

  // Keyboard, from the page: A / L / X call the line in focus, J / K move.
  export function act(verdict: ItemVerdict) {
    cards[focused]?.choose(verdict)
  }

  export function move(by: number) {
    focused = Math.min(Math.max(focused + by, 0), items.length - 1)
    cards[focused]?.scrollIntoView()
  }
</script>

<div class="flex flex-col">
  <div class="sticky top-0 z-10 border-b border-border bg-background/95 px-4 py-3 backdrop-blur">
    <div class="flex flex-wrap items-center gap-x-6 gap-y-2">
      <div>
        <p class="text-[10px] tracking-wide text-muted-foreground uppercase">Asked for</p>
        <p class="font-mono text-lg"><Morph text={money(requested)} /></p>
      </div>
      <span class="text-muted-foreground">→</span>
      <div>
        <p class="text-[10px] tracking-wide text-muted-foreground uppercase">Funding</p>
        <p class="font-mono text-lg font-semibold"><Morph text={money(funded)} /></p>
      </div>
      <div class="min-w-40 flex-1">
        <div class="h-1.5 overflow-hidden rounded-full bg-muted">
          <div
            class="h-full rounded-full bg-emerald-500 transition-[width] duration-500 ease-out"
            style:width="{share * 100}%"
          ></div>
        </div>
        <p class="mt-1 flex flex-wrap gap-x-3 text-xs text-muted-foreground">
          <span><Morph text={counts.approved} /> approved</span>
          <span><Morph text={counts.adjusted} /> lowered</span>
          <span><Morph text={counts.cut} /> cut</span>
          {#if !readonly}
            <span
              class={open ? 'text-amber-600 dark:text-amber-400' : 'text-emerald-600 dark:text-emerald-400'}
            >
              {#if open}<Morph text={open} /> to decide{:else}all decided{/if}
            </span>
          {/if}
        </p>
      </div>
      <div class="flex items-center gap-2">
        {#if page.repo?.bom_csv}
          <Button size="sm" variant="ghost" onclick={() => (showCsv = !showCsv)}>
            {showCsv ? 'Hide' : 'Show'} repo’s {page.repo.bom_path}
          </Button>
        {/if}
        {#if !readonly && carried}
          <Button size="sm" variant="outline" onclick={confirmCarried}
            >Keep last review’s calls ({carried})</Button
          >
        {/if}
        {#if !readonly && open > carried}
          <Button size="sm" class={RAISED.success} onclick={approveRest}
            >Approve the other {open - carried}</Button
          >
        {/if}
      </div>
    </div>
  </div>

  {#if showCsv && page.repo?.bom_csv}
    <div transition:reveal>
      <pre
        class="mx-4 mt-3 max-h-64 overflow-auto rounded-md border border-border bg-muted/50 p-3 font-mono text-[11px]">{page
          .repo.bom_csv}</pre>
    </div>
  {/if}

  <div class="space-y-3 p-4">
    {#if draft.ai && !readonly}
      <div
        class="rounded-md border border-red-200 bg-red-50 px-3 py-2 text-sm text-red-800 dark:border-red-900 dark:bg-red-950/40 dark:text-red-300"
      >
        Marked as AI-generated journals: it will be rejected for good, so no part needs a call.
      </div>
    {/if}
    <div class="flex flex-wrap items-center justify-between gap-2">
      <p class="text-xs text-muted-foreground">
        <span class="font-medium text-foreground">Approve</span> funds a line as asked,
        <span class="font-medium text-foreground">Lower</span> funds less,
        <span class="font-medium text-foreground">Cut</span> funds none of it.
      </p>
      <Segmented
        label="Show"
        value={filter}
        onChange={(value) => (filter = value)}
        options={[
          { value: 'all', label: 'All', count: items.length, tint: 'gray' },
          { value: 'open', label: 'To decide', count: open, tint: 'amber' },
          { value: 'changed', label: 'Lowered or cut', count: counts.adjusted + counts.cut, tint: 'red' },
        ]}
      />
    </div>

    {#each shown as { item, index } (item.id)}
      <BomLineCard
        bind:this={cards[index]}
        {item}
        {index}
        bind:call={() => draft.bom[item.id] ?? EMPTY, (call) => (draft.bom[item.id] = call)}
        focused={index === focused}
        {readonly}
        cutReasons={page.options.cut_reasons}
        lowerReasons={page.options.adjust_reasons}
        onFocus={() => (focused = index)}
      />
    {:else}
      <p class="py-6 text-center text-sm text-muted-foreground">Nothing here.</p>
    {/each}

    <p class="pt-1 text-center text-xs text-muted-foreground">
      <span class="font-mono">J</span>/<span class="font-mono">K</span> move between lines,
      <span class="font-mono">A</span> approves, <span class="font-mono">L</span> lowers,
      <span class="font-mono">X</span> cuts.
    </p>
  </div>
</div>
