<script lang="ts">
  import { prefersReducedMotion } from 'svelte/motion'
  import * as sfx from '@/lib/sfx'

  // For things that are a pain to undo: it only goes through once held for `seconds`. Holding fills it with a
  // rising hum and a growing shiver; letting go early drains it back.
  let {
    label,
    holding: holdingLabel = 'Keep holding',
    done: doneLabel,
    seconds = 1,
    onconfirm,
  }: { label: string; holding?: string; done: string; seconds?: number; onconfirm: () => void } = $props()

  let progress = $state(0)
  let shake = $state(0)
  let held = $state(false)
  let finished = $state(false)
  let frame = 0
  let hum: { stop(): void } | null = null

  function animate(from: number, to: number, ms: number, onend?: () => void) {
    cancelAnimationFrame(frame)
    const start = performance.now()
    const tick = (now: number) => {
      const t = Math.min(1, (now - start) / ms)
      progress = from + (to - from) * t
      shake = held && !prefersReducedMotion.current ? (Math.random() - 0.5) * progress * 3 : 0
      if (t < 1) frame = requestAnimationFrame(tick)
      else onend?.()
    }
    frame = requestAnimationFrame(tick)
  }

  function start() {
    if (held || finished) return
    held = true
    const left = (1 - progress) * seconds
    hum = sfx.charge(left)
    animate(progress, 1, left * 1000, () => {
      held = false
      finished = true
      shake = 0
      hum?.stop()
      sfx.confirm()
      onconfirm()
    })
  }

  function release() {
    if (!held) return
    held = false
    hum?.stop()
    sfx.cancel()
    animate(progress, 0, progress * 300)
  }

  const shown = $derived(finished ? 2 : held && progress > 0 ? 1 : 0)
  const isKey = (event: KeyboardEvent) => event.key === ' ' || event.key === 'Enter'
</script>

<button
  type="button"
  disabled={finished}
  aria-label="{label} (press and hold)"
  onpointerdown={(event) => {
    if (event.button !== 0) return
    ;(event.currentTarget as HTMLElement).setPointerCapture(event.pointerId)
    start()
  }}
  onpointerup={release}
  onpointercancel={release}
  onkeydown={(event) => {
    if (!isKey(event)) return
    event.preventDefault()
    if (!event.repeat) start()
  }}
  onkeyup={(event) => isKey(event) && release()}
  onblur={release}
  class="relative h-11 cursor-pointer touch-none overflow-hidden rounded-full border border-white/25 bg-white/10 px-5 font-montserrat font-semibold text-cream outline-offset-4 outline-cream select-none focus-visible:outline-2 disabled:cursor-default"
  style:transform="translateX({shake}px) scale({1 + progress * 0.05})"
>
  <span class="absolute inset-y-0 left-0 bg-hc-red" style:width="{progress * 100}%" aria-hidden="true"></span>
  <!-- all three stacked, so the button keeps the width of the longest as the words change -->
  <span class="relative grid">
    {#each [label, holdingLabel, doneLabel] as text, i (i)}
      <span class={['col-start-1 row-start-1', i !== shown && 'invisible']}>{text}</span>
    {/each}
  </span>
</button>
