// Where each card of the landing page's Past projects wheel stands (components/PastProjects.svelte). The cards stand
// round the rim of a circle whose centre is far below the screen, so they curve down and lean outwards either side
// of the one at the top, which is lifted and a little larger. Everything is in px and scales with the card.

export type Wheel = { width: number; height: number; spacing: number; radius: number; lift: number }
// the box the cards turn in; top is the room above the cards for the lifted one
export type Stage = { width: number; height: number; top: number }

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

// A card's dimming layer and framed card (components/PastProjectCard.svelte), found once. Their opacity and mask are
// set on them directly rather than through custom properties, which would restyle and repaint the whole card every
// frame. Only a card that has rendered both is remembered; until then it goes undimmed and unmasked.
type Parts = { shade: HTMLElement; card: HTMLElement }
const parts = new WeakMap<HTMLElement, Parts>()
function partsOf(el: HTMLElement): Parts | undefined {
  let found = parts.get(el)
  if (!found) {
    const shade = el.querySelector<HTMLElement>('[data-shade]')
    const card = el.querySelector<HTMLElement>('[data-card]')
    if (!shade || !card) return undefined
    found = { shade, card }
    parts.set(el, found)
  }
  return found
}

const crossfade = 0.05 // cards of turning over which two overlapping cards trade places
const soft = 10 // px of the overlap's fade, so its edge isn't a hard line

// What was last written to each element, so a frame only writes what changed. Every write costs a style recalc, and
// cards far out on the rim barely change at all.
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
//
// The cards also fade out towards the stage's sides and bottom, each as a whole: at the sides by where its outer edge
// is, so it has gone before the stage clips it, and at the bottom by where its middle is. A mask over the stage would
// fade them more evenly, but it redraws every card into it on every frame.
export function placeCard(el: HTMLElement, s: number, rank: number, wheel: Wheel, stage: Stage) {
  const { width, height, spacing, radius, lift } = wheel
  const away = Math.abs(s)
  const near = Math.max(0, 1 - away)
  const step = spacing / radius // radians between cards
  const angle = s * step
  const x = radius * Math.sin(angle)
  const y = radius * (1 - Math.cos(angle)) - near * lift
  const outer = Math.abs(x) + width / 2
  const sides = Math.min(1, (stage.width / 2 - outer) / (stage.width * 0.15)) // gone as it reaches the stage's edge
  const bottom = Math.min(1, (stage.height - (stage.top + height / 2 + y)) / (stage.height * 0.3)) // the last 30%
  // to a thousandth, finer than can be seen, so a card that has stopped changing stops being written
  const opacity = Math.max(0, (1 - smoothstep(3.6, 5.6, away)) * Math.min(sides, bottom)).toFixed(3)
  const hidden = Number(opacity) === 0
  write(el, 'visibility', hidden ? 'hidden' : '')
  if (hidden) return
  write(el, 'transform', `translate3d(${x}px, ${y}px, 0) rotate(${angle}rad) scale(${1 + near * 0.05})`)
  write(el, 'opacity', opacity)
  write(el, 'z-index', String(1000 - rank))
  const found = partsOf(el)
  if (!found) return
  const { shade, card } = found
  write(shade, 'opacity', (smoothstep(0, 2.5, away) * 0.6).toFixed(3))

  const edge = away < 0.5 ? 0.5 + 0.5 * smoothstep(0.5, 0.5 - crossfade, away) : 1
  if (edge < 1) {
    // the card behind is on the side towards the middle, one step further round
    const direction = (s > 0 ? 270 : 90) - Math.sign(s) * ((step * 180) / Math.PI)
    const radians = (direction * Math.PI) / 180
    const line = width * Math.abs(Math.sin(radians)) + height * Math.abs(Math.cos(radians))
    const at = line / 2 + spacing - width / 2
    write(
      card,
      'mask-image',
      `linear-gradient(${direction}deg, #000 ${at - soft}px, rgb(0 0 0 / ${edge}) ${at}px)`,
    )
  } else write(card, 'mask-image', '')
}
