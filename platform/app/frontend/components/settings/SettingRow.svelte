<script lang="ts">
  import type { Snippet } from 'svelte'

  let {
    title,
    description,
    lead,
    children,
  }: { title: string; description?: string; lead?: Snippet; children?: Snippet } = $props()
</script>

<div class="setting-row">
  {@render lead?.()}
  <div class="min-w-0 flex-1 basis-56">
    <p class="font-montserrat text-lg font-semibold tracking-[-0.02em] text-white">{title}</p>
    {#if description}<p class="mt-0.5 font-outfit text-sm text-sky-ice/60">{description}</p>{/if}
  </div>
  {@render children?.()}
</div>
