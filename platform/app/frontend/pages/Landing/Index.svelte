<script lang="ts" module>
  export { default as layout } from '@/layouts/BareLayout.svelte'
</script>

<script lang="ts">
  import Wordmark from '@/components/Wordmark.svelte'
  import { signIn } from '@/routes'
  import bg from '@/assets/bg2.webp'
  import soupFalling from '@/assets/soup-falling.png'

  import { Canvas } from '@threlte/core'
  import Particles from '@/components/shaders/Particles.svelte'
  import Shards from '@/components/shaders/Shards.svelte'
  import Noise from '@/components/shaders/Noise.svelte'

  let { hca_configured }: { hca_configured: boolean } = $props()
</script>

<svelte:head><title>Fallen</title></svelte:head>

<!-- film grain over everything; overlay blending lets it texture the colours underneath without greying them -->
<div class="fixed inset-0 z-1000 pointer-events-none mix-blend-overlay opacity-10">
  <Canvas>
    <Noise />
  </Canvas>
</div>

<section
  class="relative min-h-screen w-full text-stone-100 p-6 md:p-10 py-10 xl:p-20 space-y-6"
>
  <div
    style="background-image: url({bg})"
    class="absolute inset-0 bg-top-right bg-no-repeat bg-cover pointer-events-none select-none -z-1"
  ></div>
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
  <div class="absolute inset-0 pointer-events-none">
    <Canvas>
      <Particles />
      <Shards />
    </Canvas>
  </div>
  <img src={soupFalling} alt="" class="absolute left-1/2 -translate-x-1/2 bottom-0 h-80" />

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
