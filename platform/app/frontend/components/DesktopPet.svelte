<script module lang="ts">
  import { SCENE } from '@/components/dialog/geometry'
  import { DIALOG_EGG } from '@/lib/pet.svelte'

  // 70% of the onboarding's talking egg. The dialog fills the window and scales its 1185 x 541 scene to fit 94% of
  // its width and half its height (DialogStage's default `fit`), so the same sum gives the egg's size there.
  const SHARE_OF_DIALOG_EGG = 0.7
  const EGG_ASPECT = 550 / 736 // the egg drawings; the hatched forms are measured when they load
  function size(aspect: number) {
    const unit = Math.min((window.innerWidth * 0.94) / SCENE.width, (window.innerHeight * 0.5) / SCENE.height)
    const h = Math.round(DIALOG_EGG.height * unit * SHARE_OF_DIALOG_EGG)
    return { w: Math.round(h * aspect), h }
  }

  const GROUND = 10 // px between the egg and the bottom of the window
  const EDGE = 16 // closest it gets to the window's sides, in px
  const HOP_DURATION = 0.42
  const STORE = 'fallen:pet-x'
  const GOLD = '#F9AF3F'

  // Thrown or dropped, it falls under gravity and bounces, losing speed at each bounce, the walls and along the
  // ground. Speeds in px/s.
  const GRAVITY = 3400
  const RESTITUTION = 0.42 // vertical speed kept per bounce
  const BOUNCE_FRICTION = 0.55 // horizontal speed kept per bounce
  const WALL = 0.5
  const AIR_DRAG = 0.6 // horizontal speed kept per second in the air
  const MIN_BOUNCE = 160 // slower landings just settle, and an egg does not slide
  const THROW = 0.7 // share of the pointer's speed it is thrown with, so it feels heavy
  const MAX_THROW = 1800

  const clamp = (n: number, min: number, max: number) => Math.min(max, Math.max(min, n))
  const between = (min: number, max: number) => min + Math.random() * (max - min)
</script>

