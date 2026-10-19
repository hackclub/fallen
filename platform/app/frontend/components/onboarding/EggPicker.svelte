<script module lang="ts">
  import luluEgg from '@/assets/onboarding/lulu-egg.png'
  import samiEgg from '@/assets/onboarding/sami-egg.png'
  import type { TeamRules } from '@/types'

  // The two eggs to choose from, one per pet. The pet is also the team, and each rewards journaling its own way
  // (app/models/team.rb); `perks` says how, with the numbers from the server.
  export const EGGS = [
    {
      value: 'lulu',
      label: 'Lulu',
      src: luluEgg,
      tagline: 'Steady weeks',
      perks: (r: TeamRules) => [
        `+${r.lulu_bonus} XP for every week you journal on ${r.lulu_days} days`,
        `${7 - r.lulu_days} days off a week, no penalty`,
      ],
    },
    {
      value: 'sami',
      label: 'Sami',
      src: samiEgg,
      tagline: 'Daily streaks',
      perks: (r: TeamRules) => [
        `Each week you journal every day adds +${r.sami_step}x to all your XP, up to ${r.sami_max}x`,
        `${r.sami_freezes} freezes cover missed days, then it drops back to 1x`,
      ],
    },
  ]

  // Gap between the picker and the top of the speech bubble, which DialogStage gives as --dlg-clear.
  const ABOVE_BUBBLE = '2rem'
  const SPARKS = 6
</script>

<script lang="ts">
  import { starPath } from '@/components/GoldFrame.svelte'
  import { gestures } from '@/components/dialog/gestures'
  import { enter, exit, styler } from '@/components/dialog/motion'
  import { shared } from '@/lib/shared.svelte'
  import { launchEgg } from './eggLaunch'

  let { onpick }: { onpick: (value: string) => void } = $props()

  let pick = $state<string | null>(null)
  // The egg under the pointer or keyboard focus, so the perks can be compared before picking.
  let hover = $state<string | null>(null)
  const shown = $derived(EGGS.find((e) => e.value === (hover ?? pick)))
  // Sent while onboarding, and always in development so a replay shows them too.
  const rules = $derived.by(() => {
    const { setup, team_rules } = shared()
    return setup?.step === 'onboarding' ? setup.rules : team_rules
  })
  let launching = $state(false)
  let card: HTMLElement
  const eggs: Record<string, HTMLImageElement> = {}

  // The chosen egg flies to the one talking and becomes it; the card clears out of the way meanwhile.
  function confirm() {
    if (!pick || launching) return
    const value = pick
    launching = true
    styler(card).animate({ opacity: 0, scale: 0.96 }, { duration: 0.35, ease: 'easeOut', delay: 0.15 })
    launchEgg({
      from: eggs[value],
      src: EGGS.find((e) => e.value === value)!.src,
      onImpact: () => onpick(value),
    })
  }

  // The chosen egg rocks gently, as if something inside is moving; the other one rests.
  function rock(selected: boolean) {
    return (el: HTMLElement) => {
      const s = styler(el)
      if (selected) {
        s.animate(
          { rotate: [0, -6, 5, -3, 0] },
          { duration: 1.1, ease: 'easeInOut', repeat: Infinity, repeatDelay: 0.6 },
        )
      } else s.animate({ rotate: 0 }, { type: 'spring', stiffness: 300, damping: 18 })
      return () => s.stop()
    }
  }

  // A ring of gold stars bursts out of an egg when it is picked.
  function spark(i: number) {
    const angle = (i / SPARKS) * Math.PI * 2 - Math.PI / 2
    return enter(
      { x: 0, y: 0, scale: 0, opacity: 1, rotate: 0 },
      {
        x: Math.cos(angle) * 130,
        y: Math.sin(angle) * 150,
        scale: [0, 1.2, 0],
        opacity: [1, 1, 0],
        rotate: 90,
      },
      { duration: 0.8, ease: [0.16, 1, 0.3, 1] },
    )
  }
