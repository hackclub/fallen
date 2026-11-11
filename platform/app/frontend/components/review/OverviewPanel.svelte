<script lang="ts">
  import Morph from '@/components/admin/Morph.svelte'
  import { openLightbox } from '@/components/review/lightbox.svelte'
  import Key from '@/components/review/Key.svelte'
  import CollapsibleCard from '@/components/review/CollapsibleCard.svelte'
  import PersonChip from '@/components/review/PersonChip.svelte'
  import CheckDetail from '@/components/submission/CheckDetail.svelte'
  import StatusBadge from '@/components/review/StatusBadge.svelte'
  import { formatDate, formatDateTime, formatMinutes, timeAgo } from '@/lib/format'
  import type { ReviewPage } from '@/lib/review.svelte'
  import { money } from '@/lib/submission'

  let {
    page,
    countedMinutes,
    fundedCents,
  }: { page: ReviewPage; countedMinutes: number; fundedCents: number } = $props()

  const s = $derived(page.submission)
  const failed = $derived(s.checks.filter((c) => c.status === 'fail'))
  const warned = $derived(s.checks.filter((c) => c.status === 'warn'))
  const PARTS: Record<string, string> = { pcb: 'PCB', cad: 'CAD', firmware: 'Firmware' }
</script>

<div class="space-y-4 p-4">
  <section class="overflow-hidden rounded-md border border-border">
    <div class="space-y-1.5 p-3">
      <h1 class="text-base leading-snug font-semibold">{page.project.title}</h1>
      {#if page.project.description}
        <p class="text-sm leading-relaxed whitespace-pre-wrap text-muted-foreground">
          {page.project.description}
        </p>
      {/if}
      <div class="flex flex-wrap items-center gap-x-2 gap-y-1 text-xs text-muted-foreground">
        {#each page.project.team as person (person.id)}
          <PersonChip {person} class="text-foreground" />
        {/each}
        <span>|</span>
        <span>Started {formatDate(page.project.created_at)}</span>
        <span>|</span>
        <span title={formatDateTime(s.created_at)}
          >Submitted {timeAgo(s.created_at)} by {s.submitter.name}</span
        >
        {#if s.made_with.length}
          <span>|</span>
          <span class="text-foreground">{s.made_with.map((k) => PARTS[k] ?? k).join(', ')}</span>
        {/if}
      </div>
    </div>
    <div
      class="grid grid-cols-2 divide-x divide-y divide-border border-t border-border sm:grid-cols-4 sm:divide-y-0"
    >
      <div class="px-3 py-2">
        <p class="mb-0.5 text-xs text-muted-foreground">Logged</p>
        <p class="font-mono text-sm">{formatMinutes(page.project.logged_minutes)}</p>
      </div>
      <div class="px-3 py-2">
        <p class="mb-0.5 text-xs text-muted-foreground">Counted</p>
        <p
          class={[
            'font-mono text-sm',
            countedMinutes < page.project.logged_minutes &&
              'font-semibold text-amber-600 dark:text-amber-400',
          ]}
        >
          <Morph text={formatMinutes(countedMinutes)} />
        </p>
      </div>
      <div class="px-3 py-2">
        <p class="mb-0.5 text-xs text-muted-foreground">Journals</p>
        <p class="font-mono text-sm">{page.project.journal_count}</p>
      </div>
      <div class="px-3 py-2">
        <p class="mb-0.5 text-xs text-muted-foreground">Asked for / funding</p>
        <p class="font-mono text-sm">
          {money(s.requested_cents)} <span class="text-muted-foreground">→</span>
          <Morph text={money(fundedCents)} />
        </p>
      </div>
    </div>
    {#if page.project.slack_url}
      <div class="border-t border-border px-3 py-2 text-xs">
        <a
          href={page.project.slack_url}
          target="_blank"
          rel="noopener"
          class="text-blue-600 hover:underline dark:text-blue-400">Slack thread ↗</a
        >
      </div>
    {/if}
  </section>

  {#if s.note}
    <section class="rounded-md border border-sky-200 bg-sky-50 p-3 dark:border-sky-900 dark:bg-sky-950/40">
      <p class="mb-1 text-xs font-medium text-sky-700 dark:text-sky-300">Note from {s.submitter.name}</p>
      <p class="text-sm whitespace-pre-wrap">{s.note}</p>
    </section>
  {/if}

  {#if s.screenshots.length}
    <section class="grid grid-cols-2 gap-2 md:grid-cols-3">
      {#each s.screenshots as shot, i (shot.id)}
        <button
          type="button"
          aria-label="Open screenshot {i + 1}"
          onclick={(event) => {
            const thumbs = [...event.currentTarget.parentElement!.querySelectorAll('img')]
            openLightbox(
              s.screenshots.map((shot, n) => ({
                url: shot.url,
                alt: `Screenshot ${n + 1}`,
                from: thumbs[n],
              })),
              i,
            )
          }}
          class={[
            'block cursor-zoom-in overflow-hidden rounded-md border border-border bg-muted',
            i === 0 && 'col-span-2 row-span-2',
          ]}
        >
          <img
            src={shot.url}
            alt="Screenshot {i + 1}"
            class="aspect-[4/3] h-full w-full object-contain transition-transform duration-300 hover:scale-[1.02]"
          />
        </button>
      {/each}
    </section>
  {/if}

  {#if page.history.length}
    <CollapsibleCard title="Previous reviews" storageKey="history" defaultOpen>
      {#snippet summary()}
        <span class="flex items-center gap-1"
          >{#each page.history as h (h.id)}<StatusBadge status={h.status} />{/each}</span
        >
      {/snippet}
      <div class="divide-y divide-border">
        {#each page.history as h (h.id)}
          <div class="space-y-1.5 p-3">
            <div class="flex flex-wrap items-center justify-between gap-2">
              <span class="flex items-center gap-2">
                <StatusBadge status={h.status} />
                <span class="text-xs text-muted-foreground"
                  >asked {money(h.requested_cents)}{h.approved_cents != null
                    ? `, funded ${money(h.approved_cents)}`
                    : ''}</span
                >
              </span>
              <span class="text-xs text-muted-foreground"
                >{h.reviewer ? `${h.reviewer.name} · ` : ''}{formatDate(h.decided_at ?? h.created_at)}</span
              >
            </div>
            {#if h.feedback}
              <div>
                <p class="mb-0.5 text-xs text-muted-foreground">Feedback</p>
                <p class="text-sm whitespace-pre-wrap">{h.feedback}</p>
              </div>
            {/if}
            {#if h.internal_reason}
              <div>
                <p class="mb-0.5 text-xs text-muted-foreground">Internal reason</p>
                <p class="text-sm whitespace-pre-wrap text-muted-foreground">{h.internal_reason}</p>
              </div>
            {/if}
          </div>
        {/each}
      </div>
    </CollapsibleCard>
  {/if}

  <CollapsibleCard
    title="Checks"
    storageKey="checks"
    defaultOpen
    tone={failed.length ? 'fail' : warned.length ? 'warn' : undefined}
  >
    {#snippet summary()}
      {s.checks.length - failed.length - warned.length} passed{#if warned.length}, {warned.length} warnings{/if}{#if failed.length},
        {failed.length} failed{/if}
    {/snippet}
    <ul class="divide-y divide-border text-sm">
      {#each [...failed, ...warned, ...s.checks.filter((c) => c.status === 'pass')] as check (check.key)}
        <li class="flex items-start gap-2 px-3 py-1.5">
          <span
            class={[
              'mt-1 size-2 shrink-0 rounded-full',
              check.status === 'fail'
                ? 'bg-red-500'
                : check.status === 'warn'
                  ? 'bg-amber-500'
                  : 'bg-emerald-500',
            ]}
          ></span>
          <span class="min-w-0">
            <span class={check.status === 'pass' ? 'text-muted-foreground' : ''}>{check.label}</span>
            {#if check.detail}<span class="block text-xs text-muted-foreground"><CheckDetail {check} /></span
              >{/if}
          </span>
        </li>
      {/each}
    </ul>
  </CollapsibleCard>

  <p class="text-xs text-muted-foreground">
    Tabs: <Key>1</Key> overview, <Key>2</Key> journals, <Key>3</Key> parts, <Key>4</Key> repo. <Key>?</Key> for
    every shortcut.
  </p>
</div>
