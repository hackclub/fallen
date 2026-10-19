<script lang="ts" module>
  export { default as layout } from '@/layouts/SkyLayout.svelte'
</script>

<script lang="ts">
  // The shop isn't open yet: what it will sell sits out of focus around a lock. Prizes and prices wait on
  // program/the-plan.md. Photo credits are in assets/shop/CREDITS.md.
  import PageTitle from '@/components/PageTitle.svelte'
  import SolarLockKeyhole from '@/components/icons/SolarLockKeyhole.svelte'
  import arduino from '@/assets/shop/arduino-uno.webp'
  import bambu from '@/assets/shop/bambu-x1c.webp'
  import drone from '@/assets/shop/drone.webp'
  import flipper from '@/assets/shop/flipper-zero.webp'
  import gameBoy from '@/assets/shop/game-boy-color.webp'
  import macbook from '@/assets/shop/macbook.webp'
  import mill from '@/assets/shop/milling-machine.webp'
  import oscilloscope from '@/assets/shop/oscilloscope.webp'
  import prusa from '@/assets/shop/prusa-mini.webp'
  import raspberryPi from '@/assets/shop/raspberry-pi.webp'
  import steamDeck from '@/assets/shop/steam-deck.webp'
  import tShirt from '@/assets/shop/t-shirt.webp'

  // x and y are the item's centre in % of the area, size its width in px, tilt in degrees. Kept clear of the middle.
  const items = [
    { src: prusa, x: 13, y: 17, size: 170, tilt: -6 },
    { src: tShirt, x: 48, y: 10, size: 120, tilt: 5 },
    { src: mill, x: 85, y: 19, size: 180, tilt: 4 },
    { src: gameBoy, x: 31, y: 36, size: 70, tilt: -12 },
    { src: flipper, x: 69, y: 36, size: 100, tilt: 12 },
    { src: oscilloscope, x: 10, y: 54, size: 170, tilt: 8 },
    { src: drone, x: 90, y: 53, size: 190, tilt: -8 },
    { src: arduino, x: 30, y: 72, size: 110, tilt: 10 },
    { src: raspberryPi, x: 71, y: 71, size: 130, tilt: -10 },
    { src: macbook, x: 14, y: 89, size: 170, tilt: -4 },
    { src: steamDeck, x: 50, y: 92, size: 190, tilt: 3 },
    { src: bambu, x: 87, y: 87, size: 130, tilt: 6 },
  ]
</script>

<svelte:head><title>Shop · Fallen</title></svelte:head>

<PageTitle title="Shop" />

<section class="relative isolate min-h-[640px] md:h-[calc(100dvh-14rem)]">
  {#each items as item (item.src)}
    <img
      src={item.src}
      alt=""
      aria-hidden="true"
      class="pointer-events-none absolute -translate-1/2 opacity-80 blur-[9px] select-none max-md:scale-75"
      style:left="{item.x}%"
      style:top="{item.y}%"
      style:width="{item.size}px"
      style:rotate="{item.tilt}deg"
    />
  {/each}

  <div class="absolute inset-0 flex flex-col items-center justify-center gap-4 px-6 text-center">
    <SolarLockKeyhole size={56} class="text-white drop-shadow-[0_2px_12px_rgb(0_0_0/0.5)]" />
    <h2
      class="font-montserrat text-4xl font-semibold tracking-[-0.03em] text-white drop-shadow-[0_2px_12px_rgb(0_0_0/0.5)] md:text-5xl"
    >
      Coming Soon!
    </h2>
  </div>
</section>
