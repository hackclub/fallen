<script lang="ts">
  import { MAX_VOLUME } from '@/lib/preferences.svelte'
  import * as sfx from '@/lib/sfx'
  import SolarVolume from '@/components/icons/SolarVolume.svelte'

  // Ten bars that grow left to right, set by clicking or dragging across them or with the arrow keys. Each change
  // plays a blip at the new level, and the bar that changed pops. The speaker mutes and brings the level back.
  let { value, label, onchange }: { value: number; label: string; onchange: (value: number) => void } =
    $props()

  const bars: HTMLElement[] = $state([])
  // svelte-ignore state_referenced_locally
  let unmuted = value || 6
  let dragging = false

  function set(next: number) {
    next = Math.min(MAX_VOLUME, Math.max(0, next))
    if (next === value) return
    const grew = next > value
    onchange(next)
    if (next) unmuted = next
    sfx.step(next)
    const bar = bars[grew ? next - 1 : next]
    if (!bar || matchMedia('(prefers-reduced-motion: reduce)').matches) return
    bar.animate(
      { scale: grew ? ['1 1', '1.25 1.3', '1 1'] : ['1 1', '0.85 0.8', '1 1'] },
      {
        duration: 260,
        easing: 'cubic-bezier(0.34, 1.56, 0.64, 1)',
      },
    )
  }

  function at(event: PointerEvent) {
    const rect = (event.currentTarget as HTMLElement).getBoundingClientRect()
    return Math.ceil(((event.clientX - rect.left) / rect.width) * MAX_VOLUME)
  }

  function onkeydown(event: KeyboardEvent) {
    const moves: Record<string, number> = {
      ArrowRight: value + 1,
      ArrowUp: value + 1,
      ArrowLeft: value - 1,
      ArrowDown: value - 1,
      Home: 0,
      End: MAX_VOLUME,
    }
    if (!(event.key in moves)) return
    event.preventDefault()
    set(moves[event.key])
  }
</script>

<span class="flex items-center gap-3">
  <button
    type="button"
    aria-label={value ? 'Mute' : 'Unmute'}
    onclick={() => set(value ? 0 : unmuted)}
    class="relative grid size-9 cursor-pointer place-items-center rounded-full text-cream outline-offset-2 outline-cream transition hover:bg-white/10 focus-visible:outline-2 active:scale-90"
  >
    <SolarVolume size={22} class={value ? '' : 'opacity-40'} />
    {#if !value}
      <span class="absolute h-0.5 w-6 rotate-45 rounded-full bg-cream" aria-hidden="true"></span>
    {/if}
  </button>
  <span
    role="slider"
    tabindex="0"
    aria-label={label}
    aria-valuemin={0}
    aria-valuemax={MAX_VOLUME}
    aria-valuenow={value}
    aria-valuetext={value ? `${value} of ${MAX_VOLUME}` : 'Off'}
    {onkeydown}
    onpointerdown={(event) => {
      ;(event.currentTarget as HTMLElement).setPointerCapture(event.pointerId)
      dragging = true
      set(at(event))
    }}
    onpointermove={(event) => dragging && set(at(event))}
    onpointerup={() => (dragging = false)}
    onpointercancel={() => (dragging = false)}
    class="flex h-8 cursor-pointer touch-none items-end gap-1 rounded-sm outline-offset-4 outline-cream focus-visible:outline-2"
  >
    {#each { length: MAX_VOLUME }, i (i)}
      <span
        bind:this={bars[i]}
        class={[
          'w-2.5 origin-bottom rounded-[2px] transition-colors duration-100',
          i < value ? 'bg-cream shadow-[0_0_10px_-2px_var(--color-cream)]' : 'bg-white/15',
        ]}
        style:height="{30 + (70 * (i + 1)) / MAX_VOLUME}%"
      ></span>
    {/each}
  </span>
  <span class="w-8 font-montserrat text-sm font-semibold text-cream/80 tabular-nums" aria-hidden="true"
    >{value || 'Off'}</span
  >
</span>
