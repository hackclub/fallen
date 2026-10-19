<script module lang="ts">
  import type { TeamRules } from '@/types'

  // What HomeController#xp sends: XP and form, the person's team and its week so far, and the race between the teams.
  export interface Standing {
    total: number
    form: number
    next_stage_xp: number | null
    progress: number
    team: string | null
    multiplier: number
    freezes: number
    rules: TeamRules
    week: {
      start: string
      today: string
      days: string[]
      since: string | null
      totals: Record<string, number>
    }
  }

  const TEAM_NAMES: Record<string, string> = { lulu: 'Lulu', sami: 'Sami' }
  const weekdayFormatter = new Intl.DateTimeFormat(undefined, { weekday: 'narrow' })
  const dayFormatter = new Intl.DateTimeFormat(undefined, { weekday: 'long', month: 'short', day: 'numeric' })

  const parse = (iso: string) => {
    const [y, m, d] = iso.split('-').map(Number)
    return new Date(y, m - 1, d)
  }
  const iso = (date: Date) =>
    `${date.getFullYear()}-${String(date.getMonth() + 1).padStart(2, '0')}-${String(date.getDate()).padStart(2, '0')}`
</script>

<script lang="ts">
  import { FINAL_FORM } from '@/lib/pet.svelte'

  // XP and the way to the next form on top; below, this week on the person's team (a dot per day: Monday to Sunday
  // for Sami, from the weekday of the first journal for Lulu, with the goal in a line) beside the race between the
  // teams. The pet itself is already on the page (DesktopPet).
  let { xp }: { xp: Standing } = $props()

  const stage = $derived(Math.max(xp.form, 1))

  // Each day of the week: journaled, missed (for Sami, a past day since the streak began with nothing logged), or
  // still to come.
  const days = $derived.by(() => {
    const start = parse(xp.week.start)
    return Array.from({ length: 7 }, (_, i) => {
      const date = new Date(start)
      date.setDate(start.getDate() + i)
      const day = iso(date)
      const journaled = xp.week.days.includes(day)
      const past = day < xp.week.today
      const missed =
        xp.team === 'sami' && past && !journaled && xp.week.since !== null && day >= xp.week.since
      return { day, date, journaled, missed, today: day === xp.week.today, future: day > xp.week.today }
    })
  })
  const journaled = $derived(days.filter((d) => d.journaled).length)

  const race = $derived.by(() => {
    const teams = Object.keys(TEAM_NAMES).map((name) => ({
      name,
      label: TEAM_NAMES[name],
      xp: xp.week.totals[name] ?? 0,
    }))
    const most = Math.max(1, ...teams.map((t) => t.xp))
    return teams.map((t) => ({ ...t, share: t.xp / most }))
  })

  const goal = $derived(
    xp.team === 'lulu'
      ? `${journaled} of ${xp.rules.lulu_days} days for +${xp.rules.lulu_bonus} XP`
      : `${xp.multiplier}x on every journal · ${xp.freezes} ${xp.freezes === 1 ? 'freeze' : 'freezes'} left`,
  )
  const rule = $derived(
    xp.team === 'lulu'
      ? `Journal on ${xp.rules.lulu_days} days in a week and you get +${xp.rules.lulu_bonus} XP the day after it ends. Your weeks start on the day of your first journal.`
      : `A week without a missed day adds ${xp.rules.sami_step}x, up to ${xp.rules.sami_max}x. A missed day spends a freeze; with none left the multiplier goes back to 1x. The streak starts with your first journal.`,
  )
</script>

<section class="glass divide-y divide-white/10 font-outfit" aria-label="Your XP">
  <div class="setting-row">
    <div class="w-full">
      <div class="flex flex-wrap items-end justify-between gap-x-4 gap-y-1">
        <p class="font-display text-5xl leading-none text-white">
          {xp.total}<span class="ml-2 font-montserrat text-lg font-semibold text-cream">XP</span>
        </p>
        <p class="font-montserrat text-sm font-semibold text-cream/70">
          {#if xp.form === 0}
            Egg · hatches with your first journal
          {:else if xp.next_stage_xp}
            Stage {stage} · {xp.next_stage_xp - xp.total} XP to stage {stage + 1}
          {:else if xp.form < FINAL_FORM}
            Stage {stage} · final form once your project is approved
          {:else}
            Final form
          {/if}
        </p>
      </div>
      <div
        class="meter mt-4 h-3"
        role="progressbar"
        aria-label="Progress to the next stage"
        aria-valuenow={Math.round(xp.progress * 100)}
        aria-valuemin={0}
        aria-valuemax={100}
      >
        <div style:width="{xp.progress * 100}%"></div>
      </div>
    </div>
  </div>

  {#if xp.team}
    <div class="grid sm:grid-cols-2 sm:divide-x sm:divide-white/10 max-sm:divide-y max-sm:divide-white/10">
      <div class="setting-row">
        <div class="w-full">
          <div class="flex flex-wrap items-center gap-3">
            <h3 class="font-montserrat text-lg font-semibold tracking-[-0.02em] text-white">This week</h3>
            <span class="chip">Team {TEAM_NAMES[xp.team]}</span>
          </div>
          <ol class="mt-3 flex gap-1.5 sm:gap-2">
            {#each days as d (d.day)}
              <li
                title="{dayFormatter.format(d.date)}: {d.journaled
                  ? 'journaled'
                  : d.missed
                    ? 'missed, a freeze used'
                    : d.today
                      ? 'today'
                      : 'nothing yet'}"
                class={[
                  'grid size-8 place-items-center rounded-full font-montserrat text-xs font-semibold',
                  d.journaled && 'bg-cream text-slate-ink shadow-[0_0_12px_rgb(252_249_239/0.45)]',
                  d.missed && 'bg-saffron/80 text-slate-ink',
                  !d.journaled && !d.missed && 'bg-white/10 text-sky-ice/60',
                  d.today && 'outline-2 outline-offset-2 outline-cream',
                  d.future && 'opacity-50',
                ]}
              >
                {weekdayFormatter.format(d.date)}
              </li>
            {/each}
          </ol>
          <p
            class="mt-3 w-fit cursor-help text-sm text-pale-blue underline decoration-cream/30 decoration-dotted underline-offset-4"
            title={rule}
          >
            {goal}
          </p>
        </div>
      </div>

      <div class="setting-row">
        <div class="w-full">
          <h3 class="font-montserrat text-lg font-semibold tracking-[-0.02em] text-white">Teams this week</h3>
          <ol class="mt-3 space-y-2.5">
            {#each race as team (team.name)}
              <li class="grid grid-cols-[3rem_1fr_auto] items-center gap-3 text-sm">
                <span
                  class={team.name === xp.team
                    ? 'font-montserrat font-semibold text-white'
                    : 'font-montserrat font-semibold text-sky-ice/60'}>{team.label}</span
                >
                <div class="meter">
                  <div
                    class={[team.name !== xp.team && 'bg-white/40! shadow-none!']}
                    style:width="{team.share * 100}%"
                  ></div>
                </div>
                <span class="font-montserrat text-xs font-semibold text-cream/80 tabular-nums"
                  >{team.xp} XP</span
                >
              </li>
            {/each}
          </ol>
          <p class="mt-3 text-sm text-sky-ice/60">
            +{xp.rules.win_bonus} XP to everyone on the leading team on Monday.
          </p>
        </div>
      </div>
    </div>
  {/if}
</section>
