<script lang="ts">
  // One card in the Past projects arc: the photo in a gilded frame with a gold hairline and diamonds inside it, and the
  // project's name over a dusk gradient at the bottom. The wheel sets custom properties on a card's slot each frame
  // (lib/projectWheel.ts): --near, 1 for the card in the middle and 0 from one place away, which lights its sparkles;
  // --shade, which dims the cards further out; --twinkle, which runs the sparkles only while they show; and --mask,
  // which fades its edge as it trades places with the card behind. The shadow and sparkles sit outside the mask so it
  // never cuts them. Hovering tilts it towards the cursor (lib/holo.ts).
  //
  // In Firefox the card is redrawn every frame it moves (lib/browser.ts), so there nothing in it may need an
  // off-screen pass: the title's shadow has no blur, the sparkles glow with a gradient instead of a filter, and the
  // photo's corners are square, since a rounded corner on a turned card costs a mask per element inside it.
  import HoloShine from '@/components/HoloShine.svelte'
  import { starPath } from '@/components/GoldFrame.svelte'
  import { holo } from '@/lib/holo'
  import type { PastProject } from '@/lib/pastProjects'

  let { project }: { project: PastProject } = $props()
</script>

<div
  class="absolute inset-0 rounded-2xl shadow-[0_10px_20px_-10px_rgb(2_2_4/0.5),0_30px_60px_-24px_rgb(2_2_4/0.6)]"
></div>
<div
  class="holo-card relative size-full rounded-2xl bg-linear-to-br from-[#fbebc2] via-gold to-[#8a6a32] p-1.5"
  style:mask-image="var(--mask, none)"
  use:holo={{ maxTilt: 10 }}
>
  <div class="relative size-full">
    <!-- only the photo and its tints are clipped to the corners; everything else stays inside them anyway -->
    <div class="absolute inset-0 overflow-hidden rounded-xl bg-dark-blue firefox:rounded-none">
      <img src={project.image} alt="" draggable="false" loading="lazy" class="size-full object-cover" />
      <div
        class="absolute inset-0 bg-linear-to-t from-dark-purple via-dark-purple/25 via-45% to-transparent"
      ></div>
      <div class="absolute inset-0 bg-dark-blue" style:opacity="calc(var(--shade, 0) * 0.6)"></div>
    </div>
    <div class="absolute inset-2 rounded-lg border border-gold/60">
      <span class="absolute top-0 left-1/2 size-2 -translate-1/2 rotate-45 border border-gold bg-dark-blue"
      ></span>
      <span class="absolute bottom-0 left-1/2 size-2 -translate-x-1/2 translate-y-1/2 rotate-45 bg-gold"
      ></span>
    </div>
    <p
      class="absolute inset-x-5 bottom-6 font-lora text-xl leading-tight font-bold text-cream text-shadow-md text-shadow-dark-purple firefox:text-shadow-2xs sm:text-2xl"
    >
      {project.name}
    </p>
    <HoloShine rounded="rounded-xl firefox:rounded-none" />
  </div>
</div>
<div class="pointer-events-none absolute inset-0">
  <!-- in Firefox each star's glow is a gradient behind it rather than a drop-shadow filter, and the opacity goes on
       each part rather than the pair, so neither needs its own pass -->
  {#each [['-top-3 -right-3 size-7', '0s'], ['top-5 -right-4 size-3.5', '-1.1s'], ['-top-4 right-7 size-3', '-0.6s']] as [place, delay] (place)}
    <span class="absolute {place}">
      <span
        class="absolute -inset-1/2 hidden rounded-full bg-[radial-gradient(circle,rgb(247_221_166/0.55),transparent_65%)] firefox:block"
        style:opacity="var(--near, 0)"
      ></span>
      <svg
        class="sparkle relative size-full text-[#fff4d6] drop-shadow-[0_0_6px_rgb(247_221_166/0.9)] firefox:drop-shadow-none"
        style:opacity="var(--near, 0)"
        style:animation-delay={delay}
        viewBox="0 0 29.1 29.1"
        aria-hidden="true"><path d={starPath} fill="currentColor" /></svg
      >
    </span>
  {/each}
</div>

<style>
  /* a slow twinkle, each star on its own beat */
  .sparkle {
    animation: twinkle 2.4s ease-in-out infinite;
    animation-play-state: var(--twinkle, paused);
  }

  @keyframes twinkle {
    0%,
    100% {
      scale: 0.7;
      rotate: 0deg;
    }
    50% {
      scale: 1.1;
      rotate: 45deg;
    }
  }

  @media (prefers-reduced-motion: reduce) {
    .sparkle {
      animation: none;
    }
  }
</style>
