<script lang="ts">
  import { Button } from '@/components/admin/ui/button'
  import JournalReviewCard from '@/components/review/JournalReviewCard.svelte'
  import Segmented from '@/components/review/Segmented.svelte'
  import { formatMinutes } from '@/lib/format'
  import { journalDeflated, type ReviewDraft, type ReviewPage } from '@/lib/review.svelte'

  // Every journal the submission covers, oldest first, each with its own call on the time that counts.
  let {
    page,
    draft = $bindable(),
    readonly,
    focused = $bindable(),
  }: { page: ReviewPage; draft: ReviewDraft; readonly: boolean; focused: number } = $props()

  let filter = $state<'all' | 'cut'>('all')
  const cards: JournalReviewCard[] = $state([])

  const carried = $derived(page.journals.filter((j) => draft.journals[j.id]?.carried).length)
  const cut = $derived(page.journals.filter((j) => journalDeflated(j, draft.journals[j.id])).length)
  // The journal being worked on stays in a filtered list until focus moves off it, so typing "45" into a deflate
  // doesn't drop it from "Deflated" at the "0".
  const shown = $derived(
    page.journals
      .map((journal, index) => ({ journal, index }))
      .filter(
        ({ journal, index }) =>
          index === focused ||
          (filter === 'cut' ? journalDeflated(journal, draft.journals[journal.id]) : true),
      ),
  )

  function confirmCarried() {
    for (const j of page.journals) {
      const call = draft.journals[j.id]
      if (call?.carried) draft.journals[j.id] = { ...call, carried: false }
    }
  }

  // Keyboard: the page passes R here to deflate the journal in focus, and J / K move the focus.
  export function deflate() {
    cards[focused]?.deflate()
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
          { value: 'cut', label: 'Deflated', count: cut, tint: 'red' },
        ]}
      />
    </div>
  </div>

  <div class="space-y-3 p-4">
    {#if draft.ai && !readonly}
      <div
        class="rounded-md border border-red-200 bg-red-50 px-3 py-2 text-sm text-red-800 dark:border-red-900 dark:bg-red-950/40 dark:text-red-300"
      >
        Marked as AI-generated journals: rejecting it makes every journal count no time, whatever is chosen
        below.
      </div>
    {/if}
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
      <span class="font-mono">R</span> deflates.
    </p>
  </div>
</div>
