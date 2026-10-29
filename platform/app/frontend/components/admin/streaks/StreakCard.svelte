<script lang="ts">
  import Check from '@lucide/svelte/icons/check'
  import Lock from '@lucide/svelte/icons/lock'
  import SlidersHorizontal from '@lucide/svelte/icons/sliders-horizontal'
  import Sparkles from '@lucide/svelte/icons/sparkles'
  import Snowflake from '@lucide/svelte/icons/snowflake'
  import TriangleAlert from '@lucide/svelte/icons/triangle-alert'
  import X from '@lucide/svelte/icons/x'
  import StreakDialog from '@/components/admin/streaks/StreakDialog.svelte'
  import StreakLog from '@/components/admin/streaks/StreakLog.svelte'
  import { Badge } from '@/components/admin/ui/badge'
  import { Button } from '@/components/admin/ui/button'
  import * as Card from '@/components/admin/ui/card'
  import {
    DAY_STATES,
    EXCUSABLE,
    addDays,
    OUTCOMES,
    dayLabel,
    dayOfMonth,
    daysBetween,
    formatMultiplier,
    longDayLabel,
    plural,
    rangeLabel,
    weekdayLabel,
    type StreakDay,
    type StreakKind,
    type StreakRow,
  } from '@/lib/streaks'
  import type { AdminStreak, AdminUserDetail } from '@/types'

  // Someone's streak, a week to a row, for seeing what happened and putting it right. Clicking a missed or coming
  // day picks it; clicking another picks the days between. Broken weeks (and Lulu weeks short of the bonus) offer
  // to restore themselves.
  let {
    user,
    streak,
    canAdjust,
    blocked,
  }: { user: AdminUserDetail; streak: AdminStreak; canAdjust: boolean; blocked: string | null } = $props()

  let anchor = $state<string | null>(null)
  let selection = $state<{ from: string; to: string } | null>(null)
  let hovered = $state<StreakDay | null>(null)
  let dialog = $state<{ open: boolean; kind: StreakKind }>({ open: false, kind: 'excuse' })

  const sami = $derived(streak.team === 'sami')
  const excuses = $derived(new Map(streak.adjustments.map((adjustment) => [adjustment.id, adjustment])))
  const latestBroken = $derived(streak.rows.findLast((row) => row.status === 'broken'))
  const earlierSami = $derived(streak.team === 'lulu' ? streak.judged : [])
  const selectedDays = $derived(selection ? daysBetween(selection.from, selection.to) + 1 : 0)

  const STATE_STYLES: Record<StreakDay['state'], string> = {
    before: 'text-muted-foreground/40',
    journal: 'bg-emerald-500 text-white dark:bg-emerald-600',
    excused:
      'bg-amber-200 text-amber-900 dark:bg-amber-900/70 dark:text-amber-100 bg-[repeating-linear-gradient(135deg,transparent_0_4px,rgb(255_255_255/0.35)_4px_8px)]',
    missed:
      'bg-red-50 text-red-700 ring-1 ring-red-200 ring-inset dark:bg-red-950/50 dark:text-red-300 dark:ring-red-900',
    frozen:
      'bg-sky-100 text-sky-800 ring-1 ring-sky-200 ring-inset dark:bg-sky-950/60 dark:text-sky-200 dark:ring-sky-900',
    today: 'border-2 border-dashed border-foreground/30 text-foreground',
    future: 'text-muted-foreground ring-1 ring-border ring-inset',
  }

  const OUTCOME_BADGES: Record<StreakRow['status'], string> = {
    kept: 'bg-emerald-100 text-emerald-800 dark:bg-emerald-950 dark:text-emerald-300',
    frozen: 'bg-sky-100 text-sky-800 dark:bg-sky-950 dark:text-sky-300',
    broken: 'bg-red-100 text-red-800 dark:bg-red-950 dark:text-red-300',
    open: 'bg-muted text-foreground',
    paid: 'bg-emerald-100 text-emerald-800 dark:bg-emerald-950 dark:text-emerald-300',
    unpaid: 'bg-muted text-muted-foreground',
    unjudged: 'bg-muted text-muted-foreground',
  }

  const excusable = (day: StreakDay) => canAdjust && EXCUSABLE.includes(day.state)
  const inSelection = (date: string) => Boolean(selection && date >= selection.from && date <= selection.to)

  function pick(day: StreakDay) {
    if (!excusable(day)) return
    if (selection && selection.from === selection.to && selection.from === day.date) {
      clear()
    } else if (anchor && selection) {
      selection = anchor < day.date ? { from: anchor, to: day.date } : { from: day.date, to: anchor }
    } else {
      anchor = day.date
      selection = { from: day.date, to: day.date }
    }
  }

  function clear() {
    anchor = null
    selection = null
  }

  // The days a restore needs: the week's days that didn't count, as one range.
  function restoreRange(row: StreakRow) {
    const days = row.days
      .filter((day) => day.state === 'missed' || day.state === 'frozen')
      .map((day) => day.date)
    return days.length ? { from: days[0], to: days[days.length - 1] } : null
  }

  function restore(row: StreakRow) {
    const range = restoreRange(row)
    if (!range) return
    anchor = range.from
    selection = range
    open('excuse')
  }

  function open(kind: StreakKind) {
    dialog = { open: true, kind }
  }

  // Missed days so far in a Sami week still open, against the freezes left: whether it will break as things stand.
  function atRisk(row: StreakRow) {
    if (!sami || row.status !== 'open') return null
    const missed = row.days.filter((day) => day.state === 'missed').length
    return { missed, breaks: missed > streak.freezes }
  }

  // A Lulu week short of the bonus that excusing its missed days would pay.
  function luluRestorable(row: StreakRow) {
    if (row.status !== 'unpaid') return false
    const missed = row.days.filter((day) => day.state === 'missed').length
    return row.counted + missed >= streak.rules.lulu_days
  }

  function describe(day: StreakDay) {
    const excuse = day.excuse_id ? excuses.get(day.excuse_id) : null
    const detail =
      day.state === 'journal'
        ? `Journaled, ${day.xp} XP`
        : excuse
          ? `Excused${excuse.incident ? ' for everyone' : ''}: “${excuse.reason}”, by ${excuse.admin?.name ?? 'someone'}`
          : DAY_STATES[day.state]
    return `${longDayLabel(day.date)} · ${detail}`
  }
