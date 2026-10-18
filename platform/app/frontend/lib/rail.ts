// The nav rail's feel (components/NavRail.svelte), shared with the settings categories: the label springs toward
// the content on hover and back on press, and a click flashes the glow.
import { Spring, prefersReducedMotion } from 'svelte/motion'

// Pixels the label springs toward the content on hover and back against the rail on press.
const HOVER_NUDGE = 5
const PRESS_NUDGE = -3

export const nudgeSpring = () => new Spring(0, { stiffness: 0.2, damping: 0.6 })

// As in jolts: a click flashes the glow to full brightness for a beat, then the item stays dark until the pointer
// leaves, so hovering through the navigation doesn't count.
function flash(el: HTMLElement) {
  el.classList.remove('rail-flash')
  void el.offsetWidth // restart the animation if mid-flash
  el.classList.add('rail-flash')

  let gone = false
  el.addEventListener(
    'pointerleave',
    () => {
      gone = true
      el.classList.remove('rail-hold')
    },
    { once: true },
  )
  setTimeout(() => {
    el.classList.remove('rail-flash')
    if (!gone) el.classList.add('rail-hold')
  }, 270)
}

export function flashOnClick(list: HTMLElement) {
  const onclick = (event: MouseEvent) => {
    const item = (event.target as Element).closest<HTMLElement>('.rail-item')
    if (item) flash(item)
  }
  list.addEventListener('click', onclick)
  return () => list.removeEventListener('click', onclick)
}

// The rail lives in the persistent layout, so the same spring keeps its velocity across an Inertia page switch.
export function nudge(x: Spring<number>) {
  return (li: HTMLElement) => {
    let hovered = false
    let pressed = false
    const settle = () => {
      const target = pressed ? PRESS_NUDGE : hovered ? HOVER_NUDGE : 0
      x.set(target, { instant: prefersReducedMotion.current })
    }
    const handlers: [string, (event: PointerEvent) => void][] = [
      ['pointerenter', (e) => ((hovered = e.pointerType === 'mouse'), settle())],
      ['pointerleave', () => ((hovered = pressed = false), settle())],
      ['pointerdown', () => ((pressed = true), settle())],
      ['pointerup', () => ((pressed = false), settle())],
      ['pointercancel', () => ((pressed = false), settle())],
    ]
    for (const [type, fn] of handlers) li.addEventListener(type, fn as EventListener)
    return () => {
      for (const [type, fn] of handlers) li.removeEventListener(type, fn as EventListener)
    }
  }
}