</script>

{#snippet star()}
  <svg aria-hidden="true" viewBox="0 0 29.1 29.1" class="size-3 rotate-45 fill-current"
    ><path d={starPath} /></svg
  >
{/snippet}

<!-- svelte-ignore a11y_click_events_have_key_events, a11y_no_static_element_interactions -->
<div
  class="absolute inset-x-0 top-0 z-[5] flex items-center justify-center px-3 pt-9 pb-3 sm:px-6 sm:pt-10 sm:pb-4"
  style:bottom="calc(var(--dlg-clear) + {ABOVE_BUBBLE})"
  style:container-type="size"
  onclick={(event) => event.stopPropagation()}
  out:exit|global={{
    target: { opacity: 0, y: -24, scale: 0.96 },
    transition: { duration: 0.2, ease: 'easeIn' },
    duration: 0.2,
  }}
>
  <div
    bind:this={card}
    class="game-card relative flex max-h-full w-full max-w-[560px] flex-col items-center gap-4 px-4 pb-5 sm:gap-5 sm:px-7 sm:pb-6"
    style:transform-origin="50% 100%"
    {@attach enter(
      { opacity: 0, scale: 0.85, y: 40 },
      { opacity: 1, scale: 1, y: 0 },
      { type: 'spring', stiffness: 320, damping: 20 },
    )}
  >
    <h2
      class="game-tab -mt-6 shrink-0"
      {@attach enter(
        { opacity: 0, y: 14, scale: 0.5 },
        { opacity: 1, y: 0, scale: 1 },
        { type: 'spring', stiffness: 420, damping: 16, delay: 0.12 },
      )}
    >
      Choose your egg
    </h2>

    <div role="radiogroup" aria-label="Eggs" class="grid min-h-0 w-full grid-cols-2 gap-3 sm:gap-5">
      {#each EGGS as option, i (option.value)}
        {@const selected = pick === option.value}
        <button
          type="button"
          role="radio"
          aria-checked={selected}
          aria-label={option.label}
          class="egg-tile relative flex cursor-pointer flex-col items-center rounded-3xl px-2 pt-4 pb-3 outline-none"
          {@attach enter(
            { opacity: 0, y: 50, scale: 0.6 },
            { opacity: 1, y: 0, scale: 1 },
            { type: 'spring', stiffness: 420, damping: 18, delay: 0.2 + i * 0.08 },
          )}
          onclick={() => !launching && (pick = option.value)}
          onpointerenter={() => (hover = option.value)}
          onpointerleave={() => hover === option.value && (hover = null)}
          onfocus={() => (hover = option.value)}
          onblur={() => hover === option.value && (hover = null)}
        >
          <!-- Hops on hover and dips when pressed, on its own element so it composes with the entrance. -->
          <span
            class="relative flex flex-col items-center"
            {@attach gestures({
              rest: { y: selected ? -4 : 0 },
              hover: { y: -6 },
              press: { y: 2 },
              transition: { type: 'spring', stiffness: 500, damping: 14 },
            })}
          >
            {#if selected}
              {#key pick}
                {#each { length: SPARKS }, s (s)}
                  <svg
                    aria-hidden="true"
                    viewBox="0 0 29.1 29.1"
                    class="pointer-events-none absolute top-1/2 left-1/2 -mt-2.5 -ml-2.5 size-5"
                    {@attach spark(s)}
                  >
                    <path d={starPath} fill="#F9AF3F" />
                  </svg>
                {/each}
              {/key}
            {/if}
            <img
              bind:this={eggs[option.value]}
              src={option.src}
              alt=""
              draggable="false"
              class={[
                // Shrinks on short screens so the card fits above the speech bubble: 21rem is everything else in it.
                'relative h-[clamp(4.5rem,calc(100cqh-21rem),9.5rem)] w-auto drop-shadow-[0_6px_0_rgba(80,60,30,0.15)] transition-opacity duration-300 select-none',
                pick && !selected && 'opacity-60',
              ]}
              style:transform-origin="50% 90%"
              {@attach rock(selected)}
            />
          </span>
          <span class="mt-2 font-dialog text-2xl leading-none text-ink">{option.label}</span>
          <span class="egg-tagline mt-1 font-outfit text-sm text-ink-soft">{option.tagline}</span>
          {#if selected}
            <span
              aria-hidden="true"
              class="absolute -top-2.5 -right-2.5 grid size-9 place-items-center rounded-full border-[3px] border-white bg-[#1cb0f6] text-white shadow-[0_3px_0_#1683c0]"
              {@attach enter(
                { scale: 0, rotate: -45 },
                { scale: 1, rotate: 0 },
                { type: 'spring', stiffness: 600, damping: 14 },
              )}
            >
              <svg viewBox="0 0 16 16" class="size-4" fill="none" stroke="currentColor" stroke-width="3">
                <path d="M3 8.5l3.2 3L13 4.5" stroke-linecap="round" stroke-linejoin="round" />
              </svg>
            </span>
          {/if}
          {#if rules}
            <span class="sr-only">{option.perks(rules).join('. ')}.</span>
          {/if}
        </button>
      {/each}
    </div>

    <!-- What the hovered or picked egg's team rewards. Its height is held so the button below never jumps. -->
    {#if rules}
      <div
        aria-hidden="true"
        class="flex min-h-[4.75rem] w-full shrink-0 items-center rounded-2xl bg-paper-well px-4 py-3 font-outfit text-sm text-ink sm:text-[15px]"
        {@attach enter(
          { opacity: 0, y: 12 },
          { opacity: 1, y: 0 },
          { type: 'spring', stiffness: 400, damping: 26, delay: 0.35 },
        )}
      >
        {#key shown?.value}
          <div
            class="w-full"
            {@attach enter({ opacity: 0, y: 6 }, { opacity: 1, y: 0 }, { duration: 0.2, ease: 'easeOut' })}
          >
            {#if shown}
              <ul class="flex flex-col gap-1.5">
                {#each shown.perks(rules) as perk (perk)}
                  <li class="flex items-baseline gap-2.5">
                    <span class="translate-y-[1px] text-saffron">{@render star()}</span>
                    <span>{perk}</span>
                  </li>
                {/each}
              </ul>
            {:else}
              <p class="text-center text-ink-soft">
                Each one rewards journaling its own way. Tap one to see how.
              </p>
            {/if}
          </div>
        {/key}
      </div>
    {/if}

    <button
      type="button"
      disabled={!pick}
      class="game-btn game-btn-blue min-w-52 shrink-0 text-xl"
      {@attach enter(
        { opacity: 0, y: 16 },
        { opacity: 1, y: 0 },
        { type: 'spring', stiffness: 400, damping: 22, delay: 0.45 },
      )}
      onclick={confirm}
    >
      This one!
    </button>
  </div>
</div>

<style>
  /* The dialog's option cards (dialog.css .dlg-option) at egg size: white on a hard ledge, lit blue once picked. */
  .egg-tile {
    --egg-edge: #e9dfc8;
    border: 3px solid var(--egg-edge);
    background: #fffdf8;
    box-shadow: 0 5px 0 var(--egg-edge);
    transition:
      background-color 0.15s,
      border-color 0.15s,
      box-shadow 0.15s;
  }
  .egg-tile:hover {
    background: #fff;
  }
  .egg-tile:focus-visible {
    --egg-edge: #84d8ff;
  }
  .egg-tile[aria-checked='true'] {
    --egg-edge: #84d8ff;
    background: #ddf4ff;
  }
  .egg-tile[aria-checked='true'] .egg-tagline {
    color: #1683c0;
  }
</style>
