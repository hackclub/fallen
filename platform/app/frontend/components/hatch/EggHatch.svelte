<script module lang="ts">
  import { starPath } from '@/components/GoldFrame.svelte'

  const TAPS = 3
  const REACH = [0.38, 0.72, 1] // how much of the crack shows after each tap
  const AUTO_FIRST = 2400 // ms before it cracks by itself, so it never waits forever
  const AUTO_NEXT = 1300
  const TEASE_WAIT = 3500 // ms the teaser sits before its one crack
  const TEASE_PACE = 1.3 // how much slower the teaser's motion is
  const HIT_STOP = 70 // ms the egg holds still on each hit before it reacts, so the hit lands
  const CHARGE = 0.9 // s of shaking before it opens

  // The drawings' own colours: flat fills with the brown outline, no glows.
  const SHELL = '#fff8ee'
  const OUTLINE = '#5b3512'
  // Each egg's own shell and outline, sampled from its drawing, for the crack and the bits flung off it.
  const EGG_COLOURS: Record<string, { shell: string; outline: string }> = {
    lulu: { shell: SHELL, outline: OUTLINE },
    sami: { shell: '#353b7d', outline: '#04052c' },
    egg: { shell: '#fbfaf6', outline: '#031235' },
  }
  const GOLD = '#F9AF3F'
  const CONFETTI = ['#F9AF3F', '#fcf9ef', '#90a8f6', '#cbe1b8', '#f7dda6']

  // The flying shell pieces: top, bottom left, bottom right. Distances are in egg heights; they fall off the
  // bottom of the window.
  const FLIGHTS = [
    { x: -0.9, up: -1.1, rotate: -260 },
    { x: -1.3, up: -0.45, rotate: -140 },
    { x: 1.3, up: -0.5, rotate: 160 },
  ]

  const between = (min: number, max: number) => min + Math.random() * (max - min)
  const wait = (ms: number) => new Promise((resolve) => setTimeout(resolve, ms))
  // Back and forth, growing to `max` and back to rest.
  const jitter = (n: number, max: number) =>
    Array.from({ length: n + 2 }, (_, i) =>
      i === 0 || i === n + 1 ? 0 : (i % 2 ? -1 : 1) * max * (0.25 + (0.75 * i) / n),
    )
</script>

