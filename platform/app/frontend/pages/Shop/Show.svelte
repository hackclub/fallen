<script lang="ts" module>
  export { default as layout } from '@/layouts/SkyLayout.svelte'
</script>

<script lang="ts">
  // The shop isn't open yet: what it will sell sits out of focus around a lock. Prizes and prices wait on
  // program/the-plan.md. Item art is OpenMoji (CC BY-SA 4.0), except the CNC mill, drawn to match.
  import PageTitle from '@/components/PageTitle.svelte'
  import SolarLockKeyhole from '@/components/icons/SolarLockKeyhole.svelte'
  import printer from '@/assets/shop/3d-printer.svg'
  import camera from '@/assets/shop/camera.svg'
  import circuit from '@/assets/shop/circuit.svg'
  import cncMill from '@/assets/shop/cnc-mill.svg'
  import drone from '@/assets/shop/drone.svg'
  import headphone from '@/assets/shop/headphone.svg'
  import keyboard from '@/assets/shop/keyboard.svg'
  import laptop from '@/assets/shop/laptop.svg'
  import raspberryPi from '@/assets/shop/raspberry-pi.svg'
  import robot from '@/assets/shop/robot.svg'
  import tShirt from '@/assets/shop/t-shirt.svg'

  // x and y are the item's centre in % of the area, size in px, tilt in degrees. Kept clear of the middle.
  const items = [
    { src: printer, x: 14, y: 16, size: 150, tilt: -8 },
    { src: tShirt, x: 50, y: 9, size: 120, tilt: 6 },
    { src: cncMill, x: 85, y: 18, size: 160, tilt: 5 },
    { src: keyboard, x: 9, y: 50, size: 110, tilt: 10 },
    { src: drone, x: 91, y: 52, size: 120, tilt: -12 },
    { src: headphone, x: 20, y: 84, size: 120, tilt: 12 },
    { src: raspberryPi, x: 50, y: 92, size: 110, tilt: -6 },
    { src: robot, x: 80, y: 86, size: 130, tilt: -4 },
    { src: camera, x: 33, y: 32, size: 80, tilt: -14 },
    { src: circuit, x: 68, y: 34, size: 80, tilt: 14 },
    { src: laptop, x: 69, y: 70, size: 90, tilt: 8 },
  ]
</script>

<svelte:head><title>Shop · Fallen</title></svelte:head>

<PageTitle title="Shop" />

<section
  class="relative isolate min-h-[640px] overflow-hidden rounded-2xl border border-white/10 bg-sky-night/60 md:h-[calc(100dvh-14rem)]"
>
  {#each items as item (item.src)}
    <img
      src={item.src}
      alt=""
      aria-hidden="true"
      class="pointer-events-none absolute -translate-1/2 blur-[5px] brightness-125 select-none max-md:scale-75"
      style:left="{item.x}%"
      style:top="{item.y}%"
      style:width="{item.size}px"
      style:rotate="{item.tilt}deg"
    />
  {/each}

  <div class="absolute inset-0 flex flex-col items-center justify-center gap-5 px-6 text-center">
    <div
      class="grid size-24 place-items-center rounded-full border border-gold/60 bg-sky-night/80 text-gold shadow-[0_0_60px_rgb(218_183_113/0.25)]"
    >
      <SolarLockKeyhole size={44} />
    </div>
    <h2
      class="font-display text-4xl text-white drop-shadow-[0_2px_12px_rgb(0_0_0/0.5)] sm:text-5xl md:text-6xl"
    >
      Coming Soon!
    </h2>
  </div>
</section>
