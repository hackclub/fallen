<script lang="ts">
  import { Spring, prefersReducedMotion } from 'svelte/motion'
  import * as sfx from '@/lib/sfx'

  // A switch whose knob springs across, overshooting a little, and stretches while it is pressed.
  let {
    checked,
    label,
    disabled = false,
    onchange,
  }: { checked: boolean; label: string; disabled?: boolean; onchange: (checked: boolean) => void } = $props()

  const TRAVEL = 32 // px from off to on: the track's 64 less its 4px padding each side and the 24px knob
  // svelte-ignore state_referenced_locally
  const x = new Spring(checked ? TRAVEL : 0, { stiffness: 0.2, damping: 0.45 })
  const stretch = new Spring(1, { stiffness: 0.3, damping: 0.6 })

  $effect(() => {
    x.set(checked ? TRAVEL : 0, { instant: prefersReducedMotion.current })
  })

  const press = (on: boolean) => stretch.set(on ? 1.3 : 1, { instant: prefersReducedMotion.current })

  function flip() {
    sfx.toggle(!checked)
    onchange(!checked)
  }
</script>

<span class="flex items-center gap-3">
  <span class="w-8 text-right font-montserrat text-sm font-semibold text-cream/80" aria-hidden="true"
    >{checked ? 'On' : 'Off'}</span
  >
  <button
    type="button"
    role="switch"
    aria-checked={checked}
    aria-label={label}
    {disabled}
    onclick={flip}
    onpointerdown={() => press(true)}
    onpointerup={() => press(false)}
    onpointerleave={() => press(false)}
    onpointercancel={() => press(false)}
    class={[
      'relative inline-flex h-8 w-[64px] shrink-0 cursor-pointer items-center rounded-[6px] p-1 outline-offset-4 outline-cream transition-colors duration-200 focus-visible:outline-2 disabled:cursor-not-allowed disabled:opacity-40',
      checked ? 'bg-white/40' : 'bg-white/15',
    ]}
  >
    <span
      class="block size-6 rounded-[4px] bg-cream shadow-[0_2px_6px_rgba(0,0,0,0.35)]"
      style:transform="translateX({x.current}px) scaleX({stretch.current})"
      style:transform-origin={checked ? 'right' : 'left'}
    ></span>
  </button>
</span>
