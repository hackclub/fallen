// The landing page cards' hover, after counterspell.hackclub.com's guild cards: the card tilts towards the cursor, the
// side under it dipping away, and grows a little. It only sets custom properties; the `holo-card` utility turns them
// into the tilt and HoloShine.svelte into the glare and the bar of light. maxTilt is in degrees at a card's edge.
const properties = ['--rx', '--ry', '--scale', '--glare-x', '--glare-opacity', '--shine-x']

export function holo(card: HTMLElement, { maxTilt = 18 }: { maxTilt?: number } = {}) {
  function move(event: PointerEvent) {
    if (event.pointerType === 'touch') return leave()
    const box = card.getBoundingClientRect()
    const x = (event.clientX - box.left) / box.width
    const y = (event.clientY - box.top) / box.height
    card.style.setProperty('--rx', `${(0.5 - y) * 2 * maxTilt}deg`)
    card.style.setProperty('--ry', `${(x - 0.5) * 2 * maxTilt}deg`)
    card.style.setProperty('--scale', '1.1')
    // a soft glare along the top edge, away from the cursor, while the cursor is in the card's upper half
    card.style.setProperty('--glare-x', `${(1 - x) * 50}%`)
    card.style.setProperty('--glare-opacity', `${Math.max(0, 0.5 - y)}`)
    // a faint diagonal bar of light, off the card until the cursor moves it on
    card.style.setProperty('--shine-x', `${-100 - (x - 0.5) * 150 - (y - 0.5) * 150}%`)
  }

  function leave() {
    for (const property of properties) card.style.removeProperty(property)
  }

  card.addEventListener('pointermove', move)
  card.addEventListener('pointerleave', leave)
  return {
    destroy() {
      card.removeEventListener('pointermove', move)
      card.removeEventListener('pointerleave', leave)
    },
  }
}
