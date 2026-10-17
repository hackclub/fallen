<script lang="ts">
  import type { Snippet } from 'svelte'
  import Nav from '@/components/Nav.svelte'
  import Toasts from '@/components/Toasts.svelte'
  import OnboardingOverlay from '@/components/onboarding/OnboardingOverlay.svelte'
  import HatchOverlay from '@/components/hatch/HatchOverlay.svelte'
  import DesktopPet from '@/components/DesktopPet.svelte'
  import ImpersonationBanner from '@/components/ImpersonationBanner.svelte'

  let { children }: { children?: Snippet } = $props()
</script>

<div class="flex min-h-screen flex-col">
  <ImpersonationBanner />
  <Nav />
  <main class="mx-auto w-full max-w-5xl flex-1 px-4 py-8 sm:px-6">
    <Toasts />
    <DesktopPet />
    <OnboardingOverlay />
    <HatchOverlay />
    {@render children?.()}
  </main>
  <footer class="border-t border-stone-200 py-6 text-center text-xs text-stone-500 dark:border-stone-800">
    <a href="https://hackclub.com" class="hover:underline">Hack Club</a>
  </footer>
</div>
