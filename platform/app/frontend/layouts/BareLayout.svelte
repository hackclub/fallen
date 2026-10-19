<script lang="ts">
  import type { Snippet } from 'svelte'
  import Toaster from '@/components/Toaster.svelte'
  import OnboardingOverlay from '@/components/onboarding/OnboardingOverlay.svelte'
  import HatchOverlay from '@/components/hatch/HatchOverlay.svelte'
  import ImpersonationBanner from '@/components/ImpersonationBanner.svelte'

  let { children }: { children?: Snippet } = $props()
</script>

<!-- No nav, footer or content width, for full-bleed pages like the landing hero. -->
<ImpersonationBanner />
<main>
  <Toaster />
  <OnboardingOverlay />
  <HatchOverlay />
  {@render children?.()}
</main>
