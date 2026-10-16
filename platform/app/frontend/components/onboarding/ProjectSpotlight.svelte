<script module lang="ts">
  import { SCENE } from '@/components/dialog/geometry'

  // The tutorial spotlight: the screen goes dark except a rounded window on one thing to click, which closes in on it
  // from the whole screen like a camera iris. A gold frame with reticle corners pulses round it and an arrow bobs
  // beside it. Outside the window nothing can be clicked; inside, the page works as usual. Two steps use it: the
  // Projects tab (`onarrive` once the projects page is open), then its create button, which hands over to the form
  // (tour.stepAside). Targets are marked with data-tour.
  export type SpotlightTarget = 'projects-tab' | 'new-project'
  const PAD = 12
  const RADIUS = 18
  const DIM = 'rgba(4, 6, 15, 0.74)'
  const LOOK_FOR_MS = 1500
  // The window's four edges each ride a damped spring towards the target, stepped every frame, so it overshoots,
  // settles, and chases the target with momentum when it moves (scrolling, or the next step's button).
  const SPRING = { stiffness: 230, damping: 23, mass: 1 }
  const SUBSTEP = 1 / 240

  type Rect = { x: number; y: number; w: number; h: number }
  type Spring = { pos: number; vel: number }

  // Where the speech bubble starts, from the top of the window: the button is scrolled to the middle of the space
  // above it. Mirrors DialogStage's default fit and the stage's `bottom` in Onboarding.svelte.
  function bubbleTop() {
    const unit = Math.min((innerWidth * 0.94) / SCENE.width, (innerHeight * 0.5) / SCENE.height)
    return innerHeight - unit * (24 + SCENE.height - 267)
  }

  function findTarget(name: SpotlightTarget) {
    return [...document.querySelectorAll<HTMLElement>(`[data-tour="${name}"]`)].find(
      (el) => el.getClientRects().length > 0,
    )
  }
</script>

<script lang="ts">
  import { untrack } from 'svelte'
  import { router, usePage } from '@inertiajs/svelte'
  import { starPath } from '@/components/GoldFrame.svelte'
  import { prefersReducedMotion } from '@/components/dialog/motion'
  import { projects } from '@/routes'
  import { stepAside, tour } from '@/lib/tour.svelte'

  let { target: name, onarrive }: { target: SpotlightTarget; onarrive?: () => void } = $props()

  const page = usePage()

  let hole = $state({ x: 0, y: 0, w: 0, h: 0 })
  let ready = $state(false)
  let pointUp = $state(false)
  // The rail sits at the window's edge: point at it from the right instead of from above.
  let pointLeft = $state(false)

  // From the whole screen the first time, from the last step's window after that.
  function springs(from: Rect): Record<keyof Rect, Spring> {
    return {
      x: { pos: from.x, vel: 0 },
      y: { pos: from.y, vel: 0 },
      w: { pos: from.w, vel: 0 },
      h: { pos: from.h, vel: 0 },
    }
  }

  function step(s: Spring, goal: number, dt: number) {
    for (let t = 0; t < dt; t += SUBSTEP) {
      const force = -SPRING.stiffness * (s.pos - goal) - SPRING.damping * s.vel
      s.vel += (force / SPRING.mass) * SUBSTEP
      s.pos += s.vel * SUBSTEP
    }
  }

  $effect(() => {
    tour.spotlight = true
    let frame = 0
    let target: HTMLElement | undefined
    const edges = springs(untrack(() => tour.lastHole) ?? { x: 0, y: 0, w: innerWidth, h: innerHeight })
    let last = performance.now()
    const began = performance.now()
    let visited = false

    const onClick = () => name === 'new-project' && stepAside()

    const track = () => {
      if (name === 'projects-tab' && page.component === 'Projects/Index') return onarrive?.()
      if (!target || !target.isConnected) {
        target = findTarget(name)
        if (target) {
          target.addEventListener('click', onClick)
          const r = target.getBoundingClientRect()
          // The rail stays put; a button in the page is scrolled into the room above the speech bubble.
          // A button at the foot of a short page gets room below it so it can scroll that far.
          if (name === 'new-project') {
            document.body.style.paddingBottom = `${innerHeight}px`
            window.scrollBy({ top: r.top + r.height / 2 - bubbleTop() / 2, behavior: 'smooth' })
          }
          ready = true
        } else if (
          !visited &&
          performance.now() - began > LOOK_FOR_MS &&
          page.component !== 'Projects/Index'
        ) {
          // A page without the rail: go to the projects page, which has the button (or Connect Slack in its place).
          visited = true
          router.visit(projects.index())
        }
      }
      const now = performance.now()
      const dt = Math.min((now - last) / 1000, 1 / 30)
      last = now
      if (target) {
        const r = target.getBoundingClientRect()
        const to: Rect = { x: r.left - PAD, y: r.top - PAD, w: r.width + PAD * 2, h: r.height + PAD * 2 }
        for (const k of ['x', 'y', 'w', 'h'] as const) {
          if (prefersReducedMotion()) edges[k].pos = to[k]
          else step(edges[k], to[k], dt)
        }
        hole = { x: edges.x.pos, y: edges.y.pos, w: Math.max(edges.w.pos, 0), h: Math.max(edges.h.pos, 0) }
        tour.lastHole = hole
        pointUp = r.top < 120
        pointLeft = name === 'projects-tab'
      }
      frame = requestAnimationFrame(track)
    }
    frame = requestAnimationFrame(track)

    return () => {
      cancelAnimationFrame(frame)
      target?.removeEventListener('click', onClick)
      document.body.style.paddingBottom = ''
      tour.spotlight = false
    }
  })

  // The dark layer with the window cut out of it. Clipping also limits where it can be clicked, so clicks in the
  // window reach the page.
  const clip = $derived.by(() => {
    const { x, y, w, h } = hole
    const r = Math.min(RADIUS, w / 2, h / 2)
    const W = innerWidth
    const H = innerHeight
    return `path(evenodd, "M0 0H${W}V${H}H0Z M${x + r} ${y}H${x + w - r}A${r} ${r} 0 0 1 ${x + w} ${y + r}V${y + h - r}A${r} ${r} 0 0 1 ${x + w - r} ${y + h}H${x + r}A${r} ${r} 0 0 1 ${x} ${y + h - r}V${y + r}A${r} ${r} 0 0 1 ${x + r} ${y}Z")`
  })
