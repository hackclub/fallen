<script lang="ts">
  // Past projects, fanned out on a great wheel (lib/projectWheel.ts) with the middle card lit from behind and named
  // underneath. The wheel drifts round on its own; the first time it comes on screen it spins in fast and slows into
  // that drift. Under the pointer it settles on the nearest card with a slight sway. It can be dragged and flicked,
  // carrying on with the flick's speed before easing back into the drift. A side card turns to that project, and the
  // middle card opens its source. The list is drawn twice round the rim so the edges are never short of cards. Only
  // transforms, opacity and a mask change each frame, and the frames stop while it's off screen or held still.
  import PastProjectCard from '@/components/PastProjectCard.svelte'
  import { starPath } from '@/components/GoldFrame.svelte'
  import { pastProjects as projects } from '@/lib/pastProjects'
  import { placeCard, wheelFor } from '@/lib/projectWheel'
  import { backOut } from 'svelte/easing'
  import { fade, fly } from 'svelte/transition'

  const copies = 2
  const slots = projects.length * copies
  const drift = 0.3 // cards/s it turns on its own
  const entrance = 16 // cards/s it spins in at
  const ease = 1.4 // how quickly the speed eases back to the drift, 1/s
  const idleAfterUse = 6000 // ms after the last drag or click before it drifts again
  const stiffness = 70
  const damping = 14 // a little under critical (2 * sqrt(stiffness)), so it sways once as it settles
  const top = 64 // px of room above the cards for the lifted one and its sparkles

  let stageWidth = $state(1024)
  const wheel = $derived(wheelFor(stageWidth < 640 ? 150 : stageWidth < 1280 ? 180 : 200))

  const slotsEl: HTMLElement[] = $state([])
  let offset = 0 // cards the wheel has turned
  let velocity = 0 // cards/s
  let target: number | null = null // the card it's settling on, while held
  let active = $state(0) // the project named under the wheel; left alone while it spins fast
  let fast = $state(false)

  let still = false // prefers reduced motion
  let onScreen = false
  let entered = false
  let spinUntil = 0 // ms; the entrance spin isn't stopped by a pointer that just happens to be where it scrolls in
  let hovering = false
  let lastUse = -Infinity
  let frame = 0
  let last = 0

  const wrap = (s: number, period = slots) => s - period * Math.round(s / period) // into -period/2 to period/2
  const held = () => {
    const now = performance.now()
    return (hovering && now > spinUntil) || dragging || still || now - lastUse < idleAfterUse
  }

  function place() {
    slotsEl.forEach((el, i) => placeCard(el, wrap(i - offset), wheel))
    // too quick to read: the name hides until the wheel slows, then shows the card it slowed on
    fast = Math.abs(velocity) > 4
    if (!fast) active = ((Math.round(offset) % projects.length) + projects.length) % projects.length
  }

  function start() {
    if (frame || !onScreen) return
    last = performance.now()
    frame = requestAnimationFrame(tick)
  }

  function tick(now: number) {
    const delta = Math.min((now - last) / 1000, 1 / 30)
    last = now
    frame = requestAnimationFrame(tick)
    if (dragging) return place()
    if (!held()) {
      target = null
      velocity += (drift - velocity) * (1 - Math.exp(-delta * ease))
      offset += velocity * delta
      return place()
    }
    // held: settle on a card, the nearest one ahead at the speed it was going if nothing was picked
    target ??= Math.round(offset + Math.max(-3, Math.min(3, velocity * 0.35)))
    if (still) [offset, velocity] = [target, 0]
    velocity += ((target - offset) * stiffness - velocity * damping) * delta
    offset += velocity * delta
    if (Math.abs(target - offset) < 0.0005 && Math.abs(velocity) < 0.005) {
      // a whole turn of the rim looks the same, so the numbers are kept small
      offset = target = target - slots * Math.round(target / slots)
      velocity = 0
      // still under the pointer: nothing moves until it leaves
      if (hovering || still) {
        cancelAnimationFrame(frame)
        frame = 0
      }
    }
    place()
  }

  function turnTo(slot: number) {
    lastUse = performance.now()
    target = Math.round(offset) + wrap(slot - Math.round(offset))
    start()
  }

  $effect(() => {
    void wheel
    place()
  })

  $effect(() => {
    still = matchMedia('(prefers-reduced-motion: reduce)').matches
    const visibility = new IntersectionObserver(
      ([entry]) => {
        onScreen = entry.isIntersecting
        if (!onScreen) {
          cancelAnimationFrame(frame)
          frame = 0
          return
        }
        if (!entered && !still) {
          velocity = entrance
          spinUntil = performance.now() + 2500
        }
        entered = true
        start()
      },
      // from the first px on screen, so it's already turning as it scrolls into view
      { threshold: 0 },
    )
    visibility.observe(slotsEl[0].parentElement!)
    return () => {
      visibility.disconnect()
      cancelAnimationFrame(frame)
    }
  })

  // a press only becomes a drag once it has moved, so a click still reaches the card under it
  let pressed: { x: number; id: number } | null = null
  let dragging = $state(false)
  let dragged = false
  let lastX = 0
  let lastMove = 0

  function onPointerDown(event: PointerEvent) {
    if (event.button !== 0) return
    // a mouse press would otherwise start selecting text, drag the photo's ghost image or focus the card (which turns
    // to it); the click still comes after
    if (event.pointerType === 'mouse') event.preventDefault()
    pressed = { x: event.clientX, id: event.pointerId }
    dragged = false
    lastX = event.clientX
    lastMove = performance.now()
  }

  function onPointerMove(event: PointerEvent) {
    if (!pressed) return
    if (!dragging) {
      if (Math.abs(event.clientX - pressed.x) < 6) return
      ;(event.currentTarget as Element).setPointerCapture(pressed.id)
      dragging = dragged = true
      velocity = 0
      start()
    }
    const now = performance.now()
    const moved = (event.clientX - lastX) / wheel.spacing
    offset -= moved
    // the flick's speed is the drag's own, smoothed so one jerky event doesn't decide it
    velocity += (-moved / Math.max((now - lastMove) / 1000, 0.001) - velocity) * 0.4
    lastX = event.clientX
    lastMove = now
  }

  function onPointerUp() {
    pressed = null
    if (!dragging) return
    dragging = false
    lastUse = performance.now()
    target = null // settle wherever the flick carries it
    // no flick if the pointer had already stopped before letting go
    if (performance.now() - lastMove > 80) velocity = 0
    start()
  }

  function onCardClick(slot: number) {
    if (dragged) return
    if (Math.abs(wrap(slot - offset)) < 0.5)
      window.open(projects[slot % projects.length].repo, '_blank', 'noreferrer')
    else turnTo(slot)
  }

  const project = $derived(projects[active])
  const rise = (line: number) => ({ y: 12, duration: 360, delay: line * 40, easing: backOut })
