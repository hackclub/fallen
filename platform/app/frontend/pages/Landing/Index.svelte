<script lang="ts" module>
  export { default as layout } from '@/layouts/BareLayout.svelte'
</script>

<script lang="ts">
  import CursorTrail from '@/components/CursorTrail.svelte'
  import Faq from '@/components/Faq.svelte'
  import Footer from '@/components/Footer.svelte'
  import GoldFrame from '@/components/GoldFrame.svelte'
  import HowItWorks from '@/components/HowItWorks.svelte'
  import OrnamentNav from '@/components/OrnamentNav.svelte'
  import PastProjects from '@/components/PastProjects.svelte'
  import Recap from '@/components/Recap.svelte'
  // import Store from '@/components/Store.svelte'
  import Wordmark from '@/components/Wordmark.svelte'
  import { home, root, signIn } from '@/routes'
  import { shared } from '@/lib/shared.svelte'

  import { onMount } from 'svelte'
  import type { Component } from 'svelte'

  // Everything that follows the scroll is plain arithmetic on scrollY, so a scroll costs no layout: the only
  // measurement is How It Works' place on the page, taken again whenever the page changes height.
  let scrollY = $state(0)
  let innerHeight = $state(1)
  let pageHeight = $state(0)
  let howItWorks: { top: number; bottom: number } | undefined = $state()

  $effect(() => {
    void [pageHeight, innerHeight]
    const box = document.getElementById('how-it-works')!.getBoundingClientRect()
    howItWorks = { top: box.top + window.scrollY, bottom: box.bottom + window.scrollY }
  })

  const unit = (v: number) => Math.min(1, Math.max(0, v))
  const easeInOut = (t: number) => (t < 0.5 ? 2 * t * t : 1 - 2 * (1 - t) ** 2)
  // 0 to 1 as a point `at` px down the page scrolls up the screen from `from` to `to` (shares of its height)
  const passing = (at: number, from: number, to: number) =>
    easeInOut(unit((from * innerHeight - (at - scrollY)) / ((from - to) * innerHeight)))

  // The hero's background and frame stay fixed behind the whole page, and the sections below scroll over it with no
  // backgrounds of their own. The hero's rings stay put too, fading out over the first screen of scrolling: pinned to
  // the sky they frame, and gone before the sections scroll in under them.
  const heroFade = $derived(unit(1 - scrollY / innerHeight))

  // How It Works has its own colour: the whole page fades from the sky into twilight as the section comes up the
  // screen, holds it while the section is read, and fades back to the sky as it leaves, taking the hero's frame with
  // it.
  const leaving = $derived(howItWorks ? passing(howItWorks.bottom, 0.75, 0.15) : 0)
  const tint = $derived(howItWorks ? passing(howItWorks.top, 0.85, 0.25) * (1 - leaving) : 0)

  // ...and the screen's edges are softly darkened with a multiplied vignette. Multiply only ever darkens, so a dark
  // card stays dark rather than turning see-through. It fades away over the last stretch of the page, so the footer
  // is never left dimmed.
  const vignette = $derived(unit((pageHeight - scrollY - innerHeight) / (innerHeight * 0.2)))

  // the frame's border, from the screen edge in to its inner line (GoldFrame's innerInset, 21px), and which way each
  // strip fades
  const blurEdges = [
    ['inset-x-0 top-0 h-[21px]', 'bottom'],
    ['inset-x-0 bottom-0 h-[21px]', 'top'],
    ['inset-y-[21px] left-0 w-[21px]', 'right'],
    ['inset-y-[21px] right-0 w-[21px]', 'left'],
  ]

  // bind:value selects the first option and fills this in when it starts out undefined.
  let devUserUrl: string | undefined = $state()

  // Without Hack Club Auth (local development), getting started opens the dev login picker instead.
  let showDevLogin = $state(false)
  const openDevLogin = (event: MouseEvent) => {
    event.preventDefault()
    showDevLogin = true
  }

  const navItems = $derived([
    shared().auth.user
      ? { label: 'DASHBOARD', href: home.index().url }
      : { label: 'GET STARTED', href: signIn().url },
    { label: 'View Stats', href: root().url },
  ])

  // The WebGL effects start after the page has painted.
  let LandingScene: Component | undefined = $state()
  onMount(async () => {
    LandingScene = (await import('@/components/shaders/LandingScene.svelte')).default
  })
</script>

<svelte:head><title>Fallen</title></svelte:head>
<svelte:window bind:scrollY bind:innerHeight />
<svelte:body bind:clientHeight={pageHeight} />

<CursorTrail />

<div
  class="fixed inset-0 -z-2 bg-[url('/assets/hero/background.webp')] bg-cover bg-center bg-no-repeat"
  aria-hidden="true"
></div>
<!-- the page's colour while How It Works is on screen, over the sky (see tint above). Twilight, lit from the middle
     by the sky's bright blue, like Lulu's card -->
