<script lang="ts">
  // The landing hero's painted scene. The backdrop layers share one 2360x1640 canvas, so they stay lined up as long
  // as they're all cropped the same way. Each layer drifts away from the cursor by its depth, nearer ones more, for a
  // slight parallax. Goes inside a positioned element; the backdrop sits behind it and the soup in front.
  import { onMount } from 'svelte'
  import sky from '@/assets/hero/starry-bg.webp'
  import flowers from '@/assets/hero/flowers.webp'
  import building1 from '@/assets/hero/building-1.webp'
  import building2 from '@/assets/hero/building-2.webp'
  import building4 from '@/assets/hero/building-4.webp'
  import building5 from '@/assets/hero/building-5.webp'
  import building6 from '@/assets/hero/building-6.webp'
  import building7 from '@/assets/hero/building-7.webp'
  import soup from '@/assets/hero/soup-falling.webp'
  import sparkles from '@/assets/hero/soup-falling-sparkles.webp'

  // px the depth-1 layer moves when the cursor is at the edge of the screen. The buildings are stacked in the Figma
  // frame's order (Fallen, node 214:118), already rotated the way it places them, and each one higher in the stack is
  // nearer and moves more. The sky barely moves, and neither do the flowers, which are drawn over everything.
  const shift = 32
  const backdrop = [
    { src: sky, depth: 0.05 },
    { src: building1, depth: 0.35 },
    { src: building6, depth: 0.45 },
    { src: building2, depth: 0.6 },
    { src: building4, depth: 0.7 },
    { src: building5, depth: 0.85 },
    { src: building7, depth: 1 },
    { src: flowers, depth: 0.1 },
  ]

  let root: HTMLDivElement

  onMount(() => {
    if (matchMedia('(prefers-reduced-motion: reduce)').matches) return
    const target = [0, 0]
    const value = [0, 0]
    let frame = 0
    let last = 0

    // ease towards the cursor, frame-rate independent, and stop once settled so an idle page costs nothing
    const render = (now: number) => {
      const delta = Math.min((now - last) / 1000, 0.1)
      last = now
      const ease = 1 - Math.exp(-delta * 5)
      value[0] += (target[0] - value[0]) * ease
      value[1] += (target[1] - value[1]) * ease
      root.style.setProperty('--parallax-x', `${-value[0] * shift}px`)
      root.style.setProperty('--parallax-y', `${-value[1] * shift}px`)
      const settled = Math.abs(target[0] - value[0]) + Math.abs(target[1] - value[1]) < 0.001
      frame = settled ? 0 : requestAnimationFrame(render)
    }
    const follow = (x: number, y: number) => {
      target[0] = x
      target[1] = y
      if (frame) return
      last = performance.now()
      frame = requestAnimationFrame(render)
    }

    // touch has no hover, and dragging a finger would only jerk the layers around
    const onPointerMove = (event: PointerEvent) => {
      if (event.pointerType !== 'mouse') return
      follow((event.clientX / innerWidth) * 2 - 1, (event.clientY / innerHeight) * 2 - 1)
    }
    const onMouseLeave = () => follow(0, 0)
    addEventListener('pointermove', onPointerMove)
    document.addEventListener('mouseleave', onMouseLeave)

    return () => {
      cancelAnimationFrame(frame)
      removeEventListener('pointermove', onPointerMove)
      document.removeEventListener('mouseleave', onMouseLeave)
    }
  })

  const parallax = (depth: number) =>
    `transform: translate3d(calc(var(--parallax-x, 0px) * ${depth}), calc(var(--parallax-y, 0px) * ${depth}), 0)`
</script>

<!-- display: contents so the offsets reach both the backdrop and the soup without adding a box -->
<div bind:this={root} class="contents" aria-hidden="true">
  <div class="absolute inset-0 -z-1 overflow-hidden bg-[#0b0f4a] pointer-events-none select-none">
    {#each backdrop as layer (layer.src)}
      <!-- bleeds past the edges by the full shift so moving never uncovers them -->
      <img
        src={layer.src}
        alt=""
        decoding="async"
        class="absolute -inset-8 h-[calc(100%+4rem)] w-[calc(100%+4rem)] max-w-none object-cover object-right-top will-change-transform"
        style={parallax(layer.depth)}
      />
    {/each}
  </div>

  <!-- the sparkles image is 359x467 and sits 90px above the 369x390 soup, in a 375x480 box -->
  <div
    class="absolute bottom-10 left-1/2 w-72 aspect-375/480 -translate-x-1/2 pointer-events-none select-none"
  >
    <img src={sparkles} alt="" class="absolute top-0 left-[1.3%] w-[95.7%]" style={parallax(1.3)} />
    <img src={soup} alt="" class="absolute top-[18.75%] left-0 w-[98.4%]" style={parallax(1.15)} />
  </div>
</div>