</script>

<section id="projects" aria-label="Past projects" class="pt-16">
  <!-- a gold line running out from the heading that fades to the right, starting from the star in the frame's corners -->
  <div class="mx-auto flex w-[calc(100%-3rem)] max-w-6xl items-center gap-4 md:w-[calc(100%-5rem)]">
    <h2
      class="shrink-0 font-lora text-4xl font-bold text-parchment text-shadow-md text-shadow-dark-purple/40 md:text-5xl"
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
    class="relative"
    style:height="{top + wheel.height + wheel.width * 0.95}px"
    bind:clientWidth={stageWidth}
  >
    <!-- the light behind the middle card: a warm glow and slow turning rays, faded out towards their ends -->
    <div
      class="pointer-events-none absolute left-1/2 -translate-x-1/2 -translate-y-1/4"
      style:top="{top}px"
      style:width="{wheel.width * 3.4}px"
      style:height="{wheel.width * 3.4}px"
      aria-hidden="true"
    >
      <div
        class="absolute inset-0 rounded-full bg-[radial-gradient(closest-side,rgb(247_221_166/0.38),rgb(81_100_211/0.22)_45%,transparent)]"
      ></div>
      <div
        class="rays absolute inset-0 rounded-full bg-[repeating-conic-gradient(rgb(247_221_166/0.16)_0deg_5deg,transparent_5deg_18deg)] [mask-image:radial-gradient(closest-side,#000_15%,transparent)]"
      ></div>
    </div>

    <!-- the cards, faded out towards the screen's sides and the bottom of the wheel -->
    <div
      role="presentation"
      class={[
        'absolute inset-0 touch-pan-y overflow-hidden select-none mask-x-from-85% mask-b-from-70%',
        dragging ? 'cursor-grabbing' : 'cursor-grab',
      ]}
      onpointerdown={onPointerDown}
      onpointermove={(event) => {
        // on a move rather than on entering, which also fires when the page scrolls under a still pointer
        hovering = true
        onPointerMove(event)
      }}
      onpointerup={onPointerUp}
      onpointercancel={onPointerUp}
      onpointerleave={() => {
        hovering = false
        start()
      }}
    >
      {#each { length: slots } as _, slot (slot)}
        {@const item = projects[slot % projects.length]}
        {@const clone = slot >= projects.length}
        <div
          bind:this={slotsEl[slot]}
          class="absolute left-1/2 will-change-transform"
          style:top="{top}px"
          style:width="{wheel.width}px"
          style:height="{wheel.height}px"
          style:margin-left="{-wheel.width / 2}px"
          aria-hidden={clone}
        >
          <button
            type="button"
            class="block size-full rounded-2xl focus-visible:ring-2 focus-visible:ring-cream focus-visible:outline-none"
            tabindex={clone ? -1 : undefined}
            aria-label="{item.name}, by {item.by}"
            onfocus={(event) => event.currentTarget.matches(':focus-visible') && turnTo(slot)}
            onclick={() => onCardClick(slot)}
          >
            <PastProjectCard project={item} />
          </button>
        </div>
      {/each}
    </div>

    <!-- the middle card's name and maker -->
    <div
      class="pointer-events-none absolute left-1/2 grid -translate-x-1/2 text-center transition-opacity duration-150"
      style:top="{top + wheel.height + wheel.width * 0.12}px"
      style:width="{wheel.width * 1.9}px"
      class:opacity-0={fast}
      aria-live="polite"
    >
      {#key active}
        <!-- the old lines fade quickly; the new ones rise in one after another, overshooting a little and settling -->
        <div class="col-start-1 row-start-1" out:fade={{ duration: 150 }}>
          <p
            class="font-lora text-xl leading-tight font-bold text-parchment text-shadow-md text-shadow-dark-purple/50 sm:text-2xl"
            in:fly={rise(0)}
          >
            {project.name}
          </p>
          <p class="mt-1 text-sm text-pale-blue/85 sm:text-base" in:fly={rise(1)}>{project.about}</p>
          <p class="mt-0.5 text-sm text-light-blue/80" in:fly={rise(2)}>by {project.by}</p>
        </div>
      {/key}
    </div>
  </div>
</section>

<style>
  .rays {
    animation: spin 90s linear infinite;
  }

  @keyframes spin {
    to {
      rotate: 360deg;
    }
  }

  @media (prefers-reduced-motion: reduce) {
    .rays {
      animation: none;
    }
  }
</style>
