<script lang="ts">
  // A banner of past Hack Club hardware projects (from fallout.hackclub.com's "See what teens are building"),
  // drifting slowly sideways above the store. Each photo is washed in the page's blue until hovered, when the
  // card also tilts towards the cursor (lib/holo.ts). Hovering eases the row to a stop; it can be grabbed and flung
  // either way, carrying on with a little momentum before easing back into its drift. The row is drawn twice and
  // wraps by one copy's width, so it loops without a seam. Only a transform changes each frame, and the frames stop
  // while the row is off screen or standing still. With reduced motion it doesn't drift, but can still be dragged.
  import cyberpad from '@/assets/projects/cyberpad.webp'
  import glowpad from '@/assets/projects/glowpad.webp'
  import angel from '@/assets/projects/angel.webp'
  import meko from '@/assets/projects/meko.webp'
  import bitlace from '@/assets/projects/bitlace.webp'
  import motherboard from '@/assets/projects/3dpmotherboard.webp'
  import twoswap from '@/assets/projects/twoswap.webp'
  import { starPath } from '@/components/GoldFrame.svelte'
  import { holo } from '@/lib/holo'

  // names and descriptions as Hack Club lists them (macondo.hackclub.com), with each project's source on GitHub
  const projects = [
    {
      image: cyberpad,
      name: 'CyberPad',
      about: 'A sleek, cyberpunk inspired macropad',
      by: 'Kai (17)',
      repo: 'https://github.com/KaiPereira/CYBERPAD-01',
    },
    {
      image: glowpad,
      name: 'GlowPad',
      about: 'A glowing macropad',
      by: 'Raygen (17)',
      repo: 'https://github.com/lordbagel42/glowpad',
    },
    {
      image: angel,
      name: 'The Biblically Accurate Macropad',
      about: 'A macropad in the form of a biblically accurate angel',
      by: 'Alex (16)',
      repo: 'https://github.com/geg-tech/biblicallyaccuratekeyboard',
    },
    {
      image: meko,
      name: 'Meko',
      about: 'A high definition music player',
      by: 'Marcell (17)',
      repo: 'https://github.com/KOEGlike/meko',
    },
    {
      image: bitlace,
      name: 'Bitlace',
      about: 'A retro accessory with an 8x8 monochrome screen',
      by: 'Vladislav (17)',
      repo: 'https://github.com/glutesha/bitlace',
    },
    {
      image: motherboard,
      name: '3DP Motherboard',
      about: 'A powerful, yet affordable 3D printer motherboard',
      by: 'Kai (17)',
      repo: 'https://github.com/KaiPereira/Cheetah-MX4-Mini',
    },
    {
      image: twoswap,
      name: 'TwoSwap',
      about: 'An epic wearable TV head',
      by: 'Nick (18)',
      repo: 'https://github.com/autowattage/2swap',
    },
  ]

  const drift = 40 // px/s the row moves left on its own
  const settle = 3 // how quickly the speed eases towards its target, 1/s; it stops in about a second on hover
  const cardShape = 'rounded-md rounded-br-[1.75rem]'

  let track: HTMLDivElement
  let rowWidth = $state(0)
  let offset = 0 // px the track has moved left, wrapped into one row's width
  let speed = 0 // px/s, positive is leftwards
  let hovering = false
  let dragging = $state(false)
  let lastX = 0
  let startX = 0
  let dragged = false // the last press moved far enough to count as a drag, not a click
  let lastMove = 0

  let still = false // prefers reduced motion
  let onScreen = false
  let frame = 0
  let last = 0

  function start() {
    if (frame || !onScreen) return
    last = performance.now()
    frame = requestAnimationFrame(step)
  }

  function step(now: number) {
    const delta = Math.min((now - last) / 1000, 0.1)
    last = now
    const target = hovering || still ? 0 : drift
    if (!dragging) {
      speed += (target - speed) * (1 - Math.exp(-delta * settle))
      offset += speed * delta
    }
    if (rowWidth) offset = ((offset % rowWidth) + rowWidth) % rowWidth
    track.style.transform = `translate3d(${-offset}px, 0, 0)`
    // at rest with nothing to move it: sleep until a pointer or the drift starts it again
    if (!dragging && !target && Math.abs(speed) < 0.5) {
      speed = 0
      frame = 0
    } else frame = requestAnimationFrame(step)
  }

  $effect(() => {
    still = matchMedia('(prefers-reduced-motion: reduce)').matches
    const visibility = new IntersectionObserver(([entry]) => {
      onScreen = entry.isIntersecting
      if (onScreen) start()
      else {
        cancelAnimationFrame(frame)
        frame = 0
      }
    })
    visibility.observe(track)
    return () => {
      visibility.disconnect()
      cancelAnimationFrame(frame)
    }
  })

  function onPointerDown(event: PointerEvent) {
    // a press on a project's link is a click, not the start of a drag: capturing it would swallow the click
    if (event.button !== 0 || (event.target as Element).closest('a')) return
    // capturing also moves the pointer off the card under it, so the card stops tilting for the drag
    track.setPointerCapture(event.pointerId)
    dragging = true
    dragged = false
    startX = event.clientX
    lastX = event.clientX
    lastMove = performance.now()
    speed = 0
    start()
  }

  function onPointerMove(event: PointerEvent) {
    if (!dragging) return
    const now = performance.now()
    const moved = lastX - event.clientX
    offset += moved
    if (Math.abs(event.clientX - startX) > 6) dragged = true
    // the fling's speed is the drag's own, smoothed a little so one jerky event doesn't decide it
    const instant = (moved / Math.max(now - lastMove, 1)) * 1000
    speed += (instant - speed) * 0.4
    lastX = event.clientX
    lastMove = now
  }

  function onPointerUp() {
    dragging = false
    // no fling if the pointer had already stopped before letting go
    if (performance.now() - lastMove > 80) speed = 0
  }