</script>

{#snippet star(className: string)}
  <svg aria-hidden="true" viewBox="0 0 29.1 29.1" class="tour-twinkle absolute size-4 rotate-45 {className}">
    <path d={starPath} fill="#F9AF3F" />
  </svg>
{/snippet}

<div class="pointer-events-none fixed inset-0 z-[5]" aria-hidden="true">
  <div
    class="tour-fade pointer-events-auto absolute inset-0"
    style:background={DIM}
    style:clip-path={clip}
  ></div>

  {#if ready}
    <div
      class="absolute"
      style:left="{hole.x}px"
      style:top="{hole.y}px"
      style:width="{hole.w}px"
      style:height="{hole.h}px"
    >
      <div class="tour-ring absolute inset-0 rounded-[18px] border-[3px] border-[#F9AF3F]"></div>
      {#each ['-top-2 -left-2 border-t-4 border-l-4 rounded-tl-xl', '-top-2 -right-2 border-t-4 border-r-4 rounded-tr-xl', '-bottom-2 -left-2 border-b-4 border-l-4 rounded-bl-xl', '-right-2 -bottom-2 border-r-4 border-b-4 rounded-br-xl'] as corner, i (i)}
        <span class="tour-corner absolute size-6 border-cream {corner}" style:--i={i}></span>
      {/each}
      {@render star('-top-5 -right-5')}
      {@render star('-bottom-5 -left-5 [animation-delay:0.6s]')}

      <svg
        viewBox="0 0 40 30"
        class={[
          'tour-arrow absolute h-8 w-11',
          pointLeft
            ? 'tour-arrow-side top-1/2 left-full ml-4 -translate-y-1/2 rotate-90'
            : pointUp
              ? 'top-full left-1/2 mt-5 -translate-x-1/2 rotate-180'
              : 'bottom-full left-1/2 mb-5 -translate-x-1/2',
        ]}
      >
        <path
          d="M4 3 H36 Q39 3 37 6 L22 26 Q20 28.5 18 26 L3 6 Q1 3 4 3Z"
          fill="#F9AF3F"
          stroke="#11163f"
          stroke-width="2.5"
        />
      </svg>
    </div>
  {/if}
</div>

<style>
  .tour-fade {
    animation: tour-fade 0.35s ease-out both;
  }
  @keyframes tour-fade {
    from {
      opacity: 0;
    }
  }
  /* The frame breathes and glows. */
  .tour-ring {
    box-shadow:
      0 0 18px rgba(249, 175, 63, 0.75),
      inset 0 0 14px rgba(249, 175, 63, 0.35);
    animation: tour-ring 1.4s ease-in-out infinite;
  }
  @keyframes tour-ring {
    50% {
      transform: scale(1.04);
      box-shadow:
        0 0 30px rgba(249, 175, 63, 0.95),
        inset 0 0 18px rgba(249, 175, 63, 0.5);
    }
  }
  /* Reticle corners closing in on the button, in turn. */
  .tour-corner {
    animation: tour-corner 1.4s ease-in-out infinite;
    animation-delay: calc(var(--i) * 0.08s);
  }
  @keyframes tour-corner {
    50% {
      translate: var(--tx, 0) var(--ty, 0);
    }
  }
  .tour-corner:nth-of-type(1) {
    --tx: 4px;
    --ty: 4px;
  }
  .tour-corner:nth-of-type(2) {
    --tx: -4px;
    --ty: 4px;
  }
  .tour-corner:nth-of-type(3) {
    --tx: 4px;
    --ty: -4px;
  }
  .tour-corner:nth-of-type(4) {
    --tx: -4px;
    --ty: -4px;
  }
  .tour-arrow {
    filter: drop-shadow(0 0 8px rgba(249, 175, 63, 0.8));
    animation: tour-bob 0.7s ease-in-out infinite alternate;
  }
  @keyframes tour-bob {
    to {
      transform: translateY(-10px);
    }
  }
  .tour-arrow.rotate-180 {
    animation-name: tour-bob-up;
  }
  .tour-arrow-side {
    animation-name: tour-bob-side;
  }
  @keyframes tour-bob-side {
    to {
      transform: translateX(10px);
    }
  }
  @keyframes tour-bob-up {
    to {
      transform: translateY(-10px);
    }
  }
  .tour-twinkle {
    animation: tour-twinkle 1.2s ease-in-out infinite;
  }
  @keyframes tour-twinkle {
    50% {
      transform: rotate(90deg) scale(0.4);
      opacity: 0.5;
    }
  }
  @media (prefers-reduced-motion: reduce) {
    .tour-ring,
    .tour-corner,
    .tour-arrow,
    .tour-twinkle {
      animation: none;
    }
  }
</style>
