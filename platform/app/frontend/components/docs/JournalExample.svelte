<script lang="ts">
  import type { Snippet } from 'svelte'

  // An example journal in "On Journaling": its text beside its pictures, like a journal on a project page. Pictures
  // are named by file in assets/docs, since an .mdx file gets one import (see index.ts).
  let { images, children }: { images: string[]; children: Snippet } = $props()

  const files = import.meta.glob<string>('@/assets/docs/*.webp', { eager: true, import: 'default' })
  const src = (name: string) => Object.entries(files).find(([path]) => path.endsWith(`/${name}`))?.[1]
</script>

<div class="grid gap-4 rounded-[4px] bg-white/10 p-4 sm:grid-cols-2">
  <div class="min-w-0 space-y-3 [&_ul]:space-y-1">{@render children()}</div>
  <div class="space-y-3">
    {#each images as image (image)}
      <img src={src(image)} alt="" loading="lazy" class="w-full rounded-[4px]" />
    {/each}
  </div>
</div>
