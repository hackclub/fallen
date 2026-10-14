<script lang="ts" module>
  export { default as layout } from '@/layouts/BareLayout.svelte'
</script>

<script lang="ts">
  import type { DevUser } from '@/types'
  import Wordmark from '@/components/Wordmark.svelte'
  import HeroArt from '@/components/HeroArt.svelte'
  import HeroFrame from '@/components/HeroFrame.svelte'
  import CursorTrail from '@/components/CursorTrail.svelte'
  import Footer from '@/components/Footer.svelte'
  import PhotoCard from '@/components/PhotoCard.svelte'
  import { signIn } from '@/routes'

  import { onMount } from 'svelte'
  import type { Component, ComponentProps } from 'svelte'

  let { hca_configured, dev_users }: { hca_configured: boolean; dev_users: DevUser[] | null } = $props()

  // bind:value selects the first option and fills this in when it starts out undefined.
  let devUserUrl: string | undefined = $state()

  // the scattered photos either side of the recap video; shift is in % of the card's own size
  const leftPhotos: ComponentProps<typeof PhotoCard>[] = [
    { class: 'aspect-4/3 w-60', rotate: 5 },
    { class: 'aspect-4/3 w-70', rotate: -2 },
  ]
  const rightPhotos: ComponentProps<typeof PhotoCard>[] = [
    { class: 'aspect-6/5 w-40 z-30', rotate: 7, shift: [25, 0] },
    { class: 'aspect-4/3 w-70', rotate: -4, shift: [0, -25] },
    { class: 'aspect-4/3 w-80', rotate: 4, shift: [0, 33.33] },
  ]

  const navItems = [
    { label: 'GET STARTED', href: '/', class: '' },
    { label: 'View Stats', href: '/', class: '' },
  ]
  // GET STARTED stays highlighted until another item is hovered, and again once the pointer leaves the nav
  let activeNav = $state(0)

  // The WebGL effects start after the page has painted.
  let LandingScene: Component | undefined = $state()
  onMount(async () => {
    LandingScene = (await import('@/components/shaders/LandingScene.svelte')).default
  })
</script>

<svelte:head><title>Fallen</title></svelte:head>

