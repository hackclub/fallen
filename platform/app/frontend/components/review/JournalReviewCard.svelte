<script lang="ts">
  import { tick } from 'svelte'
  import NumberInput from '@/components/NumberInput.svelte'
  import JournalEvidence from '@/components/review/JournalEvidence.svelte'
  import PersonLink from '@/components/review/PersonLink.svelte'
  import Segmented from '@/components/review/Segmented.svelte'
  import ReasonChips from '@/components/review/ReasonChips.svelte'
  import Morph from '@/components/admin/Morph.svelte'
  import { pop, reveal } from '@/components/review/motion'
  import { formatDateTime, formatMinutes } from '@/lib/format'
  import { countedMinutes, journalDecided, type JournalCall } from '@/lib/review.svelte'
  import type { ReviewJournal } from '@/types'

  // One journal and the call on how much of its time counts: all of it, some of it (with a reason from the fixed
  // list, so reviews stay comparable), or none.
  let {
    journal,
    call = $bindable(),
    reasons,
    index,
    focused,
    readonly,
    onFocus,
  }: {
    journal: ReviewJournal
    call: JournalCall
    reasons: string[]
    index: number
    focused: boolean
    readonly: boolean
    onFocus: () => void
  } = $props()

  const logged = $derived(journal.duration_minutes ?? 0)
  const mode = $derived(call.mode)
  const decided = $derived(journalDecided(journal, call))
  const counted = $derived(countedMinutes(journal, call))
  // What's typed in the two boxes for "part of it", kept as typed so an empty box stays empty while editing.
  // svelte-ignore state_referenced_locally
  let hours = $state(
    call.mode === 'part' && call.minutes != null ? String(Math.floor(call.minutes / 60)) : '',
  )
  // svelte-ignore state_referenced_locally
  let mins = $state(call.mode === 'part' && call.minutes != null ? String(call.minutes % 60) : '')
  let hoursInput: HTMLInputElement | undefined = $state()
  let root: HTMLElement

  const tracked = $derived(journal.tracked_minutes)
  const ai = $derived(journal.fraction_ai)
  const typedMinutes = $derived(
    hours.trim() === '' && mins.trim() === '' ? null : (Number(hours) || 0) * 60 + (Number(mins) || 0),
  )
  const partProblem = $derived(
    mode !== 'part' || typedMinutes == null
      ? null
      : typedMinutes >= logged
        ? `That’s all of it. Pick “All ${journal.duration_text}” instead.`
        : typedMinutes <= 0
          ? 'That’s none of it. Pick “None” instead.'
          : null,
  )
  // Quick picks for "part of it", rounded to 5 minutes, only the ones that are really part.
  const presets = $derived(
    [
      ['¾', 0.75],
      ['½', 0.5],
      ['¼', 0.25],
    ]
      .map(([label, share]) => ({
        label: label as string,
        minutes: Math.round((logged * (share as number)) / 5) * 5,
      }))
      .filter((p) => p.minutes > 0 && p.minutes < logged),
  )

  function setPart(minutes: number | null) {
    hours = minutes == null ? '' : String(Math.floor(minutes / 60))
    mins = minutes == null ? '' : String(minutes % 60)
    call = { ...call, mode: 'part', minutes, carried: false }
  }

  export async function choose(next: 'full' | 'part' | 'none') {
    if (readonly) return
    if (next === 'part') {
      if (mode !== 'part') setPart(null)
      await tick()
      hoursInput?.focus()
      return
    }
    call = {
      ...call,
      mode: next,
      minutes: next === 'full' ? logged : 0,
      reason: next === 'full' ? null : call.reason,
      carried: false,
    }
  }

  export function scrollIntoView() {
    root?.scrollIntoView({ block: 'nearest', behavior: 'smooth' })
  }

  function typed() {
    call = { ...call, mode: 'part', minutes: typedMinutes, carried: false }
  }
</script>

<article
  bind:this={root}
  id="review-{journal.id}"
  onfocusin={onFocus}
  class={[
    'scroll-mt-4 overflow-hidden rounded-lg border bg-card transition-[box-shadow,border-color] duration-200',
    focused
      ? 'border-ring shadow-[0_0_0_3px_color-mix(in_oklch,var(--ring)_25%,transparent)]'
      : 'border-border',
  ]}
