<script lang="ts" module>
  export { default as layout } from '@/layouts/BareLayout.svelte'
</script>

<script lang="ts">
  import type { DevUser } from '@/types'
  import Wordmark from '@/components/Wordmark.svelte'
  import HeroArt from '@/components/HeroArt.svelte'
  import { signIn } from '@/routes'

  import { onMount } from 'svelte'
  import type { Component } from 'svelte'

  let { hca_configured, dev_users }: { hca_configured: boolean; dev_users: DevUser[] | null } = $props()

  // bind:value selects the first option and fills this in when it starts out undefined.
  let devUserUrl: string | undefined = $state()

  // The WebGL effects start after the page has painted.
  let LandingScene: Component | undefined = $state()
  onMount(async () => {
    LandingScene = (await import('@/components/shaders/LandingScene.svelte')).default
  })
</script>

<svelte:head><title>Fallen</title></svelte:head>

{#if LandingScene}
  <LandingScene />
{/if}

<section class="relative min-h-screen w-full text-stone-100 p-6 md:p-10 py-10 xl:p-20 space-y-6">
  <HeroArt />
  <h1><Wordmark onDark class="absolute top-6 left-6 h-16" /></h1>

  <p class="text-3xl mt-60">December 11–14, 2026</p>
  <h2 class="relative z-10 text-6xl max-w-6xl text-left font-semibold leading-16">
    Build a hardware project for free, present it in <span class="text-shadow-md text-shadow-purple/20"
      >Shenzhen, China</span
    >!
  </h2>

  <div class="space-y-2">
    <form class="mt-10 space-x-4 flex items-center">
      <input
        type="email"
        name="email"
        autocomplete="email"
        aria-label="Email"
        placeholder="fallen@hackclub.com"
        class="bg-beige text-black w-90 h-14 shadow-sm shadow-white/40 rounded-xs rounded-bl-xl rounded-tr-xl pl-6 outline-2 outline-beige border-3 border-beige"
      />
      <button
        type="submit"
        class="bg-[#3F5BFD]/60 h-14 px-4 rounded-xs rounded-br-xl rounded-tl-xl font-genshin text-beige text-3xl outline-2 outline-beige"
        >START</button
      >
    </form>
    <span class="block"
      >By <a href="https://hackclub.com" class="underline opacity-60">Hack Club</a>, for teens 13–18</span
    >
  </div>

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
  {/if}

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
