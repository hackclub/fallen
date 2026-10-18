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
  import OrnateButton from '@/components/OrnateButton.svelte'
  import OrnateModal from '@/components/OrnateModal.svelte'
  import PastEvents from '@/components/PastEvents.svelte'
  // import PastProjects from '@/components/PastProjects.svelte'
  import Recap from '@/components/Recap.svelte'
  // import Store from '@/components/Store.svelte'
  import Wordmark from '@/components/Wordmark.svelte'
  import { home, root, signIn, slackAvatar } from '@/routes'
  import { buildTime, travellers } from '@/lib/program'
  import { shared } from '@/lib/shared.svelte'

  import { onMount } from 'svelte'
  import type { Component } from 'svelte'

  let { whoami_url }: { whoami_url: string } = $props()

  // Everything that follows the scroll is plain arithmetic on scrollY, so a scroll costs no layout: the only
  // measurements are the intro's and How It Works' places on the page, taken again whenever the page changes height.
  type Place = { top: number; bottom: number }
  let scrollY = $state(0)
  let innerHeight = $state(1)
  let pageHeight = $state(0)
  let intro: HTMLElement | undefined = $state()
  let introPlace: Place | undefined = $state()
  let howItWorks: Place | undefined = $state()

  const placeOf = (el: Element | null | undefined) => {
    const box = el?.getBoundingClientRect()
    return box && { top: box.top + window.scrollY, bottom: box.bottom + window.scrollY }
  }
  $effect(() => {
    void [pageHeight, innerHeight]
    introPlace = placeOf(intro)
    // How It Works may be commented out, so there may be nothing to measure
    howItWorks = placeOf(document.getElementById('how-it-works'))
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

  // The hero's frame fades away as How It Works leaves the screen.
  const leaving = $derived(howItWorks ? passing(howItWorks.bottom, 0.75, 0.15) : 0)

  // The page darkens to navy as the intro comes up the screen, keeps it through How It Works, and fades back to the
  // sky as How It Works leaves (or the intro, if How It Works is commented out).
  const tint = $derived.by(() => {
    if (!introPlace) return 0
    const last = howItWorks ?? introPlace
    return passing(introPlace.top, 0.85, 0.35) * (1 - passing(last.bottom, 0.75, 0.15))
  })

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

  // There aren't any stats to show yet, so View Stats just says so.
  let showStats = $state(false)
  const openStats = (event: MouseEvent) => {
    event.preventDefault()
    showStats = true
  }

  // Someone signed in to Hack Club Auth but not here gets started as their Slack picture, if they've set one. HCA's
  // whoami says who they are; the picture is looked up in a job, so it is asked for again until it's ready.
  let avatar: { src: string; alt: string; before: string } | undefined = $state()
  onMount(async () => {
    if (shared().auth.user) return
    try {
      const me = await (await fetch(whoami_url, { credentials: 'include' })).json()
      if (!me.signed_in || !me.email) return
      for (let tries = 0; tries < 8; tries++) {
        const response = await fetch(slackAvatar().url, {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ email: me.email }),
        })
        if (response.status === 200) {
          const { url } = await response.json()
          if (url) avatar = { src: url, alt: me.first_name || 'you', before: 'AS' }
          return
        }
        if (response.status !== 202) return
        await new Promise((resolve) => setTimeout(resolve, 750))
      }
    } catch {
      // not signed in to HCA, or HCA doesn't let this origin ask: the button just says Get Started
    }
  })

  const navItems = $derived([
    shared().auth.user
      ? { label: 'DASHBOARD', href: home.index().url, glimmer: true }
      : avatar
        ? { label: 'GET STARTED', href: signIn().url, glimmer: true, avatar }
        : { label: 'GET STARTED', href: signIn().url, glimmer: true },
    { label: 'View Stats', href: root().url, onclick: openStats },
  ])

  // The WebGL effects start after the page has painted.
  let LandingScene: Component | undefined = $state()
  onMount(async () => {
    LandingScene = (await import('@/components/shaders/LandingScene.svelte')).default
  })
</script>

<svelte:head><title>Fallen</title></svelte:head>
<svelte:window
  bind:scrollY
  bind:innerHeight
  onkeydown={(event) => {
    if (event.key === 'Escape') showStats = false
  }}
/>
<svelte:body bind:clientHeight={pageHeight} />

<CursorTrail />

