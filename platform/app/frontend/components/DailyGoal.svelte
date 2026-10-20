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

  // The top of "Your hours": today's journaled time against the daily goal, with the best case under it so the
  // number never looks like the only way.
  let { goal, today, team, rules }: { goal: Goal; today: number; team: string; rules: TeamRules } = $props()

  // The best case is the goal; the pace without the team's reward is the fallback under it.
  const left = $derived(Math.max(goal.best_minutes - today, 0))
  const saves = $derived(goal.best_minutes < goal.minutes)
  const how = $derived.by(() => {
    if (team === 'lulu')
      return saves
        ? `Journal on ${rules.lulu_days} days every week for Lulu's +${rules.lulu_bonus} XP bonus.`
        : 'No Lulu bonus weeks are left before the deadline.'
    return saves
      ? `Keep your streak every week and Sami takes your multiplier to ${rules.sami_max}x.`
      : `You're at Sami's ${rules.sami_max}x already, so keep the streak going.`
  })
</script>

<div class="px-5 py-5 md:px-6">
  <div class="flex flex-wrap items-baseline justify-between gap-x-4 gap-y-1">
    <h3 class="font-montserrat text-lg font-semibold tracking-[-0.02em] text-white">Today's goal</h3>
    <p
      class="font-montserrat text-sm font-semibold text-cream/70"
      title="Until {deadlineFormatter.format(new Date(goal.deadline))}"
    >
      <span class="text-saffron">{goal.days_left}</span>
      {goal.days_left === 1 ? 'day' : 'days'} to reach the final form
    </p>
  </div>
  <p class="mt-3 font-display text-4xl leading-none text-white md:text-5xl">
    {formatMinutes(goal.best_minutes)}
    <span class="ml-1 font-montserrat text-lg font-semibold text-cream">of journaled time</span>
  </p>
  <div
    class="meter mt-4 h-3"
    role="progressbar"
    aria-label="Journaled today"
    aria-valuenow={Math.min(today, goal.best_minutes)}
    aria-valuemin={0}
    aria-valuemax={goal.best_minutes}
  >
    <div style:width="{Math.min(today / goal.best_minutes, 1) * 100}%"></div>
  </div>
  <div class="mt-2 flex flex-wrap justify-between gap-x-4 font-outfit text-sm text-sky-ice/70">
    <span><strong class="font-semibold text-white">{formatMinutes(today)}</strong> journaled today</span>
    <span>{left === 0 ? 'Done for today!' : `${formatMinutes(left)} to go`}</span>
  </div>
  <p class="mt-4 font-outfit text-pale-blue">
    {how}
    {#if saves}Without it, {formatMinutes(goal.minutes)} a day.{/if}
    You can do it!
  </p>
</div>
