import { animate, frame, motionValue, type AnimationPlaybackControls, type MotionValue } from 'motion'

// A thin stand-in for motion/react's <motion.div> on top of motion's own value animator, so springs, eases and
// interrupted velocities come out exactly as they do in the React version of this dialog (make/web). Each element
// keeps one MotionValue per animated property and rebuilds its transform in motion's order, so animating `y` on an
// element that also has `x` never clobbers it.

type Value = number | string
export type Target = Record<string, Value | Value[]>
// A motion transition, optionally with per-property overrides keyed by property name.
export type Transition = Record<string, unknown>

const TRANSFORM_ORDER = ['x', 'y', 'scale', 'scaleX', 'scaleY', 'rotate', 'skewX'] as const
const TRANSFORMS = new Set<string>(TRANSFORM_ORDER)
const DEFAULTS: Record<string, Value> = {
  x: 0,
  y: 0,
  scale: 1,
  scaleX: 1,
  scaleY: 1,
  rotate: 0,
  skewX: 0,
  opacity: 1,
}

const reducedQuery =
  typeof window === 'undefined' ? null : window.matchMedia('(prefers-reduced-motion: reduce)')
// MotionConfig reducedMotion="user": transforms jump, everything else still animates.
export const prefersReducedMotion = () => reducedQuery?.matches ?? false

const TRANSITION_KEYS = new Set([
  'type',
  'duration',
  'ease',
  'delay',
  'times',
  'repeat',
  'repeatType',
  'repeatDelay',
  'stiffness',
  'damping',
  'mass',
  'velocity',
  'bounce',
  'visualDuration',
  'restSpeed',
  'restDelta',
])

// motion/react's defaults when an animation names no transition.
function defaultTransition(key: string, keyframes: Value[]) {
  if (keyframes.length > 2) return { duration: 0.8 }
  if (TRANSFORMS.has(key)) {
    if (key.startsWith('scale')) {
      const target = keyframes[keyframes.length - 1]
      return {
        type: 'spring',
        stiffness: 550,
        damping: target === 0 ? 2 * Math.sqrt(550) : 30,
        restSpeed: 10,
      }
    }
    return { type: 'spring', stiffness: 500, damping: 25, restSpeed: 10 }
  }
  return { ease: [0.25, 0.1, 0.35, 1], duration: 0.3 }
}

function valueTransition(transition: Transition | undefined, key: string, keyframes: Value[]) {
  const own = transition?.[key] as Transition | undefined
  if (own) return own
  const base: Transition = {}
  let defined = false
  for (const [k, v] of Object.entries(transition ?? {})) {
    if (!TRANSITION_KEYS.has(k)) continue
    base[k] = v
    if (k !== 'delay') defined = true
  }
  return defined ? base : { ...defaultTransition(key, keyframes), ...base }
}

const unit = (key: string, value: Value) => {
  if (typeof value === 'string') return value
  if (key === 'x' || key === 'y') return `${value}px`
  if (key === 'rotate' || key === 'skewX') return `${value}deg`
  return String(value)
}

class Styler {
  private values = new Map<string, MotionValue<Value>>()
  private running = new Map<string, AnimationPlaybackControls>()
  private queued = false

  constructor(private el: HTMLElement | SVGElement) {}

  private value(key: string, from: Value) {
    let mv = this.values.get(key)
    if (!mv) {
      mv = motionValue<Value>(from)
      mv.on('change', () => this.schedule())
      this.values.set(key, mv)
    }
    return mv
  }

  set(target: Target) {
    for (const [key, raw] of Object.entries(target)) {
      const v = Array.isArray(raw) ? raw[raw.length - 1] : raw
      this.running.get(key)?.stop()
      this.running.delete(key)
      this.value(key, v).jump(v)
    }
    this.render()
  }

  animate(target: Target, transition?: Transition): Promise<unknown> {
    const reduced = prefersReducedMotion()
    const done: Promise<unknown>[] = []
    for (const [key, raw] of Object.entries(target)) {
      const keyframes = Array.isArray(raw) ? raw : [raw]
      const mv = this.value(key, DEFAULTS[key] ?? keyframes[0])
      this.running.get(key)?.stop()
      if (reduced && TRANSFORMS.has(key)) {
        mv.jump(keyframes[keyframes.length - 1])
        this.running.delete(key)
        continue
      }
      const options = valueTransition(transition, key, keyframes)
      const controls = animate(
        mv,
        (keyframes.length === 1 ? keyframes[0] : keyframes) as never,
        options as never,
      )
      this.running.set(key, controls)
      done.push(controls.finished)
    }
    this.schedule()
    return Promise.all(done)
  }

  stop() {
    for (const controls of this.running.values()) controls.stop()
    this.running.clear()
  }

  private schedule() {
    if (this.queued) return
    this.queued = true
    frame.render(() => {
      this.queued = false
      this.render()
    })
  }

  private render() {
    const style = this.el.style
    let transform = ''
    for (const key of TRANSFORM_ORDER) {
      const mv = this.values.get(key)
      if (!mv) continue
      const v = mv.get()
      if (v === DEFAULTS[key] || v === `${DEFAULTS[key]}`) continue
      const name = key === 'x' ? 'translateX' : key === 'y' ? 'translateY' : key
      transform += `${name}(${unit(key, v)}) `
    }
    if (TRANSFORM_ORDER.some((key) => this.values.has(key))) style.transform = transform.trim() || 'none'
    for (const [key, mv] of this.values) {
      if (TRANSFORMS.has(key)) continue
      const v = mv.get()
      if (key.startsWith('--')) style.setProperty(key, String(v))
      else
        style.setProperty(
          key.replace(/[A-Z]/g, (c) => `-${c.toLowerCase()}`),
          String(v),
        )
    }
  }
}

const stylers = new WeakMap<Element, Styler>()

export function styler(el: HTMLElement | SVGElement) {
  let s = stylers.get(el)
  if (!s) {
    s = new Styler(el)
    stylers.set(el, s)
  }
  return s
}

// <motion.div initial={…} animate={…} transition={…}> as an attachment. `initial: false` starts at `animate`.
export function enter(initial: Target | false, target: Target, transition?: Transition) {
  return (el: HTMLElement | SVGElement) => {
    const s = styler(el)
    if (initial === false) s.set(target)
    else {
      s.set(initial)
      s.animate(target, transition)
    }
    return () => s.stop()
  }
}

// AnimatePresence's exit as a Svelte `out:` transition: motion runs the animation, Svelte keeps the node around
// for its length. `duration` is the longest delay + duration in the exit, in seconds.
export function exit(el: Element, params: { target: Target; transition?: Transition; duration: number }) {
  styler(el as HTMLElement).animate(params.target, params.transition)
  return { duration: params.duration * 1000 }
}
