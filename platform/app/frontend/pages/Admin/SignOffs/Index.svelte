<script lang="ts" module>
  export { default as layout } from '@/layouts/AdminLayout.svelte'
</script>

<script lang="ts">
  import ClipboardCheck from '@lucide/svelte/icons/clipboard-check'
  import EmptyState from '@/components/admin/EmptyState.svelte'
  import { Button } from '@/components/admin/ui/button'
  import * as Card from '@/components/admin/ui/card'
  import Deferred from '@/components/Deferred.svelte'
  import Link from '@/components/Link.svelte'
  import PersonChip from '@/components/review/PersonChip.svelte'
  import { formatDate, formatMinutes, timeAgo } from '@/lib/format'
  import { money } from '@/lib/submission'
  import { router } from '@inertiajs/svelte'
  import Play from '@lucide/svelte/icons/play'
  import { adminSignOffs, reviewNextSignOff, reviewSubmission } from '@/routes'
  import type { AdminSignOff, Pagy } from '@/types'

  // Design reviewers' decisions, held until an admin signs them off (SubmissionReview#propose).
  let {
    submissions,
    pagy,
    questions,
  }: { submissions?: AdminSignOff[]; pagy?: Pagy; questions: Record<string, string> } = $props()

  const VERDICTS = {
    approved: {
      label: 'Approve',
      class: 'bg-emerald-100 text-emerald-800 dark:bg-emerald-950 dark:text-emerald-300',
    },
    returned: { label: 'Return', class: 'bg-amber-100 text-amber-800 dark:bg-amber-950 dark:text-amber-300' },
    rejected: {
      label: 'Reject for good',
      class: 'bg-red-100 text-red-800 dark:bg-red-950 dark:text-red-300',
    },
  } as const

  let busy = $state<string | null>(null)

  function signOff(s: AdminSignOff) {
    const what =
      s.verdict === 'approved'
        ? `approve it and send ${money(s.requested_cents)}`
        : s.verdict === 'returned'
          ? 'return it to them'
          : 'reject it for good'
    if (!confirm(`Sign off ${s.project_title}: ${what}? It goes out straight away.`)) return
    busy = s.id
    router.patch(
      adminSignOffs.update(s.id).url,
      { proposed_at: s.proposed_at },
      { preserveScroll: true, onFinish: () => (busy = null) },
    )
  }

  function sendBack(s: AdminSignOff) {
    if (!confirm(`Send ${s.project_title} back to the queue without signing off? Nothing is applied.`)) return
    busy = s.id
    router.delete(adminSignOffs.destroy(s.id).url, { preserveScroll: true, onFinish: () => (busy = null) })
  }

  const page = (n: number) =>
    router.get(adminSignOffs.index({ query: { page: n } }).url, {}, { preserveScroll: true })
  const deflated = (s: AdminSignOff) => s.journals.filter((j) => j.counted_minutes < j.logged_minutes)
</script>

<svelte:head><title>Sign-offs · Fallen Admin</title></svelte:head>

<div class="mb-5 flex flex-wrap items-start justify-between gap-3">
  <div>
    <h1 class="text-2xl font-semibold tracking-tight">Sign-offs</h1>
    <p class="text-sm text-muted-foreground">
      Design reviewers’ decisions wait here. Nothing reaches the person, and no hours, XP or funding change,
      until you sign one off. Sign one off as it is here, or start signing off to go through them on the
      review page, changing what needs it: it still goes out as the reviewer’s review, with a note of what you
      changed. Sending one back puts the project back in the queue.
    </p>
  </div>
  <Button href={reviewNextSignOff().url}><Play data-icon="inline-start" /> Start signing off</Button>
</div>

