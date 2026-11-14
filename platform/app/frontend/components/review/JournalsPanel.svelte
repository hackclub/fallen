<script lang="ts">
  import { Button } from '@/components/admin/ui/button'
  import JournalReviewCard from '@/components/review/JournalReviewCard.svelte'
  import Segmented from '@/components/review/Segmented.svelte'
  import Morph from '@/components/admin/Morph.svelte'
  import { formatMinutes } from '@/lib/format'
  import { journalDecided, journalDeflated, type ReviewDraft, type ReviewPage } from '@/lib/review.svelte'

  // Every journal the submission covers, oldest first, each with its own call on the time that counts.
  let {
    page,
    draft = $bindable(),
    readonly,
    focused = $bindable(),
  }: { page: ReviewPage; draft: ReviewDraft; readonly: boolean; focused: number } = $props()

  let filter = $state<'all' | 'open' | 'cut'>('all')
  const cards: JournalReviewCard[] = $state([])

  const open = $derived(page.journals.filter((j) => !journalDecided(j, draft.journals[j.id])).length)
  const carried = $derived(page.journals.filter((j) => draft.journals[j.id]?.carried).length)
  const cut = $derived(page.journals.filter((j) => journalDeflated(j, draft.journals[j.id])).length)
  // The journal being worked on stays in a filtered list until focus moves off it, so typing "45" into a deflate
  // doesn't drop it from "To decide" at the "4".
  const shown = $derived(
    page.journals
      .map((journal, index) => ({ journal, index }))
      .filter(
        ({ journal, index }) =>
          index === focused ||
          (filter === 'open'
            ? !journalDecided(journal, draft.journals[journal.id])
            : filter === 'cut'
              ? journalDeflated(journal, draft.journals[journal.id])
              : true),
      ),
  )

  function confirmCarried() {
    for (const j of page.journals) {
      const call = draft.journals[j.id]
      if (call?.carried) draft.journals[j.id] = { ...call, carried: false }
    }
  }

  // Keyboard: the page passes A / R / X here for the journal in focus, and J / K move the focus.
  export function act(key: 'full' | 'part' | 'none') {
    cards[focused]?.choose(key)
  }

  export function move(by: number) {
    const at = shown.findIndex(({ index }) => index === focused)
    const next = shown[Math.min(Math.max(at + by, 0), shown.length - 1)]
    if (!next) return
    focused = next.index
    cards[focused]?.scrollIntoView()
  }
</script>

<div class="flex flex-col">
  <div
    class="sticky top-0 z-10 flex flex-wrap items-center gap-2 border-b border-border bg-background/95 px-4 py-2 backdrop-blur"
  >
    <span class="text-sm">
      <span class="font-semibold">{page.journals.length}</span> journals,
      <span class="font-mono">{formatMinutes(page.project.logged_minutes)}</span> logged
    </span>
    {#if !readonly}
      <span
        class={[
          'rounded px-1.5 py-0.5 text-xs transition-colors duration-300',
          open
            ? 'bg-amber-100 text-amber-800 dark:bg-amber-950 dark:text-amber-300'
            : 'bg-emerald-100 text-emerald-700 dark:bg-emerald-950 dark:text-emerald-300',
        ]}
      >
        {#if open}<Morph text={open} /> to decide{:else}All decided{/if}
      </span>
    {/if}
    <div class="ml-auto flex items-center gap-1">
      {#if carried && !readonly}
        <Button size="sm" variant="outline" onclick={confirmCarried}
          >Keep last review’s calls ({carried})</Button
        >
      {/if}
      <Segmented
        label="Show"
        value={filter}
        onChange={(value) => (filter = value)}
        options={[
          { value: 'all', label: 'All', tint: 'gray' },
          { value: 'open', label: 'To decide', count: open, tint: 'amber' },
          { value: 'cut', label: 'Deflated', count: cut, tint: 'red' },
        ]}
      />
    </div>
  </div>

  <div class="space-y-3 p-4">
    {#if page.journals.length === 0}
      <p class="text-sm text-muted-foreground">No journals with hours before it was submitted.</p>
    {/if}
    {#each shown as { journal, index } (journal.id)}
      <JournalReviewCard
        bind:this={cards[index]}
        {journal}
        {index}
        bind:call={draft.journals[journal.id]}
        reasons={page.options.journal_reasons}
        focused={index === focused}
        {readonly}
        onFocus={() => (focused = index)}
      />
    {/each}
    <p class="pt-2 text-center text-xs text-muted-foreground">
      <span class="font-mono">J</span>/<span class="font-mono">K</span> move between journals,
      <span class="font-mono">A</span> counts all of it, <span class="font-mono">R</span> deflates,
      <span class="font-mono">X</span> none.
    </p>
  </div>
</div>
