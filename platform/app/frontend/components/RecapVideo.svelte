<script lang="ts">
  // The recap video in a gold frame. Until someone presses play it is only the thumbnail washed in the hero's
  // blue, so the page doesn't load YouTube's player for people who never watch.
  import { starPath } from '@/components/GoldFrame.svelte'

  let { id, title, class: className = '' }: { id: string; title: string; class?: string } = $props()

  const maxTilt = 6 // degrees at the frame's edge
  const follow = 8 // how quickly the play badge catches up with the cursor, 1/s
  const ease = 10 // how quickly the frame tilts towards the cursor, 1/s
  const scoop = 28
  const line = 2

  const mask = ['0 0', '100% 0', '0 100%', '100% 100%']
    .map(
      (at) =>
        `radial-gradient(${scoop}px at ${at}, #0000 calc(100% - 0.5px), #000) ${at} / 51% 51% no-repeat`,
    )
    .join(', ')

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
    class="absolute inset-0 will-change-transform [filter:drop-shadow(0_24px_28px_rgb(2_2_4/0.7))_drop-shadow(0_0_24px_color-mix(in_srgb,var(--color-bright-blue)_30%,transparent))]"
    style:transform="rotateX({playing ? 0 : tilt[0]}deg) rotateY({playing ? 0 : tilt[1]}deg)"
  >
    <div class="absolute inset-0 overflow-hidden bg-dark-purple" style:mask>
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
            class="absolute inset-0 size-full scale-[1.045] object-cover transition duration-700 group-hover:scale-[1.055]"
          />
          <div class="absolute inset-0 bg-vivid-blue/10"></div>
          <div
            class="absolute inset-0 bg-[radial-gradient(ellipse_75%_75%_at_50%_45%,transparent_35%,color-mix(in_oklab,var(--color-twilight)_80%,transparent))]"
          ></div>
          <!-- a play button in the middle, coloured like the stops in "How this works" (HowItWorks.svelte) -->
          <span
            class="absolute top-1/2 left-1/2 grid size-14 -translate-1/2 place-items-center rounded-full border-2 border-gold bg-blue text-gold md:size-16"
          >
            <!-- nudged right, as a triangle's weight sits left of its box's middle -->
            <svg class="ml-1 size-7 md:size-8" viewBox="0 0 24 24" aria-hidden="true"
              ><path
                d="M6 3.5 21 12 6 20.5Z"
                fill="currentColor"
                stroke="currentColor"
                stroke-width="2"
                stroke-linejoin="round"
              /></svg
            >
          </span>
        </button>
      {/if}
    </div>
    {#if width}
      {@const [i, r, w, h] = [line / 2, scoop + line / 2, width, height]}
      <svg
        class="pointer-events-none absolute inset-0 size-full"
        viewBox="0 0 {w} {h}"
        fill="none"
        aria-hidden="true"
      >
        <path
          d="M{r} {i}H{w - r}A{r} {r} 0 0 0 {w - i} {r}V{h - r}A{r} {r} 0 0 0 {w - r} {h -
            i}H{r}A{r} {r} 0 0 0 {i} {h - r}V{r}A{r} {r} 0 0 0 {r} {i}Z"
          class="stroke-gold"
          stroke-width={line}
        />
      </svg>
    {/if}
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
        class="flex h-10 {centred
          ? '-translate-1/2'
          : 'translate-x-4 translate-y-5'} bg-mint p-[1.5px] [clip-path:polygon(12px_0,calc(100%-12px)_0,100%_50%,calc(100%-12px)_100%,12px_100%,0_50%)] transition-transform duration-200 {shown
          ? 'scale-100'
          : 'scale-50'}"
      >
        <span
          class="flex items-center gap-2 bg-royal-blue pr-6 pl-5 font-lora text-xl font-semibold text-mint [clip-path:polygon(11px_0,calc(100%-11px)_0,100%_50%,calc(100%-11px)_100%,11px_100%,0_50%)]"
        >
          <svg class="size-3 shrink-0 overflow-visible" viewBox="0 0 29.1 29.1">
            <path
              d={starPath}
              transform="rotate(45 14.55 14.55)"
              class="fill-cornflower stroke-mint"
              stroke-width="3"
              stroke-linejoin="round"
            />
          </svg>
          Play
        </span>
      </span>
    </span>
  {/if}
</div>