<div
  class="pointer-events-none fixed inset-0 -z-1 bg-twilight bg-[radial-gradient(ellipse_60%_55%_at_50%_45%,color-mix(in_oklab,var(--color-bright-blue)_45%,transparent),transparent)]"
  style:opacity={tint}
  aria-hidden="true"
></div>
<!-- the vignette, over the sections and under the frame: the dark painted all round a heavily rounded window, then
     blurred, so it falls off smoothly in a squircle rather than an ellipse. Centred and faint, reaching a little
     further in from the sides than from the top and bottom: just enough to settle the edges -->
<div
  class="pointer-events-none fixed inset-0 z-2 overflow-hidden mix-blend-multiply"
  style:opacity={vignette}
  aria-hidden="true"
>
  <div
    class="absolute inset-x-[11vw] inset-y-[6vmin] rounded-[min(22vw,30vh)] shadow-[0_0_0_100vmax_color-mix(in_oklab,var(--color-dark-blue)_30%,transparent)] blur-[9vw]"
  ></div>
</div>
<!-- the frame is its own layer above the sections, so their darkening gradient never covers it as it fades -->
<div class="pointer-events-none fixed inset-0 z-3" style:opacity={1 - leaving} aria-hidden="true">
  <!-- the frame's border, from the screen edge to its inner line (GoldFrame's innerInset, 21px), lightly blurs
       everything scrolling under it: most at the screen edge, fading to none by the inner line. Four strips rather
       than one full-screen layer, so only that border is ever blurred; each one's mask fades it inwards. -->
  {#each blurEdges as [edge, inwards] (edge)}
    <div
      class="absolute {edge} backdrop-blur-xs"
      style:mask-image="linear-gradient(to {inwards}, #000, transparent)"
    ></div>
  {/each}
  <GoldFrame />
</div>

{#if LandingScene}
  <LandingScene />
  <LandingScene scene="dust" />
{/if}

<section
  class="relative flex min-h-screen w-full flex-col items-center justify-center space-y-6 overflow-x-clip px-6 py-10 text-center text-stone-100 md:p-10 xl:p-20"
>
  <div class="fixed inset-0 -z-1 bg-black/10"></div>
  <div
    class="pointer-events-none fixed inset-0 m-auto grid grid-cols-1 grid-rows-1 place-items-center blur-[2px]"
    style:opacity={heroFade}
    aria-hidden="true"
  >
    <div
      class="col-start-1 row-start-1 size-220 rounded-full bg-linear-to-b from-blue/30 to-transparent p-14 [mask:linear-gradient(#000_0_0)_content-box_exclude,linear-gradient(#000_0_0)]"
    ></div>
    <div class="col-start-1 row-start-1 size-220 rounded-full outline-8 outline-blue/6"></div>
    <div
      class="col-start-1 row-start-1 size-170 rounded-full border-linear-to-b bg-linear-to-b from-blue/30 to-transparent bg-clip-padding"
    ></div>
  </div>
  <div class="flex flex-col -space-y-8">
    <h1><Wordmark onDark class="z-10 -mt-10 h-60 drop-shadow-[0_0_4px_rgb(255_255_255/0.6)]" /></h1>
    <p class="text-2xl text-cream px-2 py-1 rounded-xs">December 11–14, 2026</p>
  </div>

  <h2
    class="-mt-4 text-3xl font-lora font-semibold max-w-lg leading-8 text-shadow-md text-shadow-purple/20 text-saffron"
  >
    Build a hardware project for free, present it in Shenzhen, China.
  </h2>

  <OrnamentNav items={navItems} />

  <!-- <div class="mt-8 flex justify-center gap-3">
    {#if hca_configured}
      <a href={signIn().url} class="btn-primary text-base">Sign in with Hack Club</a>
    {:else}
      <div class="card text-left text-sm">
        <p class="font-bold">Hack Club Auth isn't configured yet.</p>
        <p class="mt-1 text-stone-600">
          Set <code>HCA_CLIENT_ID</code> and <code>HCA_CLIENT_SECRET</code> in <code>.env.development</code>,
          or run
          <code>bin/rails db:seed</code> and visit <code>/dev/sign_in_as/admin@example.com</code>.
        </p>
      </div>
    {/if}
  </div> -->
</section>

<!-- relative z-1: over the fixed hero scene (also z-1, but earlier), so its shards pass behind the video and text -->
<div class="relative z-1">
  <div class="relative">
    <div
      class="absolute inset-0 -z-1 bg-linear-to-b from-transparent via-purple via-60% to-black"
      aria-hidden="true"
    ></div>
    <HowItWorks />
    <PastProjects />
    <!-- <Store /> -->
    <Faq />
    <Recap />
  </div>
  <Footer nav={navItems} />
</div>