</script>

<Card.Root id="streak" class="mt-6 scroll-mt-6">
  <Card.Header class="gap-3">
    <div class="flex flex-wrap items-start gap-x-6 gap-y-3">
      <div>
        <Card.Title class="flex items-center gap-2">
          Streak
          {#if streak.team}
            <Badge variant="outline" class="capitalize">Team {streak.team}</Badge>
          {/if}
        </Card.Title>
        <Card.Description class="mt-1">
          {#if !streak.team}
            No pet yet, so no team and no streak.
          {:else if !streak.first_day}
            No journals yet. The streak starts with the first one.
          {:else if sami}
            Each Monday the week before is judged: every day without a journal spends a freeze, and one with
            none left drops the multiplier to 1x.
          {:else}
            Team Lulu pays {streak.rules.lulu_bonus} XP for {streak.rules.lulu_days} journal days in a week, counted
            from the weekday of their first journal.
          {/if}
        </Card.Description>
      </div>
      <dl class="ml-auto flex gap-6">
        {#if sami}
          <div>
            <dt class="text-xs text-muted-foreground">Multiplier</dt>
            <dd class="text-2xl font-semibold tabular-nums">{formatMultiplier(streak.multiplier)}</dd>
          </div>
        {/if}
        <div>
          <dt class="text-xs text-muted-foreground">Freezes</dt>
          <dd class="flex items-center gap-1.5 text-2xl font-semibold tabular-nums">
            {streak.freezes}
            <span class="flex gap-0.5 text-sky-500" aria-hidden="true">
              {#each { length: Math.min(streak.freezes, 6) }, i (i)}<Snowflake class="size-3.5" />{/each}
            </span>
          </dd>
        </div>
      </dl>
    </div>

    {#if canAdjust}
      <div class="flex flex-wrap gap-2">
        {#if sami}
          <Button variant="outline" size="sm" onclick={() => open('freezes')}>
            <Snowflake data-icon="inline-start" /> Give freezes
          </Button>
          <Button variant="outline" size="sm" onclick={() => open('set')}>
            <SlidersHorizontal data-icon="inline-start" /> Set multiplier and freezes
          </Button>
        {/if}
        <Button variant="outline" size="sm" onclick={() => open('xp')}>
          <Sparkles data-icon="inline-start" /> Give XP
        </Button>
        {#if latestBroken}
          <Button size="sm" onclick={() => restore(latestBroken)}>
            Restore week of {dayLabel(latestBroken.start)}
          </Button>
        {/if}
      </div>
    {:else if blocked}
      <p class="flex items-center gap-1.5 text-sm text-muted-foreground">
        <Lock class="size-3.5" />
        {blocked}
      </p>
    {/if}
  </Card.Header>

  <Card.Content class="space-y-6">
    {#if streak.rows.length}
      <div>
        <div class="overflow-x-auto">
          <table class="w-full border-separate border-spacing-y-1.5 text-sm">
            <thead>
              <tr class="text-xs text-muted-foreground">
                <th class="w-20 pr-3 text-left font-normal">Week of</th>
                {#each streak.rows[0].days as day (day.date)}
                  <th class="w-10 font-normal">{weekdayLabel(day.date)}</th>
                {/each}
                <th class="pl-4 text-left font-normal">{sami ? 'Judged' : 'Bonus'}</th>
              </tr>
            </thead>
            <tbody>
              {#each streak.rows as row (row.start)}
                {@const risk = atRisk(row)}
                <tr>
                  <td class="pr-3 whitespace-nowrap text-muted-foreground tabular-nums"
                    >{dayLabel(row.start)}</td
                  >
                  {#each row.days as day (day.date)}
                    {@const picked = inSelection(day.date)}
                    <td class="px-0.5 text-center">
                      <button
                        type="button"
                        aria-label={describe(day)}
                        aria-pressed={excusable(day) ? picked : undefined}
                        disabled={!excusable(day)}
                        onclick={() => pick(day)}
                        onmouseenter={() => (hovered = day)}
                        onmouseleave={() => (hovered = null)}
                        onfocus={() => (hovered = day)}
                        onblur={() => (hovered = null)}
                        class={[
                          'relative mx-auto flex size-9 items-center justify-center rounded-md text-xs font-medium tabular-nums transition',
                          STATE_STYLES[day.state],
                          excusable(day)
                            ? 'cursor-pointer hover:scale-105 hover:shadow-sm'
                            : 'cursor-default',
                          picked && 'ring-2 ring-primary ring-offset-2 ring-offset-background',
                          day.date === streak.today &&
                            day.state !== 'today' &&
                            'outline-2 outline-offset-2 outline-foreground/20',
                        ]}
                      >
                        {#if day.state === 'frozen'}
                          <Snowflake class="size-3.5" />
                        {:else if day.state === 'missed' && row.status === 'broken'}
                          <X class="size-3.5" />
                        {:else}
                          {dayOfMonth(day.date)}
                        {/if}
                        {#if picked && excusable(day)}
                          <span
                            class="absolute -top-1.5 -right-1.5 flex size-4 items-center justify-center rounded-full bg-primary text-primary-foreground"
                            ><Check class="size-2.5" /></span
                          >
                        {/if}
                      </button>
                    </td>
                  {/each}
                  <td class="pl-4">
                    <div class="flex flex-wrap items-center gap-x-2 gap-y-1">
                      <span
                        class={[
                          'rounded-full px-2 py-0.5 text-xs font-medium whitespace-nowrap',
                          OUTCOME_BADGES[row.status],
                        ]}>{OUTCOMES[row.status]}</span
                      >
                      <span class="text-xs whitespace-nowrap text-muted-foreground tabular-nums">
                        {#if row.judged}
                          {formatMultiplier(row.judged.multiplier_before)} → {formatMultiplier(
                            row.judged.multiplier,
                          )}
                          {#if row.judged.missed}· {plural(row.judged.missed, 'day')} missed, {row.judged
                              .freezes_before} ❄ going in{/if}
                          {#if row.judged.excused}· {row.judged.excused} excused{/if}
                        {:else if risk}
                          {#if risk.missed}
                            {plural(risk.missed, 'day')} missed so far, {plural(streak.freezes, 'freeze')} left
                          {:else}
                            Judged {dayLabel(addDays(row.finish, 1))}
                          {/if}
                        {:else if !sami}
                          {row.counted} of {streak.rules.lulu_days} days{row.bonus_xp
                            ? ` · +${row.bonus_xp} XP`
                            : ''}
                        {/if}
                      </span>
                      {#if risk?.breaks}
                        <span class="flex items-center gap-1 text-xs text-destructive"
                          ><TriangleAlert class="size-3.5" /> Breaks unless days are excused</span
                        >
                      {/if}
                      {#if canAdjust && (row.status === 'broken' || luluRestorable(row))}
                        <Button
                          variant="link"
                          size="sm"
                          class="h-auto p-0 text-xs"
                          onclick={() => restore(row)}
                        >
                          {row.status === 'broken' ? 'Restore' : 'Pay the bonus'}
                        </Button>
                      {/if}
                    </div>
                  </td>
                </tr>
              {/each}
            </tbody>
          </table>
        </div>

        <div class="mt-2 min-h-5 text-xs text-muted-foreground" aria-live="polite">
          {#if hovered}
            {describe(hovered)}
          {:else if canAdjust}
            Click a missed or coming day to excuse it, then another to take in the days between.
          {/if}
        </div>

        <div class="mt-3 flex flex-wrap gap-x-4 gap-y-1.5 text-xs text-muted-foreground">
          {#each [['journal', 'Journaled'], ['excused', 'Excused'], ['frozen', 'Freeze used'], ['missed', 'Missed'], ['future', 'To come']] as [state, label] (state)}
            <span class="flex items-center gap-1.5">
              <span class={['size-3 rounded-sm', STATE_STYLES[state as StreakDay['state']]]}></span>{label}
            </span>
          {/each}
        </div>

        {#if selection}
          <div
            class="sticky bottom-3 mt-4 flex flex-wrap items-center gap-3 rounded-lg border bg-background/95 p-3 shadow-lg backdrop-blur"
          >
            <span class="text-sm">
              <span class="font-medium">{rangeLabel(selection.from, selection.to)}</span>
              <span class="text-muted-foreground">· {plural(selectedDays, 'day')}</span>
            </span>
            {#if selectedDays > streak.rules.max_excuse_days}
              <span class="text-xs text-destructive">At most {streak.rules.max_excuse_days} at a time</span>
            {/if}
            <div class="ml-auto flex gap-2">
              <Button variant="ghost" size="sm" onclick={clear}>Clear</Button>
              <Button
                size="sm"
                disabled={selectedDays > streak.rules.max_excuse_days}
                onclick={() => open('excuse')}>Excuse {plural(selectedDays, 'day')}…</Button
              >
            </div>
          </div>
        {/if}
      </div>
    {/if}

    {#if earlierSami.length}
      <div>
        <h3 class="mb-2 text-sm font-medium">Earlier, on Team Sami</h3>
        <ul class="space-y-1 text-xs text-muted-foreground tabular-nums">
          {#each earlierSami as week (week.start)}
            <li>
              Week of {dayLabel(week.start)}: {OUTCOMES[week.outcome]}, {formatMultiplier(
                week.multiplier_before,
              )} →
              {formatMultiplier(week.multiplier)}, {week.freezes_before} → {plural(week.freezes, 'freeze')}
            </li>
          {/each}
        </ul>
      </div>
    {/if}

    <div>
      <h3 class="mb-3 text-sm font-medium">History</h3>
      <StreakLog adjustments={streak.adjustments} canUndo={canAdjust} />
    </div>
  </Card.Content>
</Card.Root>

<StreakDialog
  bind:open={dialog.open}
  kind={dialog.kind}
  range={dialog.kind === 'excuse' ? selection : null}
  {user}
  {streak}
  onSaved={clear}
/>