{#if showStats}
  <OrnateModal titleId="stats-title" title="View Stats" class="max-w-md" onClose={() => (showStats = false)}>
    <div class="px-6 pt-1 pb-6 text-center md:px-9 md:pb-8">
      <p class="font-outfit text-ink-soft">oops :p we don't have enough stats to show yet</p>
      <div class="mt-6 flex justify-center">
        <OrnateButton kind="confirm" onclick={() => (showStats = false)}>Okay</OrnateButton>
      </div>
    </div>
  </OrnateModal>
{/if}

<div
  class="fixed inset-0 -z-2 bg-[url('/assets/hero/background.webp')] bg-cover bg-center bg-no-repeat"
  aria-hidden="true"
></div>
<!-- the page's colour from the intro through How It Works (see tint above): a deep navy, lit faintly from the
     middle by the sky's cobalt -->
<div
  class="pointer-events-none fixed inset-0 -z-1 bg-navy bg-[radial-gradient(ellipse_60%_55%_at_50%_45%,color-mix(in_oklab,var(--color-indigo)_45%,transparent),transparent)]"
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
  <!-- and a deeper dark along the bottom, so what scrolls up fades in rather than appearing at the frame's edge: the
       same blurred squircle, its window running off the top and sides and ending above the bottom, so the dark rises
       softly and curves up into the bottom corners -->
  <div
    class="absolute -inset-x-[12vw] -top-[30vh] bottom-[10vh] rounded-[min(22vw,30vh)] shadow-[0_0_0_100vmax_color-mix(in_oklab,var(--color-dark-blue)_55%,transparent)] blur-[6vw]"
  ></div>
</div>
<!-- the frame is its own layer above the sections, so their darkening gradient never covers it as it fades. Hidden on
     phones for now -->
<div
  class="pointer-events-none fixed inset-0 z-3 max-sm:hidden"
  style:opacity={1 - leaving}
  aria-hidden="true"
>
  <!-- the frame's border, from the screen edge to its inner line (GoldFrame's innerInset, 21px), lightly blurs
       everything scrolling under it: most at the screen edge, fading to none by the inner line. Four strips rather
       than one full-screen layer, so only that border is ever blurred; each one's mask fades it inwards. -->
  {#each blurEdges as [edge, inwards] (edge)}
    <div
      class="absolute {edge} backdrop-blur-xs firefox:backdrop-blur-none"
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
  class="relative flex min-h-screen w-full flex-col items-center justify-center space-y-4 overflow-x-clip sm:space-y-6 px-6 py-10 text-center text-stone-100 md:p-10 xl:p-20"
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
  <div class="flex flex-col -space-y-3 sm:-space-y-8">
    <h1>
      <Wordmark onDark class="z-10 -mt-6 h-32 sm:-mt-10 sm:h-60 drop-shadow-[0_0_4px_rgb(255_255_255/0.6)]" />
    </h1>
    <p class="text-lg md:text-2xl text-cream px-2 py-1 rounded-xs font-lora">December 11–14, 2026</p>
  </div>

  <h2
    class="-mt-4 text-xl md:text-3xl font-lora font-semibold max-w-lg leading-6 md:leading-8 text-shadow-md text-shadow-purple/20 text-saffron drop-shadow-[0_0_10px_color-mix(in_oklab,var(--color-saffron)_35%,transparent)]"
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

<!-- relative z-1: over the fixed hero scene (also z-1, but earlier), so its shards pass behind the video and text.
     overflow-x-clip: tilted cards and wide companions stick out past the screen edge, and mustn't scroll it sideways -->
<div class="relative z-1 overflow-x-clip">
  <div class="relative">
    <div
      class="absolute inset-0 -z-1 bg-linear-to-b from-transparent via-purple via-60% to-dark-purple"
      aria-hidden="true"
    ></div>
    <div
      bind:this={intro}
      class="px-10 sm:px-16 md:px-24 lg:px-32 mx-auto flex max-w-6xl flex-col items-center gap-12 text-xl/relaxed text-cream md:text-2xl lg:flex-row lg:justify-between lg:gap-16"
    >
      <div class="max-w-2xl space-y-5 font-lora md:space-y-6">
        <p class="font-bold">Welcome to Fallen!</p>
        <p>
          This December you & {travellers} teens will travel to China, to showcase your projects at
          <a class="text-periwinkle underline" href="https://makerfaire.com/">Maker Faire Shenzhen!</a>
          For the next {buildTime}, you, other fallers, and we will work together to
          <span class="text-periwinkle underline">build our own interactive hardware projects!</span>
        </p>
        <p>
          Then, we'll meet up with our projects in Shenzhen, China to demo at Maker Faire's flagship
          convention and go on a hardware adventure.
        </p>
        <p>Hope to see you there!</p>
        <p class="italic text-mint">- Katie, Anson & Sophia</p>
      </div>
      <PastEvents />
    </div>
    <HowItWorks />
    <!-- <PastProjects /> -->
    <!-- <Store /> -->
    <Faq />
    <Recap />
  </div>
  <Footer nav={navItems} />
</div>