<script lang="ts">
  import { untrack } from 'svelte'
  import { starPath } from '@/components/GoldFrame.svelte'
  import { enter, exit, prefersReducedMotion, styler } from '@/components/dialog/motion'
  import { FINAL_FORM, PET_FORMS, PET_NAMES, hatch, petState } from '@/lib/pet.svelte'
  import { shared } from '@/lib/shared.svelte'

  // A desktop pet for the signed-in site: the egg picked in onboarding sits on the bottom of the window, hops about
  // now and then, wobbles, can be picked up and dropped, and jumps when poked. Where it stands is remembered. It
  // shows its current form (User#pet_form) and bursts into the next one when that changes.
  const user = $derived(shared().auth.user)
  const pet = $derived(petState.picked ?? user?.pet ?? null)
  const form = $derived(user?.pet_form ?? 0)
  // svelte-ignore state_referenced_locally
  let shown = $state(form)
  // At least this form, whatever the server says: a hatch previewed in development (Shift+K) leaves the pet hatched.
  let floor = $state(0)
  const src = $derived(pet ? PET_FORMS[pet][Math.max(shown, floor)] : undefined)
  const visible = $derived(!!src && !petState.onboarding)

  let root: HTMLButtonElement
  let flight: HTMLElement
  let body: HTMLElement
  let flying = $state(false)

  // Hovering shows a little status card above the pet, kept inside the window (TIP_WIDTH px wide, its tail still
  // pointing at the pet): its name and stage, how far it is to its next form, and what gets it there. The pet
  // stays put while it shows.
  const stageLabel = $derived(
    shown === 0 ? 'Egg' : shown === FINAL_FORM ? 'Final form' : `Stage ${shown} of ${FINAL_FORM}`,
  )
  // What the bar says: the XP left to the next form (the bar fills across this stage only), or the one thing left to do.
  const barText = $derived.by(() => {
    if (shown === 0) return 'Hatches with your first journal'
    if (user?.next_stage_xp != null) return `${user.next_stage_xp - user.xp} XP to stage ${shown + 1}`
    if (shown < FINAL_FORM) return 'Awaiting project approval'
    return `${user?.xp ?? 0} XP`
  })
  const TIP = $derived(`${pet ? PET_NAMES[pet] : 'Your pet'}, ${stageLabel.toLowerCase()}. ${barText}`)
  const TIP_WIDTH = 250
  let hovered = $state(false)
  let tipShift = $state(0)
  const showTip = $derived(hovered && !flying)

  function onpointerenter(event: PointerEvent) {
    if (event.pointerType === 'touch' || drag?.moved) return
    const centre = x + dims.w / 2
    const left = clamp(centre - TIP_WIDTH / 2, 8, innerWidth - 8 - TIP_WIDTH)
    tipShift = left - (centre - TIP_WIDTH / 2)
    hovered = true
  }
  let aspect = EGG_ASPECT
  let dims = $state(size(aspect))

  function measure(img: HTMLImageElement) {
    if (!img.naturalHeight) return
    aspect = img.naturalWidth / img.naturalHeight
    dims = size(aspect)
    x = clamp(x, EDGE, maxX())
    if (root) styler(root).set({ x })
  }

  // A new form: squeeze down, swap at the smallest, and spring back out in a burst of stars.
  $effect(() => {
    if (form === shown) return
    untrack(() => evolve(form))
  })

  async function evolve(to: number) {
    if (!root) {
      shown = to
      return
    }
    busy = true
    clearTimeout(timer)
    hovered = false
    if (shown === 0 && pet) {
      await hatch(pet)
      shown = to
      if (!flying) {
        busy = false
        schedule()
      }
      return
    }
    sparkle()
    await styler(body).animate(
      { scaleY: [1, 1.15, 0.6], scaleX: [1, 0.9, 1.3] },
      { duration: 0.45, ease: 'easeIn', times: [0, 0.4, 1] },
    )
    shown = to
    sparkle()
    sparkle()
    await styler(body).animate({ scaleY: 1, scaleX: 1 }, { type: 'spring', stiffness: 260, damping: 9 })
    busy = false
    schedule()
  }

  let x = 0
  let busy = false
  let timer: ReturnType<typeof setTimeout> | undefined

  const maxX = () => window.innerWidth - dims.w - EDGE

  function live(el: HTMLButtonElement) {
    return untrack(() => start(el))
  }

  function start(el: HTMLButtonElement) {
    root = el
    // On <body>, out of the layout's stacking contexts, so it can fly above the onboarding overlay.
    document.body.append(el)
    flight = el.firstElementChild as HTMLElement
    body = flight.firstElementChild as HTMLElement
    const stored = Number(localStorage.getItem(STORE))
    x = clamp(Number.isFinite(stored) && stored > 0 ? stored : maxX() - 24, EDGE, maxX())
    styler(root).set({ x, y: 0 })

    const handoff = petState.handoff
    petState.handoff = null
    if (handoff) flyIn(handoff)
    else styler(body).animate({ scale: [0, 1] }, { type: 'spring', stiffness: 420, damping: 16 })

    schedule()
    const onResize = () => {
      dims = size(aspect)
      x = clamp(x, EDGE, maxX())
      styler(root).set({ x })
    }
    window.addEventListener('resize', onResize)
    return () => {
      clearTimeout(timer)
      window.removeEventListener('resize', onResize)
      el.remove()
    }
  }

  // Out of the hatch: the hatched pet flies down from where it stood, once its drawing is ready to measure.
  $effect(() => {
    const from = petState.hatched
    if (!from || !root || !pet) return
    untrack(async () => {
      petState.hatched = null
      floor = 1
      busy = true
      clearTimeout(timer)
      hovered = false
      styler(flight).set({ opacity: 0 })
      const img = new Image()
      img.src = PET_FORMS[pet][Math.max(shown, 1)]
      await img.decode().catch(() => {})
      measure(img)
      flyIn(from)
    })
  })

  // Out of the dialog: from where the talking egg stood, arcing down into its spot and shrinking to size.
  async function flyIn(from: DOMRect) {
    busy = true
    flying = true
    const to = root.getBoundingClientRect()
    const dx = from.left + from.width / 2 - (to.left + to.width / 2)
    const dy = from.bottom - to.bottom
    const f = styler(flight)
    f.set({ x: dx, y: dy, scale: from.height / dims.h, opacity: 1 })
    const ease = [0.45, 0, 0.2, 1]
    await f.animate(
      { x: 0, y: [dy, Math.min(dy, 0) - 90, 0], scale: 1 },
      {
        x: { duration: 0.8, ease },
        y: { duration: 0.8, times: [0, 0.4, 1], ease: ['easeOut', 'easeIn'] },
        scale: { duration: 0.8, ease },
      },
    )
    flying = false
    await land()
    busy = false
    schedule()
  }

  function land() {
    return styler(body).animate(
      { scaleY: [0.72, 1.1, 1], scaleX: [1.22, 0.95, 1], rotate: 0 },
      { duration: 0.5, ease: [0.22, 1, 0.36, 1], times: [0, 0.45, 1] },
    )
  }

  // Idle: every few seconds either hop somewhere else along the bottom or have a little wobble.
  function schedule() {
    clearTimeout(timer)
    timer = setTimeout(
      async () => {
        if (!busy && !hovered && !document.hidden && !prefersReducedMotion()) {
          if (Math.random() < 0.6) {
            const distance = between(80, 360) * (Math.random() < 0.5 ? -1 : 1)
            await hopTo(clamp(x + distance, EDGE, maxX()))
          } else await wobble()
        }
        schedule()
      },
      between(4000, 9000),
    )
  }

  async function hopTo(target: number) {
    busy = true
    const r = styler(root)
    const b = styler(body)
    while (Math.abs(target - x) > 1) {
      const stride = dims.w * 1.6
      const step = clamp(target - x, -stride, stride)
      await b.animate({ scaleY: 0.82, scaleX: 1.12 }, { duration: 0.12, ease: 'easeOut' })
      b.animate(
        { scaleY: [0.82, 1.1, 1], scaleX: [1.12, 0.94, 1], rotate: [0, Math.sign(step) * 10, 0] },
        { duration: HOP_DURATION, ease: 'easeOut' },
      )
      x += step
      await r.animate(
        { x, y: [0, -dims.h * 0.3, 0] },
        {
          x: { duration: HOP_DURATION, ease: 'easeInOut' },
          y: { duration: HOP_DURATION, times: [0, 0.45, 1], ease: ['easeOut', 'easeIn'] },
        },
      )
      await b.animate(
        { scaleY: [0.86, 1], scaleX: [1.08, 1] },
        { type: 'spring', stiffness: 600, damping: 14 },
      )
    }
    localStorage.setItem(STORE, String(Math.round(x)))
    busy = false
  }

  async function wobble() {
    busy = true
    await styler(body).animate({ rotate: [0, -10, 8, -5, 3, 0] }, { duration: 0.9, ease: 'easeInOut' })
    busy = false
  }

  async function poke() {
    if (busy) return
    busy = true
    sparkle()
    await styler(body).animate({ scaleY: 0.8, scaleX: 1.14 }, { duration: 0.09, ease: 'easeOut' })
    styler(body).animate({ scaleY: 1, scaleX: 1 }, { type: 'spring', stiffness: 500, damping: 15 })
    await fall(between(-120, 120), -Math.sqrt(2 * GRAVITY * dims.h * 0.45))
    busy = false
    schedule()
  }

  // Picking up: follows the pointer (never below the ground) and leans with the motion; let go and it falls back
  // down and bounces. A press that never moves is a poke.
  let drag: {
    id: number
    px: number
    py: number
    x: number
    y: number
    moved: boolean
    lastX: number
    // recent pointer positions, for the speed it is let go at
    trail: { t: number; x: number; y: number }[]
  } | null = null
  let y = 0

  function onpointerdown(event: PointerEvent) {
    if (event.button !== 0 || flying) return
    root.setPointerCapture(event.pointerId)
    drag = {
      id: event.pointerId,
      px: event.clientX,
      py: event.clientY,
      x,
      y: 0,
      moved: false,
      lastX: event.clientX,
      trail: [],
    }
  }

  function onpointermove(event: PointerEvent) {
    if (!drag || event.pointerId !== drag.id) return
    const dx = event.clientX - drag.px
    const dy = event.clientY - drag.py
    if (!drag.moved && Math.hypot(dx, dy) < 5) return
    if (!drag.moved) {
      drag.moved = true
      hovered = false
      busy = true
      clearTimeout(timer)
      styler(body).animate({ scaleY: 1.08, scaleX: 0.94 }, { type: 'spring', stiffness: 500, damping: 18 })
    }
    x = clamp(drag.x + dx, EDGE, maxX())
    y = Math.min(0, drag.y + dy)
    styler(root).set({ x, y })
    const now = performance.now()
    drag.trail.push({ t: now, x: event.clientX, y: event.clientY })
    while (drag.trail.length > 2 && now - drag.trail[0].t > 80) drag.trail.shift()
    const lean = clamp((event.clientX - drag.lastX) * 1.5, -25, 25)
    drag.lastX = event.clientX
    styler(body).animate({ rotate: lean }, { type: 'spring', stiffness: 300, damping: 20 })
  }

  async function onpointerup(event: PointerEvent) {
    if (!drag || event.pointerId !== drag.id) return
    const { moved, trail } = drag
    drag = null
    if (!moved) return poke()
    let vx = 0
    let vy = 0
    const last = trail[trail.length - 1]
    // A pointer held still before letting go drops the egg rather than throwing it with old movement.
    if (trail.length > 1 && performance.now() - last.t < 60) {
      const first = trail[0]
      const dt = Math.max((last.t - first.t) / 1000, 0.016)
      vx = clamp(((last.x - first.x) / dt) * THROW, -MAX_THROW, MAX_THROW)
      vy = clamp(((last.y - first.y) / dt) * THROW, -MAX_THROW, MAX_THROW)
    }
    styler(body).animate({ rotate: 0, scaleY: 1, scaleX: 1 }, { type: 'spring', stiffness: 400, damping: 20 })
    await fall(vx, vy)
    localStorage.setItem(STORE, String(Math.round(x)))
    busy = false
    schedule()
  }

  // Steps the throw until it comes to rest on the ground: stretched along its speed in the air, tilted the way it
  // is travelling, squashed at every landing by how hard it hit.
  function fall(vx: number, vy: number) {
    const f = styler(flight)
    let tilt = 0
    let last = performance.now()
    return new Promise<void>((resolve) => {
      const tick = (now: number) => {
        const dt = Math.min((now - last) / 1000, 1 / 30)
        last = now
        vy += GRAVITY * dt
        x += vx * dt
        y += vy * dt
        if (x < EDGE || x > maxX()) {
          x = clamp(x, EDGE, maxX())
          vx = -vx * WALL
        }
        const ceiling = -(window.innerHeight - dims.h - GROUND - EDGE)
        if (y < ceiling) {
          y = ceiling
          vy = -vy * WALL
        }
        if (y >= 0) {
          y = 0
          if (vy > MIN_BOUNCE) {
            impact(vy)
            vy = -vy * RESTITUTION
            vx *= BOUNCE_FRICTION
          } else vy = 0
        }
        const grounded = y === 0 && vy === 0
        vx = grounded ? 0 : vx * Math.pow(AIR_DRAG, dt)
        const stretch = grounded ? 0 : Math.min(Math.abs(vy) / 9000, 0.16)
        tilt = grounded ? tilt * 0.8 : clamp(vx * 0.012, -22, 22)
        styler(root).set({ x, y })
        f.set({ scaleY: 1 + stretch, scaleX: 1 - stretch * 0.5, rotate: tilt })
        if (grounded && Math.abs(vx) < 6 && Math.abs(tilt) < 0.5) {
          f.set({ rotate: 0 })
          resolve()
        } else requestAnimationFrame(tick)
      }
      requestAnimationFrame(tick)
    })
  }

  function impact(speed: number) {
    const amount = clamp(speed / 3200, 0.08, 0.36)
    styler(body).animate(
      { scaleY: [1 - amount, 1 + amount * 0.35, 1], scaleX: [1 + amount * 0.9, 1 - amount * 0.25, 1] },
      { duration: 0.3 + amount * 0.6, ease: [0.22, 1, 0.36, 1], times: [0, 0.4, 1] },
    )
  }

  function sparkle() {
    for (let i = 0; i < 5; i++) {
      const star = document.createElement('span')
      const size = between(12, 20)
      star.style.cssText = `position:absolute;left:50%;top:20%;width:${size}px;height:${size}px;margin:-${size / 2}px;pointer-events:none`
      star.innerHTML = `<svg viewBox="0 0 29.1 29.1" style="width:100%;height:100%;transform:rotate(45deg)"><path d="${starPath}" fill="${GOLD}"/></svg>`
      flight.append(star)
      const angle = -Math.PI / 2 + between(-1.1, 1.1)
      styler(star)
        .animate(
          {
            x: Math.cos(angle) * between(30, 55),
            y: Math.sin(angle) * between(30, 55),
            scale: [0, 1.2, 0],
            rotate: 120,
          },
          { duration: 0.7, ease: [0.16, 1, 0.3, 1] },
        )
        .then(() => star.remove())
    }
  }
