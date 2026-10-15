<script lang="ts">
  // The recap video in a gold frame. Until someone presses play it is only the thumbnail washed in the hero's
  // blue, so the page doesn't load YouTube's player for people who never watch.

  let { id, title, class: className = '' }: { id: string; title: string; class?: string } = $props()

  const maxTilt = 6 // degrees at the frame's edge
  const follow = 8 // how quickly the play badge catches up with the cursor, 1/s
  const ease = 10 // how quickly the frame tilts towards the cursor, 1/s

  let playing = $state(false)
  let tilt = $state([0, 0]) // degrees round the x and y axes
  const reducedMotion =
    typeof matchMedia !== 'undefined' && matchMedia('(prefers-reduced-motion: reduce)').matches
  // with no cursor (touch) or from the keyboard, the badge rests in the middle so it's still clear this plays
  const noHover = typeof matchMedia !== 'undefined' && matchMedia('(hover: none)').matches

  let hovering = $state(false)
  let focused = $state(false)
  let badge = $state([0, 0]) // px from the frame's top left
  let target = [0, 0]
  let tiltTarget = [0, 0]
  let width = $state(0)
  let height = $state(0)
  let frame = 0
  let last = 0

  // The pointer only sets targets; one animation frame moves the badge and the tilt towards them, and only through
  // transforms, so a fast mouse costs no layout and no restarted CSS transitions.
  function onPointerMove(event: PointerEvent) {
    if (playing || event.pointerType === 'touch') return
    const box = (event.currentTarget as HTMLElement).getBoundingClientRect()
    target = [event.clientX - box.left, event.clientY - box.top]
    if (!hovering) badge = target // appear under the cursor, not slide in from the last place it left
    hovering = true
    if (reducedMotion) {
      badge = target
      return
    }
    // the side under the cursor dips away, as if pressed
    tiltTarget = [-(target[1] / box.height - 0.5) * 2 * maxTilt, (target[0] / box.width - 0.5) * 2 * maxTilt]
    start()
  }

  function onPointerLeave() {
    hovering = false
    tiltTarget = [0, 0]
    start()
  }

  function start() {
    if (frame || reducedMotion) return
    last = performance.now()
    frame = requestAnimationFrame(step)
  }

  function step(now: number) {
    const delta = Math.min((now - last) / 1000, 0.1)
    last = now
    const k = 1 - Math.exp(-delta * follow)
    const t = 1 - Math.exp(-delta * ease)
    badge = [badge[0] + (target[0] - badge[0]) * k, badge[1] + (target[1] - badge[1]) * k]
    tilt = [tilt[0] + (tiltTarget[0] - tilt[0]) * t, tilt[1] + (tiltTarget[1] - tilt[1]) * t]
    const settled =
      Math.hypot(target[0] - badge[0], target[1] - badge[1]) < 0.5 &&
      Math.hypot(tiltTarget[0] - tilt[0], tiltTarget[1] - tilt[1]) < 0.01
    if (settled) tilt = tiltTarget
    frame = settled ? 0 : requestAnimationFrame(step)
  }

  $effect(() => () => cancelAnimationFrame(frame))
</script>

<div
  role="presentation"
  class="relative perspective-[1200px] {className}"
  bind:clientWidth={width}
  bind:clientHeight={height}
  onpointermove={onPointerMove}
  onpointerleave={onPointerLeave}
>
  <div
    class="absolute inset-0 will-change-transform"
    style:transform="rotateX({playing ? 0 : tilt[0]}deg) rotateY({playing ? 0 : tilt[1]}deg)"
  >
    <div
      class="absolute inset-0 overflow-hidden rounded-lg border border-gold bg-dark-purple shadow-[0_24px_60px_-12px_rgb(2_2_4/0.9),0_0_60px_-10px_color-mix(in_srgb,var(--color-bright-blue)_40%,transparent)]"
    >
      {#if playing}
        <iframe
          class="size-full"
          src="https://www.youtube-nocookie.com/embed/{id}?autoplay=1&rel=0"
          {title}
          allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture; web-share"
          referrerpolicy="strict-origin-when-cross-origin"
          allowfullscreen
        ></iframe>
      {:else}
        <button
          type="button"
          class="group relative size-full cursor-pointer focus-visible:outline-none"
          aria-label="Play {title}"
          onclick={() => (playing = true)}
          onfocus={(event) => (focused = event.currentTarget.matches(':focus-visible'))}
          onblur={() => (focused = false)}
        >
          <img
            src="https://i.ytimg.com/vi/{id}/maxresdefault.jpg"
            alt=""
            loading="lazy"
            class="absolute inset-0 size-full object-cover transition duration-700 group-hover:scale-[1.03]"
          />
          <div class="absolute inset-0 bg-bright-blue/40 mix-blend-multiply"></div>
          <div
            class="absolute inset-0 bg-[radial-gradient(ellipse_at_50%_45%,transparent_20%,rgb(21_17_58/0.85)_90%)] transition-opacity duration-500 group-hover:opacity-70"
          ></div>
          <div class="absolute inset-2.5 rounded-sm border border-gold/35"></div>
        </button>
      {/if}
    </div>
  </div>

  <!-- outside the tilting plane, so it stays by the cursor; off to the lower right so the cursor doesn't cover it -->
  {#if !playing}
    {@const shown = hovering || focused || noHover}
    {@const centred = !hovering && (focused || noHover)}
    <span
      class="pointer-events-none absolute top-0 left-0 z-10 transition-opacity duration-200 will-change-transform {shown
        ? 'opacity-100'
        : 'opacity-0'}"
      style:transform={centred
        ? `translate(${width / 2}px, ${height / 2}px)`
        : `translate3d(${badge[0]}px, ${badge[1]}px, 0)`}
      aria-hidden="true"
    >
      <span
        class="flex {centred
          ? '-translate-1/2'
          : 'translate-x-4 translate-y-5'} items-center justify-between gap-2 rounded-full border-2 border-dark-purple bg-gold py-2 pr-4 pl-2 font-sans text-base font-bold text-dark-purple uppercase transition-transform duration-200 {shown
          ? 'scale-100'
          : 'scale-50'}"
      >
        <span class="size-6 rounded-full bg-dark-purple"></span>
        Play
      </span>
    </span>
  {/if}
</div>
