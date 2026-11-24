<script lang="ts">
  import { shared } from '@/lib/shared.svelte'
  import { announced, type Boost } from './FlashBoostOverlay.svelte'

  // While the flash event (FlashBoost) runs: a shining gold notice beside Home's title saying what the person's team
  // gets and how long is left, and the page's big type in gold, once they've been through the dialog
  // (FlashBoostOverlay). Not dismissable; gone once it ends, even on a page loaded before then.
  let { boost }: { boost?: Boost | null } = $props()

  const pet = $derived(shared().auth.user?.pet)
  // Ticks so the countdown stays live, and the notice goes the moment the event ends.
  let now = $state(Date.now())
  $effect(() => {
    const id = setInterval(() => (now = Date.now()), 30_000)
    return () => clearInterval(id)
  })
  const left = $derived(boost ? new Date(boost.ends_at).getTime() - now : 0)
  const running = $derived(left > 0)
  // "4d 7h left", then "7h left" on the last day, and minutes in the last hour.
  const countdown = $derived.by(() => {
    const minutes = Math.ceil(left / 60_000)
    const days = Math.floor(minutes / 1440)
    const hours = Math.floor((minutes % 1440) / 60)
    if (minutes < 60) return `${minutes}m left`
    return days ? `${days}d ${hours}h left` : `${hours}h left`
  })
  const on = $derived(!!boost && running && !!pet && announced.done)

  // The page's gold is keyed off <html>, since it's outside this component.
  $effect(() => {
    if (!on) return
    document.documentElement.dataset.flashBoost = ''
    return () => delete document.documentElement.dataset.flashBoost
  })
</script>

{#if on && boost}
  <p
    class="flash-notice relative max-w-full overflow-hidden rounded-[4px] bg-saffron px-5 py-2.5 font-montserrat text-base font-semibold text-slate-ink md:mt-1 md:text-lg"
  >
    {#if pet === 'sami'}
      +{boost.sami_step} multiplier
    {:else}
      {Number(boost.lulu_factor.toFixed(2))}× XP
    {/if}
    on journals · {countdown}
  </p>
{/if}

<style>
  /* A band of light sweeping across every few seconds. */
  .flash-notice::after {
    content: '';
    position: absolute;
    inset: 0;
    background: linear-gradient(110deg, transparent 35%, rgb(255 255 255 / 0.55) 50%, transparent 65%);
    transform: translateX(-100%);
    animation: flash-shine 3.2s ease-in-out infinite;
    pointer-events: none;
  }

  @keyframes flash-shine {
    60%,
    100% {
      transform: translateX(100%);
    }
  }

  @media (prefers-reduced-motion: reduce) {
    .flash-notice::after {
      animation: none;
      display: none;
    }
  }

  /* The title, card headings and big numbers. */
  :global(html[data-flash-boost] main .font-display) {
    color: var(--color-saffron);
  }
</style>
