// Where each card of the landing page's Past projects wheel stands (components/PastProjects.svelte). The cards stand
// round the rim of a circle whose centre is far below the screen, so they curve down and lean outwards either side
// of the one at the top, which is lifted and a little larger. Everything is in px and scales with the card.

export type Wheel = { width: number; height: number; spacing: number; radius: number; lift: number }

export function wheelFor(width: number): Wheel {
  return {
    width,
    height: width * (4 / 3),
    spacing: width * 0.86, // along the rim between cards
    radius: width * 7.5,
    lift: width * 0.1, // how far the middle card rises out of the row
  }
}

export const smoothstep = (a: number, b: number, v: number) => {
  const t = Math.min(1, Math.max(0, (v - a) / (b - a)))
  return t * t * (3 - 2 * t)
}

const crossfade = 0.05 // cards of turning over which two overlapping cards trade places
const soft = 10 // px of the overlap's fade, so its edge isn't a hard line

// What was last written to each card, so a frame only writes what changed. Every write costs a style recalc, and the
// custom properties are inherited, so changing one recalculates the whole card beneath it. Cards far out on the rim
// barely change at all.
const written = new WeakMap<HTMLElement, Map<string, string>>()

function write(el: HTMLElement, property: string, value: string) {
  let values = written.get(el)
  if (!values) written.set(el, (values = new Map()))
  if (values.get(property) === value) return
  values.set(property, value)
  if (value) el.style.setProperty(property, value)
  else el.style.removeProperty(property)
}

// Puts a card s places from the middle (fractional while the wheel turns; negative to the left) and `rank` places
// from the front. The card nearer the middle goes on top, so the order only changes as the two either side of the
// middle trade places as they pass it; a z-index that changed every frame would have the browser rebuild its layers
// every frame. A swap of z-index alone would flick the overlap from one card to the other in a frame, so for a moment either side
// of the swap the front card's overlapping edge turns half see-through, through a mask along the edge of the card
// behind (tilted with it, as the cards fan out). At the swap both show at half, so it crossfades instead.
export function placeCard(el: HTMLElement, s: number, rank: number, wheel: Wheel) {
  const { width, height, spacing, radius, lift } = wheel
  const away = Math.abs(s)
  const near = Math.max(0, 1 - away)
  const step = spacing / radius // radians between cards
  const angle = s * step
  const x = radius * Math.sin(angle)
  const y = radius * (1 - Math.cos(angle)) - near * lift
  const hidden = away > 5.7
  write(el, 'visibility', hidden ? 'hidden' : '')
  if (hidden) return
  write(el, 'transform', `translate3d(${x}px, ${y}px, 0) rotate(${angle}rad) scale(${1 + near * 0.05})`)
  // to a thousandth, finer than can be seen, so a card that has stopped changing stops being written
  write(el, 'opacity', (1 - smoothstep(3.6, 5.6, away)).toFixed(3))
  write(el, 'z-index', String(1000 - rank))
  write(el, '--near', near.toFixed(3))
  write(el, '--shade', smoothstep(0, 2.5, away).toFixed(3))
  // the sparkles only twinkle on a card that shows them
  write(el, '--twinkle', near > 0 ? 'running' : 'paused')

  const edge = away < 0.5 ? 0.5 + 0.5 * smoothstep(0.5, 0.5 - crossfade, away) : 1
  if (edge < 1) {
    // the card behind is on the side towards the middle, one step further round
    const direction = (s > 0 ? 270 : 90) - Math.sign(s) * ((step * 180) / Math.PI)
    const radians = (direction * Math.PI) / 180
    const line = width * Math.abs(Math.sin(radians)) + height * Math.abs(Math.cos(radians))
    const at = line / 2 + spacing - width / 2
    write(el, '--mask', `linear-gradient(${direction}deg, #000 ${at - soft}px, rgb(0 0 0 / ${edge}) ${at}px)`)
  } else write(el, '--mask', '')
}
