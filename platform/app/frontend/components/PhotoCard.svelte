<script lang="ts" module>
  let top = 40 // the card picked up last goes over the others
</script>

<script lang="ts">
  // A photo card that can be picked up and moved. Picking it up tilts it a little round the point you grabbed, the far
  // side dipping as if it had weight; letting go eases it back to its resting angle and drops it a few px, falling the
  // last bit onto the table.
  import type { Snippet } from 'svelte'

  let {
    class: className = '',
    rotate = 0,
    shift = [0, 0],
    children,
  }: {
    class?: string // size, aspect ratio and stacking
    rotate?: number // resting angle in degrees
    shift?: [number, number] // offset from its place in the layout, in % of its own size
    children?: Snippet
  } = $props()

  const tilt = 0.06 // radians the card tilts while held
  const ease = 12 // how quickly it tilts and untilts, 1/s
  const drop = 6 // px the card falls when let go
  const gravity = 2000 // px/s², so the fall takes under a tenth of a second

  let card: HTMLDivElement
  let x = $state(0) // px dragged from the layout position
  let y = $state(0)
  let swing = $state(0) // radians away from the resting angle
  let target = 0
  let origin: [number, number] | undefined = $state() // the pivot, in px inside the card; centre until first grab
  let z: number | undefined = $state()

  let held = false
  let falling = 0 // px still to fall
  let fallSpeed = 0 // px/s
  let frame = 0
  let last = 0
  const reducedMotion =
    typeof matchMedia !== 'undefined' && matchMedia('(prefers-reduced-motion: reduce)').matches

  function onPointerDown(event: PointerEvent) {
    if (event.button !== 0) return
    event.preventDefault()
    card.setPointerCapture(event.pointerId)
    held = true
    falling = 0
    z = ++top

    // pivot on the grabbed point, moving the card to make up for it so nothing jumps. offsetX is in the card's own
    // untransformed space (the content ignores the pointer, so the card is always the target).
    const [w, h] = [card.offsetWidth, card.offsetHeight]
    const [ox, oy] = origin ?? [w / 2, h / 2]
    const [nx, ny] = [event.offsetX + card.clientLeft, event.offsetY + card.clientTop]
    const angle = (rotate * Math.PI) / 180 + swing
    const [dx, dy] = [ox - nx, oy - ny]
    const [cos, sin] = [Math.cos(angle), Math.sin(angle)]
    x += dx - (cos * dx - sin * dy)
    y += dy - (sin * dx + cos * dy)
    origin = [nx, ny]

    // the centre's horizontal side of the hand, as the card sits now, is the side that dips
    const right = cos * (w / 2 - nx) - sin * (h / 2 - ny)
    target = Math.sign(right) * tilt
    start()
  }

  function onPointerMove(event: PointerEvent) {
    if (!held) return
    x += event.movementX
    y += event.movementY
  }

  function onPointerUp() {
    held = false
    target = 0
    falling = drop
    fallSpeed = 0
    start()
  }

  function start() {
    if (frame || reducedMotion) return
    last = performance.now()
    const step = (now: number) => {
      const delta = Math.min((now - last) / 1000, 0.1)
      last = now
      swing += (target - swing) * (1 - Math.exp(-delta * ease))
      if (falling > 0) {
        fallSpeed += gravity * delta
        const distance = Math.min(fallSpeed * delta, falling)
        y += distance
        falling -= distance
      }
      const settled = Math.abs(target - swing) < 0.0005 && falling === 0
      if (settled) swing = target
      frame = settled ? 0 : requestAnimationFrame(step)
    }
    frame = requestAnimationFrame(step)
  }

  $effect(() => () => cancelAnimationFrame(frame))
</script>

<div
  bind:this={card}
  role="presentation"
  class="relative touch-none select-none cursor-grab active:cursor-grabbing rounded-lg border-4 border-[#F09834] bg-beige {className}"
  style:z-index={z}
  style:transform-origin={origin ? `${origin[0]}px ${origin[1]}px` : undefined}
  style:transform="translate(calc({shift[0]}% + {x}px), calc({shift[1]}% + {y}px)) rotate({rotate}deg) rotate({swing}rad)"
  onpointerdown={onPointerDown}
  onpointermove={onPointerMove}
  onpointerup={onPointerUp}
  onpointercancel={onPointerUp}
>
  {#if children}
    <div class="pointer-events-none absolute inset-0 overflow-hidden rounded-sm">{@render children()}</div>
  {/if}
</div>