</script>

{#if visible}
  <button
    type="button"
    aria-label="Your pet. {TIP}"
    data-desktop-pet
    class={[
      'fixed bottom-0 left-0 cursor-grab touch-none select-none outline-none active:cursor-grabbing',
      flying ? 'z-[80]' : 'z-40',
    ]}
    style:width="{dims.w}px"
    style:height="{dims.h}px"
    style:margin-bottom="{GROUND}px"
    {@attach live}
    {onpointerdown}
    {onpointermove}
    {onpointerup}
    onpointercancel={onpointerup}
    {onpointerenter}
    onpointerleave={() => (hovered = false)}
    onclick={(event) => event.detail === 0 && poke()}
  >
    <span class="absolute inset-0" style:transform-origin="50% 100%">
      <span class="absolute inset-0" style:transform-origin="50% 100%">
        <!-- a slow breath, on its own element so it never fights the squashes above -->
        <span
          class="absolute inset-0"
          style:transform-origin="50% 100%"
          {@attach (el) => {
            const s = styler(el)
            if (!prefersReducedMotion())
              s.animate(
                { scaleY: [1, 1.035, 1], scaleX: [1, 0.985, 1] },
                { duration: 2.6, ease: 'easeInOut', repeat: Infinity },
              )
            return () => s.stop()
          }}
        >
          <img
            {src}
            alt=""
            draggable="false"
            onload={(event) => measure(event.currentTarget as HTMLImageElement)}
            class="pointer-events-none size-full object-contain object-bottom drop-shadow-[0_4px_6px_rgba(0,0,0,0.35)]"
          />
        </span>
      </span>
    </span>
    {#if showTip}
      <span
        role="tooltip"
        class="pointer-events-none absolute bottom-full left-1/2 mb-3 cursor-default"
        style:width="{TIP_WIDTH}px"
        style:margin-left="{-TIP_WIDTH / 2 + tipShift}px"
        style:transform-origin="{TIP_WIDTH / 2 - tipShift}px 100%"
        {@attach enter(
          { opacity: 0, scale: 0.6, y: 10 },
          { opacity: 1, scale: 1, y: 0 },
          { type: 'spring', stiffness: 500, damping: 22 },
        )}
        out:exit={{
          target: { opacity: 0, scale: 0.85, y: 6 },
          transition: { duration: 0.12 },
          duration: 0.12,
        }}
      >
        <span
          class="block rounded-2xl border-2 border-gold bg-dark-blue px-4 py-3 text-left font-outfit text-sm leading-snug text-cream shadow-[0_10px_30px_-8px_rgba(0,0,0,0.7)]"
        >
          <span class="flex items-baseline justify-between gap-3">
            <span class="font-lora text-base font-bold">{pet ? PET_NAMES[pet] : 'Your pet'}</span>
            <span class="text-xs text-pale-blue/80">{stageLabel}</span>
          </span>
          <span class="relative mt-2 block h-6 overflow-hidden rounded-[5px] bg-white/10">
            <span
              class="absolute inset-y-0 left-0 bg-gold transition-[width] duration-700"
              style:width="{(user?.stage_progress ?? 0) * 100}%"
            ></span>
            <span
              class="relative flex h-full items-center justify-center text-xs font-semibold text-cream [text-shadow:0_1px_2px_rgba(0,0,0,0.6)]"
            >
              {barText}
            </span>
          </span>
        </span>
        <!-- the tail, pointing down at the egg -->
        <span
          class="absolute -bottom-[7px] size-3.5 rotate-45 border-r-2 border-b-2 border-gold bg-dark-blue"
          style:left="{TIP_WIDTH / 2 - tipShift - 7}px"
        ></span>
      </span>
    {/if}
  </button>
{/if}
