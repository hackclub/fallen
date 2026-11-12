<script lang="ts" module>
  export { default as layout } from '@/layouts/BareLayout.svelte'
</script>

<script lang="ts">
  import '@fontsource-variable/geist'
  import GuideProse from '@/components/GuideProse.svelte'
  import Link from '@/components/Link.svelte'
  import Wordmark from '@/components/Wordmark.svelte'
  import Guide from '@/guides/tamagotchi-guide.mdx'
  import { root } from '@/routes'

  // The Tamagotchi build as one long walkthrough in the first person, a sibling of the paged guide (Show.svelte).
</script>

<svelte:head><title>Tamagotchi · Fallen</title></svelte:head>

<div
  class="min-h-screen bg-sky-night text-white"
  style="font-family: 'Geist Variable', ui-sans-serif, system-ui, sans-serif"
>
  <div class="mx-auto max-w-3xl px-4 pb-20 sm:px-6">
    <header class="py-4 sm:py-6">
      <Link href={root()} aria-label="Fallen" class="inline-block">
        <Wordmark onDark class="h-12 sm:h-14" />
      </Link>
    </header>

    <main>
      <h1 class="border-b-4 border-white pb-2 text-4xl font-extrabold tracking-tight uppercase">
        Tamagotchi
      </h1>
      <GuideProse>
        <Guide />
      </GuideProse>
    </main>
  </div>
</div>
