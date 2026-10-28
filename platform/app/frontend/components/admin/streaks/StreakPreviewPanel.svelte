<script lang="ts">
  import ArrowRight from '@lucide/svelte/icons/arrow-right'
  import CircleAlert from '@lucide/svelte/icons/circle-alert'
  import Clock from '@lucide/svelte/icons/clock'
  import LoaderCircle from '@lucide/svelte/icons/loader-circle'
  import {
    OUTCOMES,
    dayLabel,
    formatMultiplier,
    plural,
    previewChanges,
    rangeLabel,
    signedXp,
    type StreakPreview,
  } from '@/lib/streaks'

  // What a restore would do, worked out by the server as the form is filled in. `loading` dims the last answer
  // rather than blanking it, so the panel doesn't jump while typing.
  let { preview, loading }: { preview: StreakPreview | null | undefined; loading: boolean } = $props()

  const plan = $derived(preview?.plan)
</script>

<div
  class={['rounded-lg border bg-muted/30 p-3 text-sm transition-opacity', loading && preview && 'opacity-60']}
  aria-live="polite"
>
  <div
    class="mb-2 flex items-center gap-1.5 text-xs font-medium tracking-wide text-muted-foreground uppercase"
  >
    What happens
    {#if loading}<LoaderCircle class="size-3 animate-spin" />{/if}
  </div>

  {#if !preview}
    <p class="text-muted-foreground">Working it out…</p>
  {:else if preview.errors.length}
    {#each preview.errors as error (error)}
      <p class="flex gap-1.5 text-destructive"><CircleAlert class="mt-0.5 size-4 shrink-0" />{error}</p>
    {/each}
  {:else if plan}
    {#if previewChanges(plan)}
      <dl class="grid grid-cols-[auto_1fr] gap-x-4 gap-y-1.5">
        {#if plan.multiplier[0] !== plan.multiplier[1]}
          <dt class="text-muted-foreground">Multiplier</dt>
          <dd class="flex items-center gap-1.5 font-medium tabular-nums">
            {formatMultiplier(plan.multiplier[0])}
            <ArrowRight class="size-3.5 text-muted-foreground" />
            <span
              class={plan.multiplier[1] > plan.multiplier[0]
                ? 'text-emerald-600 dark:text-emerald-400'
                : 'text-destructive'}>{formatMultiplier(plan.multiplier[1])}</span
            >
          </dd>
        {/if}
        {#if plan.freezes[0] !== plan.freezes[1]}
          <dt class="text-muted-foreground">Freezes</dt>
          <dd class="flex items-center gap-1.5 font-medium tabular-nums">
            {plan.freezes[0]}
            <ArrowRight class="size-3.5 text-muted-foreground" />
            <span
              class={plan.freezes[1] > plan.freezes[0]
                ? 'text-sky-600 dark:text-sky-400'
                : 'text-destructive'}>{plan.freezes[1]}</span
            >
          </dd>
        {/if}
        {#if plan.xp !== 0 || plan.journals > 0}
          <dt class="text-muted-foreground">XP</dt>
          <dd>
            <span class={['font-medium tabular-nums', plan.xp < 0 && 'text-destructive']}
              >{signedXp(plan.xp)}</span
            >
            {#if plan.journals > 0}
              <span class="text-muted-foreground">
                · {plural(plan.journals, 'journal')} re-counted at the new multiplier</span
              >
            {/if}
          </dd>
        {/if}
        {#each plan.weeks as week (week.start)}
          {#if week.outcome[0] !== week.outcome[1]}
            <dt class="text-muted-foreground">Week of {dayLabel(week.start)}</dt>
            <dd class="flex items-center gap-1.5">
              {OUTCOMES[week.outcome[0]]}
              <ArrowRight class="size-3.5 text-muted-foreground" />
              <span class={week.outcome[1] === 'broken' ? 'text-destructive' : 'font-medium'}
                >{OUTCOMES[week.outcome[1]]}</span
              >
            </dd>
          {/if}
        {/each}
        {#each plan.bonuses as bonus (bonus.start)}
          <dt class="text-muted-foreground">Lulu, {rangeLabel(bonus.start, bonus.finish)}</dt>
          <dd class={bonus.pay ? 'font-medium' : 'text-destructive'}>
            {bonus.pay ? 'Bonus paid' : 'Bonus taken back'}, {signedXp(bonus.xp)}
          </dd>
        {/each}
      </dl>
      {#if plan.broken > 0}
        <p class="mt-2 flex gap-1.5 text-destructive">
          <CircleAlert class="mt-0.5 size-4 shrink-0" />
          {plural(plan.broken, 'week')} that held would break.
        </p>
      {/if}
    {:else}
      <p class="text-muted-foreground">Nothing changes right now.</p>
    {/if}
    {#if plan.open_days.length}
      <p class="mt-2 flex gap-1.5 text-muted-foreground">
        <Clock class="mt-0.5 size-4 shrink-0" />
        {plan.open_days.length === 1
          ? `${dayLabel(plan.open_days[0])} is`
          : `${plural(plan.open_days.length, 'day')} are`}
        in a week that hasn't closed yet, and will count when it does.
      </p>
    {/if}
  {/if}
</div>
