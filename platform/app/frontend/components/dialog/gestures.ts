import { styler, type Target, type Transition } from './motion'

// motion/react's whileHover / whileTap / whileFocus as an attachment. Like motion, a gesture only overrides the
// values it names, later gestures win (focus < hover < tap), and a value no active state names returns to `rest`.
type Config = {
  rest: Target
  hover?: Target
  press?: Target
  focus?: Target
  transition?: Transition
}

type Active = { hover: boolean; press: boolean; focus: boolean; attached: boolean }

const states = new WeakMap<Element, Active>()
const FALLBACK: Record<string, number> = { scale: 1 }

export function gestures(config: Config) {
  return (el: HTMLElement) => {
    let active = states.get(el)
    const first = !active
    if (!active) {
      active = { hover: false, press: false, focus: false, attached: true }
      states.set(el, active)
    }
    const state = active
    const s = styler(el)

    const target = () => {
      const keys = new Set(
        [config.rest, config.focus, config.hover, config.press].flatMap((t) => (t ? Object.keys(t) : [])),
      )
      const layers = [
        state.press && config.press,
        state.hover && config.hover,
        state.focus && config.focus,
        config.rest,
      ].filter(Boolean) as Target[]
      const out: Target = {}
      for (const key of keys) {
        const layer = layers.find((l) => key in l)
        out[key] = layer ? layer[key] : (FALLBACK[key] ?? 0)
      }
      return out
    }
    const update = () => s.animate(target(), config.transition)

    if (first) s.set(target())
    else update()

    const on = <K extends keyof HTMLElementEventMap>(
      node: EventTarget,
      type: K,
      fn: (e: HTMLElementEventMap[K]) => void,
    ) => {
      node.addEventListener(type, fn as EventListener)
      return () => node.removeEventListener(type, fn as EventListener)
    }

    const release = () => {
      if (!state.press) return
      state.press = false
      update()
    }

    const offs = [
      on(el, 'pointerenter', (e) => {
        if (!config.hover || e.pointerType === 'touch') return
        state.hover = true
        update()
      }),
      on(el, 'pointerleave', (e) => {
        if (e.pointerType === 'touch' || !state.hover) return
        state.hover = false
        update()
      }),
      on(el, 'pointerdown', (e) => {
        if (!config.press || e.button !== 0) return
        state.press = true
        update()
      }),
      on(window as unknown as HTMLElement, 'pointerup', release),
      on(window as unknown as HTMLElement, 'pointercancel', release),
      on(el, 'keydown', (e) => {
        if (!config.press || e.key !== 'Enter' || e.repeat) return
        state.press = true
        update()
      }),
      on(el, 'keyup', (e) => {
        if (e.key === 'Enter') release()
      }),
      on(el, 'focus', () => {
        if (!config.focus || !el.matches(':focus-visible')) return
        state.focus = true
        update()
      }),
      on(el, 'blur', () => {
        if (!state.focus) return
        state.focus = false
        update()
      }),
    ]

    return () => offs.forEach((off) => off())
  }
}
