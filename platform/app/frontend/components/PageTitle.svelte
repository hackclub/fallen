<script lang="ts">
  import type { Snippet } from 'svelte'

  // `children` sits at the title's right, wrapping below it on narrow screens (Home's flash event pill).
  let { title, subtitle, children }: { title: string; subtitle?: string; children?: Snippet } = $props()
</script>

<div class="mb-8 flex flex-wrap items-start justify-between gap-4">
  <div>
    <h1 class="mb-2 font-display text-4xl text-white md:text-5xl">{title}</h1>
    {#if subtitle}<p class="font-outfit text-lg text-sky-ice/60 md:text-xl">{subtitle}</p>{/if}
  </div>
  {@render children?.()}
</div>
