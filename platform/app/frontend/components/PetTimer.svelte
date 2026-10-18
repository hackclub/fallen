<script lang="ts">
  import SolarPause from '@/components/icons/SolarPause.svelte'
  import SolarPlay from '@/components/icons/SolarPlay.svelte'
  import { askGoal, formatTracked, resumeHuddle, shownSeconds, stopTimer, timer } from '@/lib/timer.svelte'

  // The pill above the desktop pet: the button for what can be done now, and the time put in since the last
  // journal (lib/timer.svelte.ts).
  // - Start: asks them to join the huddle (TimerPrompt). Already in it just chilling, it counts again and Slack
  //   asks what they are working on.
  // - Pause in the huddle: asks whether to stay without counting or leave. Pause on the site timer stops it.
  // - Resume: back to counting in the huddle.
  // Until the first answer arrives it shows no time at all, just a light sweeping over it.
  let now = $state(Date.now())
  $effect(() => {
    if (timer.running !== 'huddle' && timer.running !== 'timer') return
    const tick = setInterval(() => (now = Date.now()), 1000)
    return () => clearInterval(tick)
  })
  const shown = $derived(formatTracked(shownSeconds(now)))

  function start() {
    if (timer.inHuddle) askGoal()
    else timer.prompt = 'join'
  }

  const segment =
    'flex items-center gap-1.5 py-1 pr-2.5 pl-2 font-semibold transition-colors hover:bg-white/10 focus-visible:bg-white/10 focus-visible:outline-none disabled:opacity-60'
</script>

<!-- Its own presses never pick the pet up. -->
<div
  class="relative flex items-center overflow-hidden rounded-full border-2 border-gold bg-dark-blue font-outfit text-sm text-cream shadow-[0_6px_16px_-6px_rgba(0,0,0,0.7)]"
  onpointerdown={(event) => event.stopPropagation()}
  role="group"
  aria-label="Time since your last journal"
  aria-busy={!timer.loaded}
>
  {#if timer.running === 'huddle'}
    <button
      type="button"
      class={segment}
      onclick={() => (timer.prompt = 'pause')}
      title="Counting while you're in the huddle"
    >
      <span class="relative flex size-2">
        <span class="absolute inline-flex size-full animate-ping rounded-full bg-gold opacity-75"></span>
        <span class="relative inline-flex size-2 rounded-full bg-gold"></span>
      </span>
      Pause
    </button>
  {:else if timer.running === 'timer'}
    <button type="button" class={segment} onclick={stopTimer}>
      <SolarPause size={14} class="text-gold" />
      Pause
    </button>
  {:else if timer.running === 'paused'}
    <button type="button" class={segment} onclick={resumeHuddle} title="In the huddle, not counting">
      <SolarPlay size={14} class="text-gold" />
      Resume
    </button>
  {:else}
    <button type="button" class={segment} onclick={start} disabled={!timer.loaded}>
      <SolarPlay size={14} class="text-gold" />
      Start
    </button>
  {/if}
  <span
    class={[
      'border-l-2 border-gold/40 py-1 pr-3 pl-2.5 tabular-nums',
      timer.running === 'paused' && 'text-pale-blue/70',
    ]}
  >
    {#if timer.loaded}
      {shown}
    {:else}
      <!-- the width of "00:00", so the pill does not jump when the time arrives -->
      <span class="relative block h-[1.25em] w-[5ch]">
        <span class="absolute inset-x-0 top-1/2 h-2.5 -translate-y-1/2 rounded-full bg-white/10"></span>
      </span>
    {/if}
  </span>
  {#if !timer.loaded}
    <span class="pointer-events-none absolute inset-0 sweep" aria-hidden="true"></span>
  {/if}
</div>