<script lang="ts">
  import { onMount, tick } from 'svelte'
  import { fade, fly } from 'svelte/transition'
  import { styler } from '@/components/dialog/motion'
  import plainEgg from '@/assets/onboarding/egg.png'
  import { PET_FORMS, PET_NAMES } from '@/lib/pet.svelte'
  import { H, W, breakShell } from './shell'
  import * as sounds from './sounds'

  // The egg hatching, over the whole window: it drops in, cracks a little more with every click (or by itself if
  // left alone), shakes harder and harder, then bursts open and the pet's first form jumps out. Click to carry on.
  // `handoff` is given where the hatched pet stood as the scene closes, and says whether something took it from there
  // (so it is hidden here rather than fading out).
  let {
    pet,
    teaser = false,
    handoff,
    onclose,
  }: { pet: string; teaser?: boolean; handoff: (from: DOMRect) => boolean; onclose: () => void } = $props()

  // svelte-ignore state_referenced_locally
  // `egg` is the onboarding's egg before a pet is picked; it has no pet inside, so only the teaser plays it.
  const [eggSrc, petSrc] = PET_FORMS[pet] ?? [plainEgg]
  // svelte-ignore state_referenced_locally
  const name = PET_NAMES[pet] ?? 'Your pet'
  // svelte-ignore state_referenced_locally
  const egg = EGG_COLOURS[pet] ?? EGG_COLOURS.lulu
  // svelte-ignore state_referenced_locally
  const pace = teaser ? TEASE_PACE : 1
  // svelte-ignore state_referenced_locally
  const size = Math.round(
    teaser ? Math.min(window.innerHeight * 0.6, 560) : Math.min(window.innerHeight * 0.42, 380),
  )
  const width = Math.round((size * W) / H)
  const shell = breakShell()

  let phase = $state<'cracking' | 'charging' | 'open' | 'leaving'>('cracking')
  let hint = $state(false)
  let broken = $state(false)
  let done = $state(false)
  let taps = 0
  let lastTap = 0
  let auto: ReturnType<typeof setTimeout> | undefined
  let idle: ReturnType<typeof setTimeout> | undefined

  let root: HTMLElement
  let scene: HTMLElement
  let drop: HTMLElement
  let shake: HTMLElement
  let squash: HTMLElement
  let white = $state() as HTMLElement
  let flash: HTMLElement
  let shadow: HTMLElement
  let petEl: HTMLElement
  let petSquash: HTMLElement
  let particles: HTMLElement
  let canvas: HTMLCanvasElement
  let fire: import('canvas-confetti').CreateTypes | undefined
  let petImg: HTMLImageElement
  let cracks: SVGPathElement[] = []
  let branches: SVGPathElement[] = []
  let pieces: HTMLElement[] = []

  onMount(() => {
    document.body.append(root)
    for (const el of [...cracks, ...branches]) styler(el).set({ strokeDashoffset: 1 })
    styler(petEl).set({ scale: 0 })
    styler(root).animate({ opacity: [0, 1] }, { duration: 0.25 })
    enter()
    return () => {
      clearTimeout(auto)
      clearTimeout(idle)
      fire?.reset()
      root.remove()
    }
  })

  async function enter() {
    styler(shadow).animate({ scale: [0.3, 1], opacity: [0, 1] }, { duration: 0.45 * pace, ease: 'easeIn' })
    await styler(drop).animate(
      { y: [-window.innerHeight * 0.75, 0], rotate: [-18, 0] },
      { duration: 0.45 * pace, ease: 'easeIn' },
    )
    sounds.land()
    shakeScreen(8)
    puffs(4)
    await styler(squash).animate(
      { scaleY: [0.66, 1.14, 1], scaleX: [1.32, 0.9, 1] },
      { duration: 0.5 * pace, ease: [0.22, 1, 0.36, 1], times: [0, 0.4, 1] },
    )
    wobbleLater()
    if (teaser) {
      auto = setTimeout(crack, TEASE_WAIT)
      return
    }
    autoLater(AUTO_FIRST)
    setTimeout(() => (hint = phase === 'cracking' && taps === 0), 400)
  }

  // Waiting: a nervous little rock now and then, more so the more cracked it is. The teaser rocks slower and
  // smoother, and once cracked keeps on rocking with the odd hop.
  function wobbleLater() {
    clearTimeout(idle)
    idle = setTimeout(
      () => {
        if (phase !== 'cracking') return
        const a = 4 + taps * 4
        if (!teaser)
          styler(shake).animate({ rotate: [0, -a, a, -a / 2, 0] }, { duration: 0.5, ease: 'easeInOut' })
        else if (!taps)
          styler(shake).animate({ rotate: [0, -6, 6, -3, 0] }, { duration: 1.3, ease: 'easeInOut' })
        else {
          styler(shake).animate(
            { rotate: [0, -9, 8, -6, 4, 0], x: [0, -4, 4, -3, 2, 0] },
            { duration: 1.2, ease: 'easeInOut' },
          )
          if (Math.random() < 0.35)
            styler(drop).animate(
              { y: [0, -size * 0.05, 0] },
              { duration: 0.55, times: [0, 0.45, 1], ease: ['easeOut', 'easeIn'] },
            )
        }
        wobbleLater()
      },
      !teaser ? between(600, 1000) : taps ? between(1300, 1700) : between(1450, 1750),
    )
  }

  function autoLater(ms: number) {
    clearTimeout(auto)
    auto = setTimeout(crack, ms)
  }

  async function crack() {
    const now = performance.now()
    // taps can reach TAPS before charge() flips the phase: on a slow phone the hit stop outlasts the debounce.
    if (phase !== 'cracking' || taps >= TAPS || now - lastTap < 130) return
    lastTap = now
    taps++
    hint = false
    clearTimeout(auto)
    wobbleLater()
    sounds.crack(taps)
    navigator.vibrate?.(20 + taps * 12)

    // The hit: squashed flat and white for a moment, the crack already there, then everything reacts.
    const reach = REACH[taps - 1]
    styler(squash).set({ scaleY: 0.82, scaleX: 1.16 })
    styler(white).set({ opacity: 1 })
    for (const el of cracks) styler(el).set({ strokeDashoffset: 1 - reach })
    shell.branches.forEach((b, i) => b.at === taps && styler(branches[i]).set({ strokeDashoffset: 0 }))
    await wait(HIT_STOP)

    styler(white).animate({ opacity: 0 }, { duration: 0.08 })
    const a = 6 + taps * 5
    styler(squash).animate(
      { scaleY: [0.82, 1.12, 0.97, 1], scaleX: [1.16, 0.92, 1.02, 1] },
      { duration: 0.45 * pace, times: [0, 0.35, 0.7, 1], ease: 'easeOut' },
    )
    styler(shake).animate(
      { rotate: [0, -a, a * 0.8, -a * 0.5, a * 0.2, 0], x: [0, -a, a * 0.7, -a * 0.3, 0] },
      { duration: 0.45 * pace, ease: teaser ? 'easeInOut' : 'easeOut' },
    )
    styler(drop).animate(
      { y: [0, -size * 0.06 * taps, 0] },
      { duration: 0.32 * pace, times: [0, 0.4, 1], ease: ['easeOut', 'easeIn'] },
    )
    shakeScreen(5 * taps)
    chips(4 + taps * 3, reach)

    if (teaser) return
    if (taps >= TAPS) charge()
    else autoLater(AUTO_NEXT)
  }

  // About to go: it shakes harder and harder, hopping, with white flickers as bits fly off it.
  async function charge() {
    phase = 'charging'
    clearTimeout(idle)
    await wait(250)
    sounds.charge(CHARGE)
    styler(white).animate(
      { opacity: [0, 0, 0.9, 0, 0, 0.9, 0, 0.9, 0, 1] },
      { duration: CHARGE, ease: 'linear' },
    )
    styler(drop).animate(
      { y: [0, -14, 0, -18, 0, -24, 0, -30, 0, -size * 0.1] },
      { duration: CHARGE, ease: 'easeOut' },
    )
    styler(squash).animate(
      { scaleY: [1, 0.86, 1.12], scaleX: [1, 1.14, 0.92] },
      { duration: CHARGE, times: [0, 0.7, 1], ease: 'easeInOut' },
    )
    const chipping = setInterval(() => chips(2, 1), 140)
    await styler(shake).animate(
      { x: jitter(22, 14), rotate: jitter(22, 11) },
      { duration: CHARGE, ease: 'linear' },
    )
    clearInterval(chipping)
    open()
  }

  async function open() {
    phase = 'open'
    sounds.hatch()
    navigator.vibrate?.([40, 30, 80])
    styler(flash).animate({ opacity: [1, 0, 0.7, 0] }, { duration: 0.28, ease: 'linear' })
    styler(scene).animate(
      { x: [0, -26, 22, -16, 12, -6, 0], y: [0, 18, -14, 10, -6, 3, 0] },
      { duration: 0.45, ease: 'linear' },
    )
    styler(shake).set({ x: 0, rotate: 0 })
    styler(squash).set({ scaleX: 1, scaleY: 1 })
    styler(drop).set({ y: 0 })
    broken = true
    await tick()

    FLIGHTS.forEach((flight, i) => {
      const time = between(1, 1.25)
      styler(pieces[i]).animate(
        { x: flight.x * size, y: [0, flight.up * size, window.innerHeight], rotate: flight.rotate },
        {
          x: { duration: time, ease: 'easeOut' },
          y: { duration: time, times: [0, 0.3, 1], ease: ['easeOut', 'easeIn'] },
          rotate: { duration: time, ease: 'easeOut' },
        },
      )
    })
    styler(shadow).animate({ scale: 0.8 }, { duration: 0.3 })
    chips(26, 1)
    stars(10)
    celebrate()

    // Out it jumps, lands with a squash, and settles into a breath.
    const time = 0.7
    await styler(petEl).animate(
      { scale: [0.3, 1.1, 1], y: [size * 0.1, -size * 0.45, 0], rotate: [-20, 10, 0] },
      {
        scale: { duration: time * 0.5, ease: 'easeOut' },
        y: { duration: time, times: [0, 0.45, 1], ease: ['easeOut', 'easeIn'] },
        rotate: { duration: time, ease: 'easeOut' },
      },
    )
    sounds.land()
    shakeScreen(7)
    puffs(5)
    await styler(petSquash).animate(
      { scaleY: [0.7, 1.12, 0.96, 1], scaleX: [1.3, 0.9, 1.03, 1] },
      { duration: 0.55, times: [0, 0.35, 0.7, 1], ease: 'easeOut' },
    )
    styler(petSquash).animate(
      { scaleY: [1, 1.035, 1], scaleX: [1, 0.985, 1] },
      { duration: 2.2, ease: 'easeInOut', repeat: Infinity },
    )
    setTimeout(() => (done = true), 300)
  }

  function onclick() {
    if (phase === 'cracking' && !teaser) crack()
    else if (phase === 'open' && done) close()
  }

  function onkeydown(event: KeyboardEvent) {
    if (event.key === 'Escape') {
      event.preventDefault()
      close()
    } else if (event.key === ' ' || event.key === 'Enter') {
      event.preventDefault()
      onclick()
    }
  }

  async function close() {
    if (phase === 'leaving') return
    phase = 'leaving'
    clearTimeout(auto)
    clearTimeout(idle)
    if (broken && handoff(petImg.getBoundingClientRect())) petEl.style.visibility = 'hidden'
    await styler(root).animate({ opacity: 0 }, { duration: 0.25 })
    onclose()
  }

  function shakeScreen(amount: number) {
    styler(scene).animate(
      {
        x: [0, -amount, amount * 0.8, -amount * 0.4, 0],
        y: [0, amount * 0.6, -amount * 0.5, amount * 0.2, 0],
      },
      { duration: 0.25, ease: 'linear' },
    )
  }

  // Bits flung off the shell where the crack is.
  function chips(count: number, reach: number) {
    for (let i = 0; i < count; i++) {
      const along = 0.5 + between(-reach, reach) / 2
      const [px, py] = shell.crack[Math.round(along * (shell.crack.length - 1))]
      const s = between(9, 22)
      const el = particle(
        (px / W) * width,
        (py / H) * size,
        s,
        `<svg viewBox="0 0 10 10" style="width:100%;height:100%;overflow:visible"><path d="M${between(0, 3)} ${between(0, 4)} L${between(6, 10)} ${between(0, 3)} L${between(5, 9)} ${between(6, 10)} L${between(0, 3)} ${between(5, 9)}Z" fill="${egg.shell}" stroke="${egg.outline}" stroke-width="1.4" stroke-linejoin="round"/></svg>`,
      )
      const dx = (along - 0.5) * between(160, 360) + between(-60, 60)
      const up = between(50, 160)
      const time = between(0.8, 1.1)
      styler(el)
        .animate(
          { x: dx, y: [0, -up, size * 0.9], rotate: between(-540, 540) },
          {
            x: { duration: time, ease: 'easeOut' },
            y: { duration: time, times: [0, 0.3, 1], ease: ['easeOut', 'easeIn'] },
            rotate: { duration: time },
          },
        )
        .then(() => el.remove())
    }
  }

  // Little dust clouds either side of whatever just landed.
  function puffs(count: number) {
    for (let i = 0; i < count; i++) {
      const side = i % 2 ? 1 : -1
      const s = between(18, 34)
      const el = particle(width / 2 + side * width * between(0.25, 0.45), size - 4, s, '')
      el.style.borderRadius = '9999px'
      el.style.background = SHELL
      el.style.border = `2px solid ${OUTLINE}`
      styler(el)
        .animate(
          { x: side * between(30, 80), y: -between(4, 24), scale: [0.4, 1, 0] },
          { duration: between(0.4, 0.6), ease: 'easeOut' },
        )
        .then(() => el.remove())
    }
  }

  function stars(count: number) {
    for (let i = 0; i < count; i++) {
      const s = between(16, 30)
      const el = particle(
        width / 2,
        size * 0.5,
        s,
        `<svg viewBox="-2 -2 33.1 33.1" style="width:100%;height:100%;transform:rotate(45deg)"><path d="${starPath}" fill="${GOLD}" stroke="${OUTLINE}" stroke-width="2"/></svg>`,
      )
      const angle = (i / count) * Math.PI * 2 + between(-0.3, 0.3)
      const distance = between(size * 0.6, size * 1)
      styler(el)
        .animate(
          { x: Math.cos(angle) * distance, y: Math.sin(angle) * distance, scale: [0, 1.3, 0], rotate: 180 },
          { duration: between(0.8, 1.1), ease: [0.16, 1, 0.3, 1] },
        )
        .then(() => el.remove())
    }
  }

  // A burst of paper confetti out of the egg in every direction, flipping as it falls, on a canvas of its own inside the
  // overlay so it fades with it.
  async function celebrate() {
    const { default: confetti } = await import('canvas-confetti')
    if (phase === 'leaving') return
    fire = confetti.create(canvas, { resize: true })
    const box = scene.querySelector('[data-egg]')!.getBoundingClientRect()
    fire({
      particleCount: 90,
      spread: 360,
      startVelocity: 42,
      decay: 0.91,
      gravity: 0.9,
      ticks: 200,
      shapes: ['square'],
      scalar: 1.3,
      colors: CONFETTI,
      disableForReducedMotion: true,
      origin: { x: (box.left + box.width / 2) / innerWidth, y: (box.top + box.height * 0.5) / innerHeight },
    })
  }

  function particle(x: number, y: number, s: number, html: string) {
    const el = document.createElement('span')
    el.style.cssText = `position:absolute;left:${x}px;top:${y}px;width:${s}px;height:${s}px;margin:-${s / 2}px;pointer-events:none`
    el.innerHTML = html
    particles.append(el)
    return el
  }
