<script lang="ts">
  import type { Snippet } from 'svelte'
  import { enter } from './motion'
  import { nextItemDelay } from './StripPanel.svelte'

  // Wrap each control so it pops in on the panel's stagger.
  let { children, class: className = '' }: { children: Snippet; class?: string } = $props()

  const delay = nextItemDelay()
</script>

<div
  class="flex justify-center {className}"
  style:transform-origin="50% 100%"
  {@attach enter(
    { scale: 0.5, y: 46, opacity: 0, rotate: -4 },
    { scale: 1, y: 0, opacity: 1, rotate: 0 },
    { type: 'spring', stiffness: 520, damping: 20, mass: 0.9, delay },
  )}
>
  {@render children()}
</div>
