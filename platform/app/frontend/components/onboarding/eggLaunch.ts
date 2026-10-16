import { animate } from 'motion'
import { starPath } from '@/components/GoldFrame.svelte'
import { prefersReducedMotion, styler } from '@/components/dialog/motion'

// The picked egg winds up, flies in an arc to the talking egg and replaces it: a flash, a ring and a burst of stars
// where it lands, the stage shakes, and the new egg lands with a squash. Runs in its own layer on <body> so it
// outlives the picker, which closes the moment the egg lands.
const WIND_UP = 0.32
const FLIGHT = 0.55
const ARC = 170 // px the path bows up above the higher of the two eggs
const SPINS = 2
const TRAIL_EVERY_MS = 22
const BURST = 12
const GOLD = '#F9AF3F'

type Point = { x: number; y: number }

export async function launchEgg({
  from,
  src,
  onImpact,
}: {
  from: HTMLElement
  src: string
  onImpact: () => void
}) {
  const target = [...document.querySelectorAll<HTMLElement>('[data-dialog-avatar]')].at(-1)
  if (!target || prefersReducedMotion()) {
    onImpact()
    return
  }

  const a = from.getBoundingClientRect()
  const b = target.getBoundingClientRect()
  const layer = element('div', 'position:fixed;inset:0;pointer-events:none;z-index:60')
  document.body.append(layer)

  const egg = element(
    'img',
    `position:absolute;left:${a.left}px;top:${a.top}px;width:${a.width}px;height:${a.height}px;transform-origin:50% 100%;filter:drop-shadow(0 0 14px rgba(249,175,63,0.9))`,
  ) as HTMLImageElement
  egg.src = src
  layer.append(egg)
  from.style.visibility = 'hidden'
  const s = styler(egg)

  // Crouch, then spring up off the ground.
  await s.animate(
    { scaleY: [1, 0.76, 1.14], scaleX: [1, 1.2, 0.9], y: [0, 6, -14] },
    { duration: WIND_UP, ease: 'easeInOut', times: [0, 0.55, 1] },
  )

  egg.style.transformOrigin = '50% 50%'
  const start = centre(a)
  const end = centre(b)
  const control = { x: (start.x + end.x) / 2, y: Math.min(start.y, end.y) - ARC }
  const grow = b.height / a.height
  let lastTrail = 0

  await animate(0, 1, {
    duration: FLIGHT,
    ease: [0.5, 0, 0.8, 0.3],
    onUpdate: (t) => {
      const p = bezier(start, control, end, t)
      const squash = 1 - t
      s.set({
        x: p.x - start.x,
        y: p.y - start.y - 14 * squash,
        scale: 1 + (grow - 1) * t,
        scaleX: 1 - 0.1 * squash,
        scaleY: 1 + 0.14 * squash,
        rotate: -360 * SPINS * t,
      })
      const now = performance.now()
      if (now - lastTrail > TRAIL_EVERY_MS) {
        lastTrail = now
        trail(layer, p)
      }
    },
  })

  onImpact()
  impact(layer, end, b.height)
  const stage = target.closest<HTMLElement>('[data-dialog-stage]')
  if (stage) styler(stage).animate({ x: [0, -12, 10, -7, 4, -2, 0] }, { duration: 0.42, ease: 'easeOut' })

  // The new egg is in the DOM a frame after the dialog moves on; hand over to it and squash it on landing.
  requestAnimationFrame(() => {
    const landed = [...document.querySelectorAll<HTMLImageElement>('[data-dialog-avatar]')].find(
      (img) => img.getAttribute('src') === src,
    )
    if (landed?.parentElement)
      styler(landed.parentElement).animate(
        { scaleY: [0.72, 1.12, 1], scaleX: [1.25, 0.94, 1] },
        { duration: 0.55, ease: [0.22, 1, 0.36, 1], times: [0, 0.45, 1] },
      )
    s.animate({ opacity: 0 }, { duration: 0.08 }).then(() => egg.remove())
  })

  setTimeout(() => layer.remove(), 1200)
}

function impact(layer: HTMLElement, at: Point, size: number) {
  const flash = place(
    layer,
    at,
    size * 1.5,
    'border-radius:50%;background:radial-gradient(closest-side,#fff,rgba(255,236,190,0.85) 35%,rgba(249,175,63,0.35) 65%,transparent)',
  )
  styler(flash).animate({ scale: [0.3, 1.5], opacity: [1, 0] }, { duration: 0.45, ease: 'easeOut' })

  const ring = place(layer, at, size, `border-radius:50%;border:4px solid ${GOLD}`)
  styler(ring).animate({ scale: [0.2, 1.9], opacity: [1, 0] }, { duration: 0.55, ease: [0.16, 1, 0.3, 1] })

  for (let i = 0; i < BURST; i++) {
    const angle = (i / BURST) * Math.PI * 2 + Math.random() * 0.4
    const reach = size * (0.55 + Math.random() * 0.45)
    const star = place(layer, at, 14 + Math.random() * 12, '', starSvg())
    styler(star).animate(
      { x: Math.cos(angle) * reach, y: Math.sin(angle) * reach, scale: [0, 1.3, 0], rotate: 180 },
      { duration: 0.7, ease: [0.16, 1, 0.3, 1] },
    )
  }
}

function trail(layer: HTMLElement, at: Point) {
  const spark = place(layer, at, 8 + Math.random() * 10, '', starSvg())
  styler(spark)
    .animate(
      { scale: [1, 0], opacity: [0.9, 0], y: 8 + Math.random() * 12, rotate: 90 },
      { duration: 0.5, ease: 'easeOut' },
    )
    .then(() => spark.remove())
}

function place(layer: HTMLElement, at: Point, size: number, css: string, html = '') {
  const el = element(
    'div',
    `position:absolute;left:${at.x - size / 2}px;top:${at.y - size / 2}px;width:${size}px;height:${size}px;${css}`,
  )
  el.innerHTML = html
  layer.append(el)
  return el
}

const starSvg = () =>
  `<svg viewBox="0 0 29.1 29.1" style="width:100%;height:100%;transform:rotate(45deg)"><path d="${starPath}" fill="${GOLD}"/></svg>`

function element(tag: string, css: string) {
  const el = document.createElement(tag)
  el.style.cssText = css
  return el
}

const centre = (r: DOMRect): Point => ({ x: r.left + r.width / 2, y: r.top + r.height / 2 })

function bezier(p0: Point, p1: Point, p2: Point, t: number): Point {
  const u = 1 - t
  return {
    x: u * u * p0.x + 2 * u * t * p1.x + t * t * p2.x,
    y: u * u * p0.y + 2 * u * t * p1.y + t * t * p2.y,
  }
}