</script>

<svelte:window {onkeydown} />

<!-- svelte-ignore a11y_click_events_have_key_events (keys are on the window) -->
<div
  bind:this={root}
  role="dialog"
  aria-modal="true"
  aria-label="{name} is hatching"
  tabindex="-1"
  class={[
    'fixed inset-0 z-[70] cursor-pointer touch-none select-none overflow-hidden',
    teaser
      ? 'bg-[radial-gradient(ellipse_at_center,transparent_35%,rgba(0,1,5,0.55)_75%,rgba(0,1,5,0.9)_100%)]'
      : 'bg-[radial-gradient(circle_at_50%_45%,rgba(22,32,100,0.94),rgba(0,1,5,0.97)_70%)]',
  ]}
  style:opacity="0"
  {onclick}
>
  <div bind:this={scene} class="absolute inset-0 flex flex-col items-center justify-center">
    <div class="relative" style:width="{width}px" style:height="{size}px" data-egg>
      <div
        bind:this={shadow}
        class="absolute -bottom-3 left-1/2 h-6 w-[90%] -translate-x-1/2 rounded-[50%] bg-black/35"
      ></div>

      <div
        bind:this={petEl}
        class="absolute inset-x-[-20%] bottom-0 h-[85%]"
        style:transform-origin="50% 100%"
      >
        <div bind:this={petSquash} class="size-full" style:transform-origin="50% 100%">
          <img
            bind:this={petImg}
            src={petSrc}
            alt=""
            draggable="false"
            class="size-full object-contain object-bottom"
          />
        </div>
      </div>

      <div bind:this={drop} class="absolute inset-0">
        <div bind:this={shake} class="absolute inset-0" style:transform-origin="50% 90%">
          <div bind:this={squash} class="absolute inset-0" style:transform-origin="50% 100%">
            {#if broken}
              {#each shell.pieces as clip, i (i)}
                <div bind:this={pieces[i]} class="absolute inset-0" style:clip-path={clip}>
                  <img src={eggSrc} alt="" draggable="false" class="size-full" />
                </div>
              {/each}
            {:else}
              <img src={eggSrc} alt="" draggable="false" class="absolute inset-0 size-full" />
              <svg
                viewBox="0 0 {W} {H}"
                class="absolute inset-0 size-full"
                style:mask-image="url({eggSrc})"
                style:mask-size="100% 100%"
              >
                {#each shell.paths as d, i (i)}
                  <path
                    bind:this={cracks[i]}
                    {d}
                    pathLength="1"
                    stroke-dasharray="1 1"
                    fill="none"
                    stroke={egg.outline}
                    stroke-width="9"
                    stroke-linecap="round"
                    stroke-linejoin="round"
                  />
                {/each}
                {#each shell.branches as b, i (i)}
                  <path
                    bind:this={branches[i]}
                    d={b.d}
                    pathLength="1"
                    stroke-dasharray="1 1"
                    fill="none"
                    stroke={egg.outline}
                    stroke-width="7"
                    stroke-linecap="round"
                    stroke-linejoin="round"
                  />
                {/each}
              </svg>
              <div
                bind:this={white}
                class="absolute inset-0 bg-white"
                style:mask-image="url({eggSrc})"
                style:mask-size="100% 100%"
                style:opacity="0"
              ></div>
            {/if}
          </div>
        </div>
      </div>

      <div bind:this={particles} class="pointer-events-none absolute inset-0"></div>
    </div>

    <div class={['flex flex-col items-center text-center', teaser ? 'hidden' : 'mt-12 h-20']}>
      {#if hint}
        <p class="font-outfit text-lg text-pale-blue" transition:fade={{ duration: 200 }}>
          Click to crack it open
        </p>
      {/if}
      {#if phase === 'open' || phase === 'leaving'}
        <p
          class="font-lora text-4xl font-bold text-cream [text-shadow:0_3px_0_#5b3512]"
          in:fly={{ y: 24, duration: 450, delay: 450 }}
        >
          {name.toUpperCase()}!!!
        </p>
        {#if done}
          <p class="mt-3 font-outfit text-sm text-pale-blue/80" in:fade={{ duration: 300 }}>
            Click to continue
          </p>
        {/if}
      {/if}
    </div>
  </div>

  <canvas bind:this={canvas} class="pointer-events-none absolute inset-0 size-full"></canvas>
  <div bind:this={flash} class="pointer-events-none absolute inset-0 bg-white" style:opacity="0"></div>
</div>