{#snippet ornament(visible: boolean, extra = '')}
  <svg
    class={['transition-opacity drop-shadow-[0_0_4px_rgb(255_255_255/0.6)]', extra, !visible && 'opacity-0']}
    aria-hidden="true"
    width="180"
    height="30"
    viewBox="0 0 202 43"
    fill="none"
    xmlns="http://www.w3.org/2000/svg"
  >
    <rect
      x="0.821599"
      width="36.2118"
      height="36.2118"
      transform="matrix(0.821599 -0.570066 0.821599 0.570066 106.147 21.6816)"
      stroke="#FEFEFE"
    />
    <rect
      x="0.821599"
      width="36.2118"
      height="36.2118"
      transform="matrix(0.821599 -0.570066 0.821599 0.570066 122.002 21.6816)"
      stroke="#FEFEFE"
    />
    <line y1="20.5" x2="106" y2="20.5" stroke="white" />
    <line x1="182" y1="21" x2="202" y2="21" stroke="white" />
    <rect
      x="71.4923"
      y="21.2132"
      width="12.1802"
      height="12.1802"
      transform="rotate(-45 71.4923 21.2132)"
      fill="#024B81"
      stroke="#FEFEFE"
    />
  </svg>
{/snippet}

<CursorTrail />

{#if LandingScene}
  <LandingScene />
{/if}

<section
  class="relative min-h-screen w-full text-stone-100 p-6 md:p-10 py-10 xl:p-20 space-y-6 flex flex-col justify-center items-center text-center bg-[url('/assets/hero/background.webp')] bg-center bg-cover bg-no-repeat"
>
  <HeroFrame />
  <div class="w-full h-full fixed inset-0 -z-1 bg-black/10"></div>
  <div
    class="blur-[2px] pointer-events-none absolute inset-0 m-auto grid grid-cols-1 grid-rows-1 place-items-center"
    aria-hidden="true"
  >
    <div
      class="col-start-1 row-start-1 size-220 rounded-full p-14 bg-linear-to-b from-[#162C86]/30 to-transparent
                   [mask:linear-gradient(#000_0_0)_content-box_exclude,linear-gradient(#000_0_0)]"
    ></div>
    <div class="col-start-1 row-start-1 size-220 rounded-full outline-8 outline-[#162C86]/6"></div>
    <div
      class=" col-start-1 row-start-1 rounded-full size-170 bg-clip-padding border-linear-to-b bg-linear-to-b from-[#162C86]/30 to-transparent"
    ></div>
  </div>

  <h1><Wordmark onDark class="z-10 h-70 -mt-10 drop-shadow-[0_0_4px_rgb(255_255_255/0.6)]" /></h1>

  <!-- <p class="absolute top-10 mx-auto z-3 text-2xl text-[#ACACE1] px-2 py-1 bg-navy rounded-xs">December 11–14, 2026</p> -->
  <h2 class="text-4xl font-lora font-medium max-w-2xl leading-10 text-shadow-md text-shadow-purple/20 text-[#F5EBE4]">
    Build a hardware project for free, <span class="text-[#F6B75B]"> present it in Shenzhen, China</span>
  </h2>

  <nav class="relative z-10 flex flex-col items-center space-y-4" onmouseleave={() => (activeNav = 0)}>
    {#each navItems as item, i (item.label)}
      {@const active = activeNav === i}
      <div class="flex items-center justify-center gap-2">
        {@render ornament(active)}
        <a
          href={item.href}
          class={[
            'font-lora transition-all text-shadow-md text-shadow-black/20 [-webkit-text-stroke:6px_#162C8640] [paint-order:stroke_fill]',
            item.class,
            active ? 'text-4xl font-medium' : 'text-3xl text-[#C7E1B8]',
          ]}
          onmouseenter={() => (activeNav = i)}
          onfocus={() => (activeNav = i)}
        >
          {item.label}
        </a>
        {@render ornament(active, 'rotate-180')}
      </div>
    {/each}
  </nav>
  <!--
  {#if dev_users}
    <div class="relative z-10">
      {#if dev_users.length > 0}
        <form
          class="flex items-center gap-2"
          onsubmit={(event) => {
            event.preventDefault()
            if (devUserUrl) window.location.assign(devUserUrl)
          }}
        >
          <select
            bind:value={devUserUrl}
            class="input w-auto border-white/20 bg-black text-white"
            aria-label="Dev user"
          >
            {#each dev_users as devUser (devUser.id)}
              <option value={devUser.sign_in_url}>
                {devUser.display_name} ({devUser.roles.join(', ')})
              </option>
            {/each}
          </select>
          <button type="submit" class="btn border-white/20 text-white hover:bg-white/10">Dev login</button>
        </form>
      {:else}
        <p class="text-sm opacity-70">No users to dev login as yet. Run <code>bin/rails db:seed</code>.</p>
      {/if}
    </div>
  {/if} -->

  <!-- <div class="mt-8 flex justify-center gap-3">
    {#if hca_configured}
      <a href={signIn().url} class="btn-primary text-base">Sign in with Hack Club</a>
    {:else}
      <div class="card text-left text-sm">
        <p class="font-semibold">Hack Club Auth isn't configured yet.</p>
        <p class="mt-1 text-stone-600">
          Set <code>HCA_CLIENT_ID</code> and <code>HCA_CLIENT_SECRET</code> in <code>.env.development</code>,
          or run
          <code>bin/rails db:seed</code> and visit <code>/dev/sign_in_as/admin@example.com</code>.
        </p>
      </div>
    {/if}
  </div> -->
</section>
<section id="watch" class="h-screen flex flex-col items-center space-y-2 p-10 bg-[#040224]">
  <h3 class="text-[#ACACE1] text-3xl font-display">Last July we brought 180+ to Shenzhen, China.</h3>
  <span class="text-[#5758BF] text-2xl">Watch the recap below...</span>
  <div class="flex h-full justify-center items-center -space-x-18">
    <div class="z-20 flex h-full flex-col justify-center gap-40 pb-10 pr-14">
      {#each leftPhotos as photo, i (i)}
        <PhotoCard {...photo} />
      {/each}
    </div>
    <div
      class="aspect-video h-[80%] w-full rounded-sm rounded-tl-4xl rounded-br-4xl border-10 border-[#5758BF] bg-[repeating-linear-gradient(-45deg,#1F1C66_0_14px,color-mix(in_oklab,#1F1C66,#5758BF_35%)_14px_28px)]"
    ></div>
    <div class="z-20 flex h-full flex-col justify-between py-10">
      {#each rightPhotos as photo, i (i)}
        <PhotoCard {...photo} />
      {/each}
    </div>
  </div>
</section>

<Footer />