>
  <header
    class="flex flex-wrap items-center gap-x-2 gap-y-1 border-b border-border px-3 py-2 text-xs text-muted-foreground"
  >
    <span
      class={[
        'grid size-5 place-items-center rounded-full font-mono text-[10px] font-semibold transition-colors duration-300',
        !decided && 'bg-muted text-muted-foreground',
        decided &&
          mode === 'full' &&
          'bg-emerald-100 text-emerald-700 dark:bg-emerald-950 dark:text-emerald-400',
        decided && mode === 'part' && 'bg-amber-100 text-amber-700 dark:bg-amber-950 dark:text-amber-400',
        decided && mode === 'none' && 'bg-red-100 text-red-700 dark:bg-red-950 dark:text-red-400',
      ]}
      title={decided ? 'Decided' : 'Not decided yet'}>{index + 1}</span
    >
    <PersonLink person={journal.author} avatar class="text-foreground" />
    <span title={formatDateTime(journal.created_at)}
      >{new Date(journal.created_at).toLocaleDateString(undefined, {
        month: 'short',
        day: 'numeric',
        weekday: 'short',
      })}</span
    >
    <span class="rounded bg-muted px-1.5 py-0.5 font-mono text-foreground">{journal.duration_text}</span>
    {#if journal.source === 'transfer'}
      <span
        class="rounded bg-violet-100 px-1.5 py-0.5 text-violet-700 dark:bg-violet-950 dark:text-violet-300"
        >Transferred</span
      >
    {:else if journal.hours_self_claimed}
      <span
        class="rounded bg-amber-100 px-1.5 py-0.5 text-amber-800 dark:bg-amber-950 dark:text-amber-300"
        title="Logged more than the timer and timelapses show"
      >
        Self-claimed{tracked != null ? `, ${formatMinutes(tracked)} tracked` : ''}
      </span>
    {:else if tracked != null}
      <span>{formatMinutes(tracked)} tracked</span>
    {/if}
    {#if ai != null && ai >= 0.2}
      <span
        class={[
          'rounded px-1.5 py-0.5',
          ai >= 0.5
            ? 'bg-red-100 text-red-700 dark:bg-red-950 dark:text-red-300'
            : 'bg-zinc-100 text-zinc-600 dark:bg-zinc-800 dark:text-zinc-300',
        ]}
      >
        {Math.round(ai * 100)}% AI
      </span>
    {/if}
    {#if journal.slack_url}
      <a
        href={journal.slack_url}
        target="_blank"
        rel="noopener"
        class="ml-auto hover:text-foreground hover:underline">Slack ↗</a
      >
    {/if}
  </header>

  <div class="space-y-3 px-3 py-3">
    <JournalEvidence {journal} />
  </div>

  <footer class="border-t border-border bg-muted/30 px-3 py-3">
    {#if call.carried}
      <p transition:reveal class="pb-3 text-xs text-sky-700 dark:text-sky-300">
        The last review counted {formatMinutes(counted ?? 0)}{call.reason
          ? ` (${call.reason.toLowerCase()})`
          : ''}. Pick it again to keep it, or change it.
      </p>
    {/if}

    <div class="flex flex-wrap items-center gap-x-3 gap-y-2">
      <span class="w-24 shrink-0 text-xs text-muted-foreground">Counts</span>
      <Segmented
        label="How much of this journal counts"
        value={mode}
        disabled={readonly}
        onChange={(value) => choose(value)}
        options={[
          { value: 'full', label: `All ${journal.duration_text}`, tint: 'green', title: 'All of it (A)' },
          { value: 'part', label: 'Deflate', tint: 'amber', title: 'Deflate (R)' },
          { value: 'none', label: 'None', tint: 'red', title: 'None (X)' },
        ]}
      />
      {#if decided && mode !== 'full'}
        <span transition:pop class="text-xs text-muted-foreground">
          takes off <span class="font-mono text-foreground"
            ><Morph text={formatMinutes(logged - (counted ?? 0))} /></span
          >
        </span>
      {/if}
    </div>

    {#if mode === 'part'}
      <div transition:reveal>
        <div class="flex flex-wrap items-center gap-x-3 gap-y-2 pt-3">
          <span class="w-24 shrink-0 text-xs text-muted-foreground">Time</span>
          <div
            class={[
              'flex h-8 items-center rounded-md border bg-background pr-2 font-mono text-sm transition-[border-color,box-shadow] duration-200 focus-within:border-ring focus-within:ring-[3px] focus-within:ring-ring/50',
              partProblem ? 'border-amber-400' : 'border-input',
            ]}
          >
            <NumberInput
              bind:ref={hoursInput}
              bind:value={hours}
              onchange={typed}
              decimals={0}
              max={Math.floor(logged / 60)}
              disabled={readonly}
              label="Hours that count"
              placeholder="0"
              align="right"
              class="h-full w-9 px-2"
            />
            <span class="text-muted-foreground">h</span>
            <NumberInput
              bind:value={mins}
              onchange={typed}
              decimals={0}
              max={59}
              disabled={readonly}
              label="Minutes that count"
              placeholder="00"
              align="right"
              class="h-full w-9 px-2"
            />
            <span class="text-muted-foreground">m</span>
          </div>
          <span class="text-xs text-muted-foreground">of {journal.duration_text}</span>
          {#if !readonly}
            <div class="flex gap-1">
              {#each presets as preset (preset.label)}
                <button
                  type="button"
                  onclick={() => setPart(preset.minutes)}
                  class={[
                    'rounded-full px-2 py-0.5 text-xs transition-all duration-200',
                    counted === preset.minutes
                      ? 'bg-card font-semibold text-foreground shadow-[var(--rc-shadow-raise)]'
                      : 'text-muted-foreground hover:bg-muted hover:text-foreground',
                  ]}>{preset.label} · {formatMinutes(preset.minutes)}</button
                >
              {/each}
            </div>
          {/if}
        </div>
        {#if partProblem}<p
            transition:reveal
            class="pt-1.5 pl-[108px] text-xs text-amber-700 dark:text-amber-400"
          >
            {partProblem}
          </p>{/if}
      </div>
    {/if}

    {#if mode === 'part' || mode === 'none'}
      <div transition:reveal>
        <div class="flex flex-wrap items-start gap-x-3 gap-y-2 pt-3">
          <span class="w-24 shrink-0 pt-0.5 text-xs text-muted-foreground">Why</span>
          <ReasonChips
            {reasons}
            value={call.reason}
            label="Why it counts less"
            disabled={readonly}
            onChange={(reason) => (call = { ...call, reason, carried: false })}
          />
        </div>
        {#if call.reason}
          <div transition:reveal>
            <div class="flex items-center gap-3 pt-3">
              <span class="w-24 shrink-0 text-xs text-muted-foreground">Justification</span>
              <input
                bind:value={call.note}
                disabled={readonly}
                maxlength="1000"
                placeholder="Optional"
                class="h-8 min-w-0 flex-1 rounded-md border border-input bg-background px-2.5 text-xs transition-colors"
              />
            </div>
          </div>
        {/if}
      </div>
    {/if}
  </footer>
</article>
