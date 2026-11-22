<script lang="ts">
  import { Button } from '@/components/admin/ui/button'
  import BomLineCard from '@/components/review/BomLineCard.svelte'
  import { reveal } from '@/components/review/motion'
  import type { ReviewPage } from '@/lib/review.svelte'
  import { money } from '@/lib/submission'

  // Their parts list, line by line, to read. Approving funds it as asked; to change it, return the project.
  let { page, ai, focused = $bindable() }: { page: ReviewPage; ai: boolean; focused: number } = $props()

  let showCsv = $state(false)
  const cards: BomLineCard[] = $state([])

  const items = $derived(page.submission.bom_items)
  const owned = $derived(items.filter((item) => item.owned).length)

  export function move(by: number) {
    focused = Math.min(Math.max(focused + by, 0), items.length - 1)
    cards[focused]?.scrollIntoView()
  }
</script>

<div class="flex flex-col">
  <div
    class="sticky top-0 z-10 flex flex-wrap items-center gap-x-6 gap-y-2 border-b border-border bg-background/95 px-4 py-3 backdrop-blur"
  >
    <div>
      <p class="text-[10px] tracking-wide text-muted-foreground uppercase">Asked for</p>
      <p class="font-mono text-lg font-semibold">{money(page.submission.requested_cents)}</p>
    </div>
    <p class="text-xs text-muted-foreground">
      {items.length} line{items.length === 1 ? '' : 's'}{owned ? `, ${owned} already owned` : ''}
    </p>
    {#if page.repo?.bom_csv}
      <Button size="sm" variant="ghost" class="ml-auto" onclick={() => (showCsv = !showCsv)}>
        {showCsv ? 'Hide' : 'Show'} repo’s {page.repo.bom_path}
      </Button>
    {/if}
  </div>

  {#if showCsv && page.repo?.bom_csv}
    <div transition:reveal>
      <pre
        class="mx-4 mt-3 max-h-64 overflow-auto rounded-md border border-border bg-muted/50 p-3 font-mono text-[11px]">{page
          .repo.bom_csv}</pre>
    </div>
  {/if}

  <div class="space-y-3 p-4">
    {#if ai}
      <div
        class="rounded-md border border-red-200 bg-red-50 px-3 py-2 text-sm text-red-800 dark:border-red-900 dark:bg-red-950/40 dark:text-red-300"
      >
        Marked as AI-generated journals: it will be rejected for good, so none of this is funded.
      </div>
    {/if}

    {#each items as item, index (item.id)}
      <BomLineCard
        bind:this={cards[index]}
        {item}
        {index}
        focused={index === focused}
        onFocus={() => (focused = index)}
      />
    {:else}
      <p class="py-6 text-center text-sm text-muted-foreground">No parts listed.</p>
    {/each}

    <p class="pt-1 text-center text-xs text-muted-foreground">
      Approving funds the whole list as asked. To change it, return the project with feedback.
      <span class="font-mono">J</span>/<span class="font-mono">K</span> move between lines.
    </p>
  </div>
</div>
