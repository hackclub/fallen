<script lang="ts">
  // The landing page's store: the prizes the hours go towards, for people who don't travel to Shenzhen. On the night
  // like the hero and How It Works, as a row of cards in the companion cards' frame: a gold-outlined card with the
  // item on the sky's bright blue, lit from behind, its name between gold diamonds and its price on a gold tag. They
  // tilt and catch the light under the cursor like the companion cards (lib/holo.ts).
  // The plan has prizes in tiers by XP, but the numbers aren't settled (program/the-plan.md), so no prices yet.
  import { starPath } from '@/components/GoldFrame.svelte'
  import HoloShine from '@/components/HoloShine.svelte'
  import { holo } from '@/lib/holo'

  // a placeholder until the store's prices are set (program/the-plan.md); every item shows it for now
  const price = '10 XP'

  const prizes = [{ name: 'Stickers' }, { name: 'Keychains' }, { name: 'Trading card' }]
</script>

<section id="store" class="px-6 py-24 md:px-10">
  <hgroup class="flex flex-col items-center gap-4 text-center">
    <h2 class="font-lora text-6xl font-bold text-green text-shadow-md text-shadow-dark-purple/40 md:text-7xl">
      Store
    </h2>
    <p class="max-w-lg font-lora text-xl text-pale-blue italic">
      The more you work on your project, the more Fallen merch you can get!
    </p>
  </hgroup>

  <ul class="mx-auto mt-8 flex max-w-5xl justify-center gap-6">
    {#each prizes as prize (prize.name)}
      <li
        class="holo-card relative w-full max-w-72 rounded-xl bg-dark-blue/70 p-3 outline-2 outline-gold backdrop-blur-sm"
        use:holo
      >
        <!-- where the item's picture will go: the sky's bright blue, lit from behind like the companions' portraits,
             with the frame's star standing in until there are photos -->
        <div
          class="relative aspect-4/5 overflow-hidden rounded-lg bg-[radial-gradient(circle_at_50%_40%,var(--color-bright-blue),var(--color-blue)_50%,var(--color-dark-blue))]"
        >
          <svg
            class="absolute top-[38%] left-1/2 size-16 -translate-1/2 rotate-45 text-gold drop-shadow-[0_6px_14px_rgb(0_0_0/0.35)]"
            viewBox="0 0 29.1 29.1"
            aria-hidden="true"
          >
            <path d={starPath} fill="currentColor" />
          </svg>
          <span
            class="absolute top-3 right-3 rounded-full bg-gold px-3 py-0.5 font-lora text-sm font-bold text-dark-blue"
          >
            {price}
          </span>
          <div class="absolute bottom-4 left-1/2 flex w-max -translate-x-1/2 items-center gap-4">
            <span class="size-2 rotate-45 rounded-xs bg-gold"></span>
            <h3 class="font-lora text-2xl font-bold text-cream">{prize.name}</h3>
            <span class="size-2 rotate-45 rounded-xs bg-gold"></span>
          </div>
        </div>
        <HoloShine />
      </li>
    {/each}
  </ul>
</section>