<Deferred data={['submissions', 'pagy']}>
  {#snippet fallback()}<div class="h-40 animate-pulse rounded-lg bg-muted"></div>{/snippet}
  {#if submissions?.length}
    <div class="space-y-4">
      {#each submissions as s (s.id)}
        {@const verdict = VERDICTS[s.verdict]}
        <Card.Root>
          <Card.Header class="gap-2">
            <div class="flex flex-wrap items-center gap-2">
              <span class={['rounded px-2 py-0.5 text-xs font-semibold', verdict.class]}>{verdict.label}</span
              >
              {#if s.ai}
                <span
                  class="rounded bg-red-100 px-2 py-0.5 text-xs text-red-800 dark:bg-red-950 dark:text-red-300"
                  >AI-generated journals</span
                >
              {/if}
              <Card.Title class="text-base">
                <Link href={reviewSubmission(s.id).url} class="hover:underline">{s.project_title}</Link>
              </Card.Title>
              <span class="text-sm text-muted-foreground">by</span>
              <PersonChip person={s.submitter} />
            </div>
            <Card.Description class="flex flex-wrap items-center gap-x-1.5 gap-y-1">
              Decided by
              {#if s.proposed_by}<PersonChip person={s.proposed_by} />{/if}
              {s.proposed_at ? timeAgo(s.proposed_at) : ''}, submitted {formatDate(s.created_at)}
            </Card.Description>
          </Card.Header>

          <Card.Content class="space-y-4 text-sm">
            <div class="flex flex-wrap gap-x-8 gap-y-2">
              <div>
                <p class="text-xs text-muted-foreground">Time that counts</p>
                <p class="font-mono">
                  {formatMinutes(s.logged_minutes)} →
                  <span class="font-semibold">{formatMinutes(s.counted_minutes)}</span>
                </p>
              </div>
              <div>
                <p class="text-xs text-muted-foreground">Funding</p>
                <p class="font-mono">
                  {s.verdict === 'approved' ? money(s.requested_cents) : '$0'}
                  <span class="text-muted-foreground">of {money(s.requested_cents)} asked</span>
                </p>
              </div>
            </div>

            {#if deflated(s).length}
              <div>
                <p class="mb-1 text-xs text-muted-foreground">
                  Deflated journals ({deflated(s).length} of {s.journals.length})
                </p>
                <ul class="space-y-1.5">
                  {#each deflated(s) as j (j.id)}
                    <li class="rounded-md border border-border px-3 py-2">
                      <p class="flex flex-wrap gap-x-3 text-xs">
                        <span class="text-muted-foreground">{formatDate(j.created_at)}</span>
                        <span class="font-mono"
                          >{formatMinutes(j.logged_minutes)} →
                          <span class="font-semibold">{formatMinutes(j.counted_minutes)}</span></span
                        >
                        {#if j.reason}<span class="text-amber-700 dark:text-amber-400">{j.reason}</span>{/if}
                      </p>
                      {#if j.note}<p class="mt-0.5 text-xs">{j.note}</p>{/if}
                      <p class="mt-0.5 text-xs text-muted-foreground">{j.excerpt}</p>
                    </li>
                  {/each}
                </ul>
              </div>
            {:else}
              <p class="text-xs text-muted-foreground">Every journal counts in full ({s.journals.length}).</p>
            {/if}

            {#if Object.keys(s.rubric).length}
              <div>
                <p class="mb-1 text-xs text-muted-foreground">Rubric</p>
                <ul class="grid gap-x-6 gap-y-0.5 sm:grid-cols-2">
                  {#each Object.entries(questions) as [key, question] (key)}
                    <li class="flex justify-between gap-3 text-xs">
                      <span>{question}</span>
                      <span
                        class={[
                          'font-medium',
                          s.rubric[key] === 'yes'
                            ? 'text-emerald-700 dark:text-emerald-400'
                            : s.rubric[key] === 'no'
                              ? 'text-red-700 dark:text-red-400'
                              : 'text-amber-700 dark:text-amber-400',
                        ]}>{s.rubric[key] ?? '–'}</span
                      >
                    </li>
                  {/each}
                </ul>
              </div>
            {/if}

            <div class="grid gap-3 sm:grid-cols-2">
              <div>
                <p class="mb-1 text-xs text-muted-foreground">Internal reason</p>
                <p class="whitespace-pre-wrap">{s.internal_reason ?? '–'}</p>
              </div>
              <div>
                <p class="mb-1 text-xs text-muted-foreground">Feedback (sent to them)</p>
                <p class="whitespace-pre-wrap">{s.feedback ?? '–'}</p>
              </div>
            </div>

            <div class="flex flex-wrap gap-2 border-t border-border pt-4">
              <Button size="sm" disabled={busy === s.id} onclick={() => signOff(s)}>Sign off & send</Button>
              <Button size="sm" variant="outline" disabled={busy === s.id} onclick={() => sendBack(s)}
                >Send back to the queue</Button
              >
              <Button size="sm" variant="outline" href={reviewSubmission(s.id).url}
                >Edit, then sign off</Button
              >
            </div>
          </Card.Content>
        </Card.Root>
      {/each}
    </div>
    {#if pagy && pagy.pages > 1}
      <div class="flex items-center justify-between pt-4 text-sm text-muted-foreground">
        <span>{pagy.count} waiting</span>
        <div class="flex items-center gap-2">
          <Button
            variant="outline"
            size="sm"
            disabled={!pagy.prev}
            onclick={() => pagy.prev && page(pagy.prev)}>Previous</Button
          >
          <span class="tabular-nums">{pagy.page} / {pagy.pages}</span>
          <Button
            variant="outline"
            size="sm"
            disabled={!pagy.next}
            onclick={() => pagy.next && page(pagy.next)}>Next</Button
          >
        </div>
      </div>
    {/if}
  {:else}
    <EmptyState
      icon={ClipboardCheck}
      title="Nothing to sign off"
      description="When a design reviewer decides a project, it waits here for you."
    />
  {/if}
</Deferred>
