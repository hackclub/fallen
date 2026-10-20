<script module lang="ts">
  import luluEgg from '@/assets/onboarding/lulu-egg.png'
  import samiEgg from '@/assets/onboarding/sami-egg.png'
  import type { PetGoals, TeamRules } from '@/types'

  // The two eggs to choose from, one per pet. The pet is also the team, and each rewards journaling its own way
  // (app/models/team.rb); `perks` says how, with the numbers from the server.
  export const EGGS = [
    {
      value: 'lulu',
      label: 'Lulu',
      src: luluEgg,
      tagline: 'Steady weeks',
      daysOff: (r: TeamRules, g: PetGoals) => ({
        count: Math.round((g.days_left * (7 - r.lulu_days)) / 7),
        label: `${7 - r.lulu_days} a week`,
      }),
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
      daysOff: (r: TeamRules) => ({ count: r.sami_freezes, label: `${r.sami_freezes} in total` }),
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
  import GoldFrame, { starPath } from '@/components/GoldFrame.svelte'
  import { gestures } from '@/components/dialog/gestures'
  import { enter, exit, styler } from '@/components/dialog/motion'
  import { formatMinutes } from '@/lib/format'
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
  const goals = $derived.by(() => {
    const { setup, team_goals } = shared()
    return setup?.step === 'onboarding' ? setup.goals : team_goals
  })

  // Each egg side by side: days off over the rest of the program, and how much less time a day its reward asks for at
  // its best. Bars are against the better of the two, so the difference is what stands out.
  const stats = $derived.by(() => {
    if (!rules || !goals) return null
    const rows = EGGS.map((egg) => {
      const best = goals.best_minutes[egg.value]
      return { value: egg.value, off: egg.daysOff(rules, goals), saved: 1 - best / goals.minutes, best }
    })
    const mostOff = Math.max(1, ...rows.map((r) => r.off.count))
    const mostSaved = Math.max(0.01, ...rows.map((r) => r.saved))
    return Object.fromEntries(
      rows.map((r) => [
        r.value,
        {
          bars: [
            { label: 'Days off', value: r.off.label, share: r.off.count / mostOff },
            { label: 'Time saved', value: `${Math.round(r.saved * 100)}%`, share: r.saved / mostSaved },
          ],
          best: `${formatMinutes(r.best)} a day`,
        },
      ]),
    )
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
  <svg aria-hidden="true" viewBox="0 0 29.1 29.1" class="size-2.5 rotate-45 fill-current"
    ><path d={starPath} /></svg
  >
{/snippet}

<!-- svelte-ignore a11y_click_events_have_key_events, a11y_no_static_element_interactions -->
<div
  class="absolute inset-x-0 top-0 z-[5] flex items-center justify-center px-3 py-3 sm:px-6 sm:py-4"
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
    class="relative flex max-h-full w-full max-w-[640px] flex-col items-center gap-3 rounded-2xl bg-dark-blue px-5 py-6 sm:gap-4 sm:px-10 sm:py-8 shadow-[0_30px_80px_-20px_rgba(0,0,0,0.8)]"
    style:transform-origin="50% 100%"
    {@attach enter(
      { opacity: 0, scale: 0.85, y: 40 },
      { opacity: 1, scale: 1, y: 0 },
      { type: 'spring', stiffness: 320, damping: 24 },
    )}
  >
    <GoldFrame />

    <h2
      class="relative z-4 font-lora text-2xl font-bold sm:text-3xl text-parchment text-shadow-md text-shadow-dark-purple/40"
      {@attach enter(
        { opacity: 0, y: 12 },
        { opacity: 1, y: 0 },
        { type: 'spring', stiffness: 400, damping: 26, delay: 0.15 },
      )}
    >
      Choose your egg
    </h2>

    <div
      role="radiogroup"
      aria-label="Eggs"
      class="relative z-4 flex min-h-0 items-end justify-center gap-8 pt-2 sm:gap-12 sm:pt-4"
    >
      {#each EGGS as option, i (option.value)}
        {@const selected = pick === option.value}
        <button
          type="button"
          role="radio"
          aria-checked={selected}
          aria-label={option.label}
          class="group relative flex cursor-pointer flex-col items-center outline-none"
          {@attach enter(
            { opacity: 0, y: 50, scale: 0.6 },
            { opacity: 1, y: 0, scale: 1 },
            { type: 'spring', stiffness: 420, damping: 18, delay: 0.25 + i * 0.1 },
          )}
          onclick={() => !launching && (pick = option.value)}
          onpointerenter={() => (hover = option.value)}
          onpointerleave={() => hover === option.value && (hover = null)}
          onfocus={() => (hover = option.value)}
          onblur={() => hover === option.value && (hover = null)}
        >
          <!-- Lifts on hover and dips when pressed, on its own element so it composes with the entrance. -->
          <span
            class="relative flex flex-col items-center"
            {@attach gestures({
              rest: { y: selected ? -10 : 0 },
              hover: { y: selected ? -14 : -8 },
              press: { y: 2 },
              transition: { type: 'spring', stiffness: 500, damping: 20 },
            })}
          >
            <!-- A spotlight from above, pale while the egg is hovered or focused and warm gold once it is chosen.
                 Blurred as a whole so the beam's sides are soft; the mask fades it in from above and out below. -->
            <span
              aria-hidden="true"
              class={[
                'pointer-events-none absolute -bottom-[14%] left-1/2 h-[155%] w-[160%] -translate-x-1/2 mix-blend-screen blur-[6px] transition-opacity duration-300 [mask-image:linear-gradient(to_bottom,transparent,black_45%,black_80%,transparent)]',
                selected
                  ? 'opacity-100'
                  : 'opacity-0 group-hover:opacity-100 group-focus-visible:opacity-100',
              ]}
            >
              <span
                class={[
                  'absolute inset-0 [clip-path:polygon(40%_0,60%_0,100%_100%,0_100%)]',
                  selected ? 'bg-gold/45' : 'bg-pale-blue/25',
                ]}
              ></span>
            </span>
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
                // Shrinks on short screens so the card fits above the speech bubble: 28rem is everything else in it.
                'relative h-[clamp(5rem,calc(100cqh-28rem),11rem)] w-auto drop-shadow-[0_10px_18px_rgba(0,0,0,0.45)] transition-[opacity] duration-300 select-none',
                pick && !selected && 'opacity-55',
              ]}
              style:transform-origin="50% 90%"
              {@attach rock(selected)}
            />
          </span>
          <span
            class={[
              'mt-2 font-lora text-lg font-semibold transition-colors',
              selected ? 'text-gold' : 'text-pale-blue/70 group-hover:text-pale-blue',
            ]}
          >
            {option.label}
          </span>
          <span
            class={[
              'text-sm transition-colors',
              selected ? 'text-pale-blue' : 'text-pale-blue/50 group-hover:text-pale-blue/80',
            ]}
          >
            {option.tagline}
          </span>
          {#if stats}
            {@const stat = stats[option.value]}
            <dl aria-hidden="true" class="mt-3 w-32 space-y-2 text-left text-xs sm:w-40">
              {#each stat.bars as bar (bar.label)}
                <div>
                  <div class="flex justify-between gap-2">
                    <dt class="text-pale-blue/60">{bar.label}</dt>
                    <dd class={selected ? 'text-parchment' : 'text-pale-blue/80'}>{bar.value}</dd>
                  </div>
                  <div class="mt-1 h-1.5 overflow-hidden rounded-full bg-pale-blue/15">
                    <div
                      class={[
                        'h-full rounded-full transition-[background-color,width] duration-500',
                        selected ? 'bg-gold' : 'bg-pale-blue/50 group-hover:bg-pale-blue/70',
                      ]}
                      style:width="{bar.share * 100}%"
                    ></div>
                  </div>
                </div>
              {/each}
              <div class="flex justify-between gap-2 pt-0.5">
                <dt class="text-pale-blue/60">Best case</dt>
                <dd class={selected ? 'font-semibold text-gold' : 'text-pale-blue/80'}>{stat.best}</dd>
              </div>
            </dl>
          {/if}
          {#if rules}
            <span class="sr-only"
              >{option.perks(rules).join('. ')}.{#if stats}
                At best, {stats[option.value].best} to reach the final form.{/if}</span
            >
          {/if}
        </button>
      {/each}
    </div>

    <!-- What the hovered or picked egg's team rewards. Its height is held so the button below never jumps. -->
    {#if rules}
      <div
        aria-hidden="true"
        class="relative z-4 flex min-h-[4.5rem] w-full max-w-md items-center justify-center text-sm text-pale-blue sm:text-base"
        {@attach enter(
          { opacity: 0, y: 12 },
          { opacity: 1, y: 0 },
          { type: 'spring', stiffness: 400, damping: 26, delay: 0.4 },
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
                    <span class="translate-y-[-1px] text-gold">{@render star()}</span>
                    <span>{perk}</span>
                  </li>
                {/each}
              </ul>
            {:else}
              <p class="text-center text-pale-blue/60">
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
      class="relative z-4 mt-2 flex cursor-pointer items-center gap-4 sm:gap-7 rounded-full border border-gold bg-gradient-to-b from-[#f3dea2] to-gold px-5 py-2.5 font-lora text-lg font-bold text-dark-blue shadow-[0_0_18px_color-mix(in_oklab,var(--color-gold)_45%,transparent)] transition-opacity disabled:cursor-not-allowed disabled:opacity-40 disabled:shadow-none"
      {@attach enter(
        { opacity: 0, y: 16 },
        { opacity: 1, y: 0 },
        { type: 'spring', stiffness: 400, damping: 24, delay: 0.5 },
      )}
      {@attach gestures({
        rest: {},
        hover: pick ? { scale: 1.05 } : undefined,
        press: pick ? { scale: 0.95 } : undefined,
        transition: { type: 'spring', stiffness: 500, damping: 20 },
      })}
      onclick={confirm}
    >
      {@render star()}
      This one!
      {@render star()}
    </button>
  </div>
</div>
