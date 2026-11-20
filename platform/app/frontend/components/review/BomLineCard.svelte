<script lang="ts">
  import Morph from '@/components/admin/Morph.svelte'
  import NumberInput from '@/components/NumberInput.svelte'
  import ReasonChips from '@/components/review/ReasonChips.svelte'
  import Segmented from '@/components/review/Segmented.svelte'
  import { animate } from 'motion'
  import { prefersReducedMotion } from '@/components/dialog/motion'
  import { reveal } from '@/components/review/motion'
  import {
    itemDecided,
    itemFunded,
    itemRequested,
    type ItemCall,
    type ItemVerdict,
  } from '@/lib/review.svelte'
  import { fromCents, money, toCents } from '@/lib/submission'
  import type { BomItem } from '@/types'

  // One line of the parts list and the call on it. Everything about the part is on the left and the call on the
  // right, both at fixed widths, so choosing never moves anything; lowering or cutting opens a row underneath for
  // how much and why.
  let {
    item,
    call = $bindable(),
    index,
    focused,
    readonly,
    cutReasons,
    lowerReasons,
    onFocus,
  }: {
    item: BomItem
    call: ItemCall
    index: number
    focused: boolean
    readonly: boolean
    cutReasons: string[]
    lowerReasons: string[]
    onFocus: () => void
  } = $props()

  // Boards the funding docs ask people to design rather than buy (SubmissionChecks::READY_MADE).
  const READY_MADE =
    /\b(?:dev\s*(?:board|kit)|development\s*board|arduino|esp32[-\s]?(?:devkit|wroom[-\s]?devkit|c3[-\s]?super\s*mini)|nodemcu|wemos|d1\s*mini|raspberry\s*pi\s*pico|pico\s*w?\b|feather|xiao|breakout|module)\b/i

  const asked = $derived(itemRequested(item))
  const funded = $derived(itemFunded(item, call))
  const decided = $derived(itemDecided(item, call))
  const link = $derived(item.link && /^https?:\/\//i.test(item.link) ? item.link : null)
  const host = $derived.by(() => {
    try {
      return link ? new URL(link).hostname.replace(/^www\./, '') : null
    } catch {
      return null
    }
  })
  const flags = $derived(
    [
      item.kind === 'part' && !item.owned && !link && 'No link',
      item.kind === 'part' && READY_MADE.test(item.name) && 'Looks ready-made',
    ].filter((flag): flag is string => !!flag),
  )
  const lowerProblem = $derived(
    call.verdict !== 'adjusted' || call.cents == null
      ? null
      : call.cents >= asked
        ? `That’s all of it. Pick “Approve” instead.`
        : call.cents <= 0
          ? 'That’s nothing. Pick “Cut” instead.'
          : null,
  )
  // Quick amounts for lowering: fewer of the part, or half.
  const picks = $derived.by(() => {
    const out: { label: string; cents: number }[] = []
    if (item.kind === 'part' && item.quantity > 1 && item.unit_cents) {
      for (const n of [item.quantity - 1, Math.ceil(item.quantity / 2), 1]) {
        if (n > 0 && n < item.quantity && !out.some((p) => p.label === `${n} of ${item.quantity}`))
          out.push({ label: `${n} of ${item.quantity}`, cents: n * item.unit_cents })
      }
    }
    if (out.length < 2 && asked > 1) out.push({ label: '½', cents: Math.round(asked / 2) })
    return out.filter((p) => p.cents > 0 && p.cents < asked).slice(0, 3)
  })

  // The asked amount, struck through under the funding while a line funds less than it asks. Its space is always
  // kept, so it fades in and out on a spring without the card changing height.
  // The amount is centred in the card; while the struck price shows under it, both rise by half its height so the
  // pair stays centred.
  const lowered = $derived(funded != null && funded < asked)
  let was: HTMLElement
  let fundsBox: HTMLElement
  $effect(() => {
    const on = lowered
    const spring = prefersReducedMotion()
      ? { duration: 0 }
      : ({ type: 'spring', stiffness: 520, damping: 34 } as const)
    animate(was, { opacity: on ? 1 : 0, y: on ? 0 : -4 }, spring)
    animate(fundsBox, { y: on ? -was.offsetHeight / 2 : 0 }, spring)
  })

  let root: HTMLElement
  let amount: HTMLInputElement | undefined = $state()

  export function choose(verdict: ItemVerdict) {
    if (readonly || item.owned) return
    call = {
      verdict,
      reason: verdict === 'approved' ? null : call.verdict === verdict ? call.reason : null,
      cents: verdict === 'adjusted' ? (call.verdict === 'adjusted' ? call.cents : null) : null,
    }
    if (verdict === 'adjusted') requestAnimationFrame(() => amount?.focus())
  }

  export function scrollIntoView() {
    root?.scrollIntoView({ block: 'nearest', behavior: 'smooth' })
  }
</script>

<article
  bind:this={root}
  onfocusin={onFocus}
  class={[
    'scroll-mt-28 overflow-hidden rounded-lg border bg-card transition-[box-shadow,border-color] duration-200',
    focused
      ? 'border-ring shadow-[0_0_0_3px_color-mix(in_oklch,var(--ring)_25%,transparent)]'
      : 'border-border',
  ]}
>
  <div class="flex items-start gap-3 px-3 py-3">
    <span
      class={[
        'mt-0.5 grid size-5 shrink-0 place-items-center rounded-full font-mono text-[10px] font-semibold transition-colors duration-300',
        (!decided || item.owned) && 'bg-muted text-muted-foreground',
        decided &&
          call.verdict === 'approved' &&
          'bg-emerald-100 text-emerald-700 dark:bg-emerald-950 dark:text-emerald-400',
        decided &&
          call.verdict === 'adjusted' &&
          'bg-amber-100 text-amber-700 dark:bg-amber-950 dark:text-amber-400',
        decided && call.verdict === 'cut' && 'bg-red-100 text-red-700 dark:bg-red-950 dark:text-red-400',
      ]}>{index + 1}</span
    >

    <div class="min-w-0 flex-1">
      <div class="flex flex-wrap items-center gap-x-2 gap-y-1">
        <span class="font-medium">{item.name}</span>
        {#if item.kind !== 'part'}
          <span class="rounded bg-muted px-1.5 py-0.5 text-[10px] font-medium text-muted-foreground uppercase"
            >{item.kind}</span
          >
        {/if}
        {#if item.owned}
          <span class="rounded bg-muted px-1.5 py-0.5 text-[10px] font-medium text-muted-foreground"
            >Already owned</span
          >
        {/if}
        {#each flags as flag (flag)}
          <span
            class="rounded bg-amber-100 px-1.5 py-0.5 text-[10px] font-medium text-amber-800 dark:bg-amber-950 dark:text-amber-300"
            >{flag}</span
          >
        {/each}
      </div>
      {#if item.purpose}<p class="mt-0.5 text-sm text-muted-foreground">{item.purpose}</p>{/if}
      <p class="mt-1 flex flex-wrap items-center gap-x-3 gap-y-0.5 text-xs text-muted-foreground">
        {#if item.kind === 'part'}
          <span class="font-mono">
            {item.quantity} × {item.unit_cents != null ? money(item.unit_cents) : '?'} = {money(
              item.total_cents,
            )}
          </span>
        {/if}
        {#if link}
          <a
            href={link}
            target="_blank"
            rel="noopener noreferrer"
            class="text-blue-600 hover:underline dark:text-blue-400">{host} ↗</a
          >
        {/if}
        {#if item.vendor}<span>{item.vendor}</span>{/if}
      </p>
    </div>

    <div class="flex shrink-0 items-center gap-4 self-center">
      {#if item.owned}
        <span class="w-[13.5rem] text-right text-xs text-muted-foreground">Asks for nothing</span>
      {:else}
        <div class="flex w-[13.5rem] justify-end">
          <Segmented
            label="Decision on {item.name}"
            value={call.verdict}
            disabled={readonly}
            onChange={choose}
            options={[
              { value: 'approved', label: 'Approve', tint: 'green', title: 'Fund it as asked (A)' },
              { value: 'adjusted', label: 'Lower', tint: 'amber', title: 'Fund less (L)' },
              { value: 'cut', label: 'Cut', tint: 'red', title: 'Fund none of it (X)' },
            ]}
          />
        </div>
      {/if}
      <div bind:this={fundsBox} class="relative w-24 text-right">
        <p class="text-[10px] tracking-wide text-muted-foreground uppercase">Funds</p>
        <p class={['font-mono text-sm', funded == null ? 'text-muted-foreground' : 'font-semibold']}>
          {#if funded == null}
            {money(asked)}?
          {:else}
            <Morph text={money(funded)} />
          {/if}
        </p>
        <!-- Under the amount but out of the layout, so the card never changes height. -->
        <p
          bind:this={was}
          aria-hidden={!lowered}
          class="absolute top-full right-0 font-mono text-[11px] text-muted-foreground line-through"
          style:opacity={0}
        >
          {money(asked)}
        </p>
      </div>
    </div>
  </div>

  {#if call.carried && !readonly}
    <p transition:reveal class="px-3 pb-2 text-xs text-sky-700 dark:text-sky-300">
      The last review {call.verdict === 'approved'
        ? 'approved this'
        : call.verdict === 'cut'
          ? 'cut this'
          : `lowered this${call.cents != null ? ` to ${money(call.cents)}` : ''}`}{call.reason
        ? ` (${call.reason.toLowerCase()})`
        : ''}. Pick it again to keep it, or change it.
    </p>
  {/if}

  {#if call.verdict === 'adjusted' || call.verdict === 'cut'}
    <div transition:reveal>
      <div class="space-y-3 border-t border-border bg-muted/30 px-3 py-3 pl-11">
        {#if call.verdict === 'adjusted'}
          <div class="flex flex-wrap items-center gap-x-3 gap-y-2">
            <span class="w-14 shrink-0 text-xs text-muted-foreground">Fund</span>
            <div
              class="flex h-8 items-center rounded-md border border-input bg-background pl-2.5 font-mono text-sm transition-[border-color,box-shadow] duration-200 focus-within:border-ring focus-within:ring-[3px] focus-within:ring-ring/50"
            >
              <span class="text-muted-foreground">$</span>
              <NumberInput
                bind:ref={amount}
                value={fromCents(call.cents)}
                onchange={(value) => (call = { ...call, cents: toCents(value) })}
                max={asked / 100}
                separators
                disabled={readonly}
                label="Amount to fund"
                placeholder="0.00"
                class="h-full w-20 pr-2.5 pl-1"
              />
            </div>
            <span class="text-xs text-muted-foreground">of {money(asked)}</span>
            {#if !readonly}
              <div class="flex gap-1">
                {#each picks as pick (pick.label)}
                  <button
                    type="button"
                    onclick={() => (call = { ...call, cents: pick.cents })}
                    class={[
                      'rounded-full px-2 py-0.5 text-xs transition-all duration-200',
                      call.cents === pick.cents
                        ? 'bg-card font-semibold text-foreground shadow-[var(--rc-shadow-raise)]'
                        : 'text-muted-foreground hover:bg-muted hover:text-foreground',
                    ]}>{pick.label} · {money(pick.cents)}</button
                  >
                {/each}
              </div>
            {/if}
          </div>
          {#if lowerProblem}
            <p transition:reveal class="pl-[68px] text-xs text-amber-700 dark:text-amber-400">
              {lowerProblem}
            </p>
          {/if}
        {/if}
        <div class="flex flex-wrap items-start gap-x-3 gap-y-2">
          <span class="w-14 shrink-0 pt-0.5 text-xs text-muted-foreground">Why</span>
          <ReasonChips
            reasons={call.verdict === 'cut' ? cutReasons : lowerReasons}
            value={call.reason}
            label="Why"
            disabled={readonly}
            onChange={(reason) => (call = { ...call, reason })}
          />
        </div>
      </div>
    </div>
  {/if}
</article>
