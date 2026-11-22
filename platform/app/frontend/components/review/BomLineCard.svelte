<script lang="ts">
  import { itemRequested } from '@/lib/review.svelte'
  import { money } from '@/lib/submission'
  import type { BomItem } from '@/types'

  // One line of the parts list, to read: the part, where it's from, and what it asks for. Flags point at lines worth
  // a closer look. A line an older review lowered or cut shows what it funded instead.
  let {
    item,
    index,
    focused,
    onFocus,
  }: {
    item: BomItem
    index: number
    focused: boolean
    onFocus: () => void
  } = $props()

  // Boards the funding docs ask people to design rather than buy (SubmissionChecks::READY_MADE).
  const READY_MADE =
    /\b(?:dev\s*(?:board|kit)|development\s*board|arduino|esp32[-\s]?(?:devkit|wroom[-\s]?devkit|c3[-\s]?super\s*mini)|nodemcu|wemos|d1\s*mini|raspberry\s*pi\s*pico|pico\s*w?\b|feather|xiao|breakout|module)\b/i

  const asked = $derived(itemRequested(item))
  const lowered = $derived(item.funded_cents != null && item.funded_cents < asked)
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

  let root: HTMLElement

  export function scrollIntoView() {
    root?.scrollIntoView({ block: 'nearest', behavior: 'smooth' })
  }
</script>

<article
  bind:this={root}
  tabindex="-1"
  onfocusin={onFocus}
  class={[
    'scroll-mt-28 overflow-hidden rounded-lg border bg-card transition-[box-shadow,border-color] duration-200 outline-none',
    focused
      ? 'border-ring shadow-[0_0_0_3px_color-mix(in_oklch,var(--ring)_25%,transparent)]'
      : 'border-border',
  ]}
>
  <div class="flex items-start gap-3 px-3 py-3">
    <span
      class="mt-0.5 grid size-5 shrink-0 place-items-center rounded-full bg-muted font-mono text-[10px] font-semibold text-muted-foreground"
      >{index + 1}</span
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

    <div class="w-24 shrink-0 self-center text-right">
      {#if item.owned}
        <p class="text-xs text-muted-foreground">Asks for nothing</p>
      {:else if lowered}
        <p class="font-mono text-sm font-semibold">{money(item.funded_cents ?? 0)}</p>
        <p class="font-mono text-[11px] text-muted-foreground line-through">{money(asked)}</p>
      {:else}
        <p class="font-mono text-sm font-semibold">{money(asked)}</p>
      {/if}
    </div>
  </div>

  {#if lowered && item.reason}
    <p class="px-3 pb-2 pl-11 text-xs text-muted-foreground">
      {item.verdict === 'cut' ? 'Cut' : 'Lowered'}: {item.reason}
    </p>
  {/if}
</article>
