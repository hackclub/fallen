<script lang="ts">
  import type { Snippet } from 'svelte'
  import Toasts from '@/components/Toasts.svelte'
  import ImpersonationBanner from '@/components/ImpersonationBanner.svelte'

  let { children }: { children?: Snippet } = $props()
</script>

<!-- No nav, footer or content width, for full-bleed pages like the landing hero. -->
<ImpersonationBanner />
<main>
  <Toasts />
  {@render children?.()}
</main>
