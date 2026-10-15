<script lang="ts">
  // A thin line trailing the cursor, drawn like pencil. Each piece is a few hairline passes that wander a little off
  // the true path, painted with a speckled grain so they read as graphite rather than a clean vector stroke. The
  // wander is re-rolled a few times a second so the line "boils" like hand-drawn animation. Points fade after a
  // moment, so the line shrinks into the cursor when it stops. Gold, the landing page's border colour (#E98C21).
  // The page is dark throughout; on a light background it would need a different colour.
  import { onMount } from 'svelte'

  const life = 0.35 // seconds a point stays on the line
  const reach = 320 // px the line can trail behind the cursor, however fast it moves; it thins out towards this
  const passes = 2 // overlapping hairlines per piece, like going over a pencil line twice
  const jitter = 0.4 // px each pass can sit off the true path
  const boil = 0.12 // seconds between re-rolls of the jitter
  const width = 2 // px of each pass at the cursor end; the tail thins to nothing
  const grain = 0.88 // share of the grain texture's specks that are filled in
  const step = 2 // px between samples of the smoothed curve; each sample fades on its own

  let canvas: HTMLCanvasElement

  onMount(() => {
    // touch has no cursor to follow, and the boil is motion for its own sake
    if (!matchMedia('(pointer: fine)').matches || matchMedia('(prefers-reduced-motion: reduce)').matches)
      return
    const ctx = canvas.getContext('2d')
    if (!ctx) return

    // speckled graphite: a small tile of random light specks, used as the stroke's paint
    const tile = document.createElement('canvas')
    tile.width = tile.height = 64
    const tileCtx = tile.getContext('2d')
    if (!tileCtx) return
    const specks = tileCtx.createImageData(64, 64)
    for (let i = 0; i < specks.data.length; i += 4) {
      specks.data.set([0xe9, 0x8c, 0x21, Math.random() < grain ? 120 + Math.random() * 135 : 0], i)
    }
    tileCtx.putImageData(specks, 0, 0)
    const pencil = ctx.createPattern(tile, 'repeat')
    if (!pencil) return

    type Point = { x: number; y: number; born: number; offsets: number[][] }
    const points: Point[] = []
    const roll = () =>
      Array.from({ length: passes }, () => [0, 0].map(() => (Math.random() * 2 - 1) * jitter))
    let frame = 0
    let rolled = 0

    const resize = () => {
      canvas.width = innerWidth * devicePixelRatio
      canvas.height = innerHeight * devicePixelRatio
      ctx.setTransform(devicePixelRatio, 0, 0, devicePixelRatio, 0, 0)
    }

    // a Catmull-Rom curve through one pass's points, sampled every `step` px, so the line bends smoothly however far
    // apart the pointer events land
    const smooth = (pass: number) => {
      const at = (i: number) => {
        const point = points[Math.max(0, Math.min(points.length - 1, i))]
        return [point.x + point.offsets[pass][0], point.y + point.offsets[pass][1]]
      }
      const curve = (a: number, b: number, c: number, d: number, t: number) =>
        0.5 *
        (2 * b + (c - a) * t + (2 * a - 5 * b + 4 * c - d) * t * t + (3 * b - a - 3 * c + d) * t * t * t)
      const samples: { x: number; y: number; born: number }[] = []
      if (!points.length) return samples
      for (let i = 0; i < points.length - 1; i++) {
        const [p0, p1, p2, p3] = [at(i - 1), at(i), at(i + 1), at(i + 2)]
        const count = Math.max(1, Math.ceil(Math.hypot(p2[0] - p1[0], p2[1] - p1[1]) / step))
        for (let k = 0; k < count; k++) {
          const t = k / count
          samples.push({
            x: curve(p0[0], p1[0], p2[0], p3[0], t),
            y: curve(p0[1], p1[1], p2[1], p3[1], t),
            born: points[i].born + (points[i + 1].born - points[i].born) * t,
          })
        }
      }
      const [x, y] = at(points.length - 1)
      samples.push({ x, y, born: points[points.length - 1].born })
      return samples
    }

    const draw = (now: number) => {
      while (points.length && now - points[0].born > life * 1000) points.shift()
      // px along the line from each point to the cursor. Points past `reach` are dropped, bar one to anchor the tail.
      const behind = new Array<number>(points.length).fill(0)
      for (let i = points.length - 2; i >= 0; i--)
        behind[i] = behind[i + 1] + Math.hypot(points[i + 1].x - points[i].x, points[i + 1].y - points[i].y)
      const cut = behind.findIndex((distance) => distance < reach)
      if (cut > 1) {
        points.splice(0, cut - 1)
        behind.splice(0, cut - 1)
      }
      if (now - rolled > boil * 1000) {
        rolled = now
        for (const point of points) point.offsets = roll()
      }

      ctx.clearRect(0, 0, innerWidth, innerHeight)
      // softened as it's drawn, so only the strokes are blurred: a CSS blur on the canvas would blur the whole screen
      // every frame the line moves
      ctx.filter = 'blur(0.6px)'
      ctx.strokeStyle = pencil
      // butt ends, because round caps overlap where the short pieces meet and bead the line
      ctx.lineCap = 'butt'
      // per pass, a short piece per sample, walking back from the cursor until the line is `reach` long. Each fades
      // by its age or its distance from the cursor, whichever is further along, so the tail tapers instead of popping.
      for (let pass = 0; pass < passes; pass++) {
        const samples = smooth(pass)
        let along = 0
        for (let i = samples.length - 1; i > 0; i--) {
          const [a, b] = [samples[i - 1], samples[i]]
          along += Math.hypot(b.x - a.x, b.y - a.y)
          if (along >= reach) break
          const fresh = Math.min(1 - (now - b.born) / (life * 1000), 1 - along / reach)
          if (fresh <= 0) continue
          ctx.globalAlpha = fresh
          ctx.lineWidth = width * (0.6 + 0.4 * fresh)
          ctx.beginPath()
          ctx.moveTo(a.x, a.y)
          ctx.lineTo(b.x, b.y)
          ctx.stroke()
        }
      }

      frame = points.length ? requestAnimationFrame(draw) : 0
      if (!frame) ctx.clearRect(0, 0, innerWidth, innerHeight)
    }

    const onPointerMove = (event: PointerEvent) => {
      if (event.pointerType !== 'mouse') return
      // the browser batches moves into one event per frame; the coalesced ones are the in-between positions
      const moves = event.getCoalescedEvents?.() ?? []
      for (const move of moves.length ? moves : [event]) {
        const last = points.at(-1)
        if (last && Math.hypot(move.clientX - last.x, move.clientY - last.y) < 3) continue
        points.push({ x: move.clientX, y: move.clientY, born: performance.now(), offsets: roll() })
      }
      frame ||= requestAnimationFrame(draw)
    }

    resize()
    addEventListener('resize', resize)
    addEventListener('pointermove', onPointerMove)
    return () => {
      cancelAnimationFrame(frame)
      removeEventListener('resize', resize)
      removeEventListener('pointermove', onPointerMove)
    }
  })
</script>

<canvas
  bind:this={canvas}
  class="pointer-events-none fixed inset-0 z-1001 h-screen w-screen"
  aria-hidden="true"
></canvas>