</script>

<!-- clone: the loop's second copy, hidden from screen readers and kept out of the tab order -->
{#snippet cards(clone: boolean)}
  {#each projects as project (project.name)}
    <li
      class="project-card group relative flex w-64 shrink-0 sm:w-80 flex-col overflow-hidden {cardShape} bg-cream shadow-[0_8px_16px_-8px_rgb(2_2_4/0.3),0_24px_60px_-20px_rgb(2_2_4/0.45),0_40px_100px_-30px_rgb(2_2_4/0.35)] ring-1 ring-gold/60"
      use:holo={{ maxTilt: 8 }}
    >
      <!-- the photo, set in from the card's edges so there's a frame of cream around it -->
      <div class="relative m-3 mb-0 aspect-4/3 overflow-hidden rounded-md">
        <img
          src={project.image}
          alt=""
          draggable="false"
          loading="lazy"
          class="size-full object-cover transition duration-500 group-hover:scale-[1.03]"
        />
        <!-- washed in the page's blue, as the recap video's thumbnail is, until hovered -->
        <div
          class="pointer-events-none absolute inset-0 transition-opacity duration-500 group-hover:opacity-0"
        >
          <div class="absolute inset-0 bg-bright-blue/40 mix-blend-multiply"></div>
          <div
            class="absolute inset-0 bg-[radial-gradient(ellipse_at_50%_45%,transparent_30%,rgb(18_11_38/0.55)_100%)]"
          ></div>
        </div>
      </div>
      <div class="flex flex-1 flex-col gap-1.5 px-5 pt-4 pb-5">
        <!-- the name links to the project's source; ignored when the press ended a drag -->
        <h3 class="font-lora text-xl leading-snug font-bold text-dark-purple">
          <a
            href={project.repo}
            target="_blank"
            rel="noreferrer"
            draggable="false"
            tabindex={clone ? -1 : undefined}
            class="decoration-gold underline-offset-4 hover:underline"
            onclick={(event) => dragged && event.preventDefault()}>{project.name}</a
          >
        </h3>
        <p class="text-dark-purple/75">{project.about}</p>
        <p class="mt-auto pt-3 text-sm text-dark-purple/60">@{project.by}</p>
      </div>
    </li>
  {/each}
{/snippet}

<!-- the row has room below for its cards' long soft shadows, which the section takes back from its own padding -->
<section id="projects" aria-label="Past projects" class="pt-16">
  <!-- on the store's left edge, with a gold line running out from it that fades to the right, starting from the star
       in the frame's corners -->
  <div class="mx-auto mb-10 flex w-[calc(100%-3rem)] md:w-[calc(100%-5rem)] max-w-6xl items-center gap-4">
    <h2
      class="shrink-0 font-lora text-4xl font-bold text-green text-shadow-md text-shadow-dark-purple/40 md:text-5xl"
    >
      Past projects
    </h2>
    <span class="flex flex-1 items-center gap-2" aria-hidden="true">
      <svg class="size-4 shrink-0 rotate-45 text-gold" viewBox="0 0 29.1 29.1"
        ><path d={starPath} fill="currentColor" /></svg
      >
      <span class="h-0.5 flex-1 bg-linear-to-r from-gold/70 to-transparent"></span>
    </span>
  </div>
  <div
    role="presentation"
    class="overflow-hidden"
    style:mask-image="linear-gradient(to right, transparent, #000 8%, #000 92%, transparent)"
    onpointerenter={() => (hovering = true)}
    onpointerleave={() => {
      hovering = false
      start()
    }}
  >
    <div
      bind:this={track}
      role="presentation"
      class={['flex w-max touch-pan-y pt-4 pb-28 select-none', dragging ? 'cursor-grabbing' : 'cursor-grab']}
      onpointerdown={onPointerDown}
      onpointermove={onPointerMove}
      onpointerup={onPointerUp}
      onpointercancel={onPointerUp}
    >
      <ul bind:offsetWidth={rowWidth} class="flex shrink-0 gap-6 pr-6">{@render cards(false)}</ul>
      <ul class="flex shrink-0 gap-6 pr-6" aria-hidden="true">{@render cards(true)}</ul>
    </div>
  </div>
</section>

<style>
  .project-card {
    transform: perspective(900px) rotateX(var(--rx, 0deg)) rotateY(var(--ry, 0deg));
    opacity: 0.9; /* a touch see-through until hovered */
    transition:
      transform 300ms ease-out,
      opacity 300ms ease-out;
  }
  .project-card:hover {
    opacity: 1;
  }

  @media (prefers-reduced-motion: reduce) {
    .project-card {
      transform: none;
    }
  }
</style>
