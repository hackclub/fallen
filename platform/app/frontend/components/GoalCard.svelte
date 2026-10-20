<script module lang="ts">
  import type { TeamRules } from '@/types'

  // What HomeController#goal sends (DailyGoal): minutes a day to the final form's XP by the deadline, at the
  // multiplier the person has now and with their team's reward at its best.
  export interface Goal {
    deadline: string
    days_left: number
    minutes: number
    best_minutes: number
  }

  const deadlineFormatter = new Intl.DateTimeFormat(undefined, {
    dateStyle: 'medium',
    timeStyle: 'short',
    timeZone: 'America/New_York',
  })
</script>

<script lang="ts">
  import { formatMinutes } from '@/lib/format'
  import { PET_NAMES } from '@/lib/pet.svelte'

  // Today's coding against the daily goal, with the best case under it so the number never looks like the only way.
  let { goal, today, team, rules }: { goal: Goal; today: number; team: string; rules: TeamRules } = $props()

  const left = $derived(Math.max(goal.minutes - today, 0))
  const done = $derived(left === 0)
  const saves = $derived(goal.best_minutes < goal.minutes)
  const how = $derived(
    team === 'lulu'
      ? `journal on ${rules.lulu_days} days every week for Lulu's +${rules.lulu_bonus} XP`
      : `keep your streak every week, taking your multiplier up to ${rules.sami_max}x`,
  )
</script>

<section class="glass divide-y divide-white/10 font-outfit" aria-labelledby="goal">
  <div class="flex flex-wrap items-baseline justify-between gap-x-4 pr-5 md:pr-6">
    <h2 id="goal" class="glass-heading">Today's goal</h2>
    <p
      class="font-montserrat text-sm font-semibold text-cream/70"
      title="Until {deadlineFormatter.format(new Date(goal.deadline))}"
    >
      <span class="text-saffron">{goal.days_left}</span>
      {goal.days_left === 1 ? 'day' : 'days'} to reach the final form
    </p>
  </div>

  <div class="px-5 py-5 md:px-6">
    <p class="font-display text-5xl leading-none text-white">
      {formatMinutes(goal.minutes)}
      <span class="ml-1 font-montserrat text-lg font-semibold text-cream">of coding</span>
    </p>
    <div
      class="meter mt-4 h-3"
      role="progressbar"
      aria-label="Coded today"
      aria-valuenow={Math.min(today, goal.minutes)}
      aria-valuemin={0}
      aria-valuemax={goal.minutes}
    >
      <div style:width="{Math.min(today / goal.minutes, 1) * 100}%"></div>
    </div>
    <div class="mt-2 flex flex-wrap justify-between gap-x-4 text-sm text-sky-ice/70">
      <span><strong class="font-semibold text-white">{formatMinutes(today)}</strong> journaled today</span>
      <span>{done ? 'Done for today!' : `${formatMinutes(left)} to go`}</span>
    </div>
  </div>

  <p class="px-5 py-4 text-pale-blue md:px-6">
    {#if saves}
      Or <strong class="font-semibold text-white">{formatMinutes(goal.best_minutes)} a day</strong> if you {how}.
    {/if}
    You can do it with {PET_NAMES[team]}!
  </p>
</section>
