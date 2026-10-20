<script lang="ts">
  import type { Component, Snippet } from 'svelte'

  let {
    icon: Icon,
    title,
    description,
    children,
    class: className = '',
  }: { icon: Component; title: string; description?: string; children?: Snippet; class?: string } = $props()
</script>

<div
  class="flex flex-col items-center justify-center gap-2 rounded-lg border border-dashed border-border px-6 py-12 text-center {className}"
>
  <div class="mb-1 rounded-full bg-muted p-3 text-muted-foreground"><Icon class="size-5" /></div>
  <p class="font-medium">{title}</p>
  {#if description}<p class="max-w-sm text-sm text-muted-foreground">{description}</p>{/if}
  {@render children?.()}
</div>
