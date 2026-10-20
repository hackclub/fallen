<script lang="ts">
  import { Link } from '@inertiajs/svelte'
  import type { Snippet } from 'svelte'

  type Tab = { value: string; label: string; href: string }

  // Tabs that are links: each is its own URL, so it can be shared, opened in a new tab and prefetched. `badge`
  // renders after a tab's label, given its value.
  let {
    tabs,
    active,
    badge,
    class: className = '',
  }: { tabs: (Tab | 'divider')[]; active: string; badge?: Snippet<[string]>; class?: string } = $props()
</script>

<nav class="-mx-1 overflow-x-auto px-1 {className}">
  <div class="flex w-max items-center gap-1 border-b border-border">
    {#each tabs as tab, i (tab === 'divider' ? `divider-${i}` : tab.value)}
      {#if tab === 'divider'}
        <span class="mx-1.5 h-4 w-px bg-border"></span>
      {:else}
        {@const current = tab.value === active}
        <Link
          href={tab.href}
          preserveScroll
          prefetch
          aria-current={current ? 'page' : undefined}
          class={[
            'relative -mb-px flex items-center gap-1.5 border-b-2 px-2.5 py-2 text-sm whitespace-nowrap transition-colors',
            current
              ? 'border-foreground font-medium text-foreground'
              : 'border-transparent text-muted-foreground hover:text-foreground',
          ]}
        >
          {tab.label}
          {@render badge?.(tab.value)}
        </Link>
      {/if}
    {/each}
  </div>
</nav>
