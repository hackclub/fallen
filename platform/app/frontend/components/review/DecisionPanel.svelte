<script lang="ts">
  import Check from '@lucide/svelte/icons/check'
  import CornerDownLeft from '@lucide/svelte/icons/corner-down-left'
  import Loader from '@lucide/svelte/icons/loader'
  import * as AlertDialog from '@/components/admin/ui/alert-dialog'
  import { Button } from '@/components/admin/ui/button'
  import { Separator } from '@/components/admin/ui/separator'
  import Segmented from '@/components/review/Segmented.svelte'
  import Morph from '@/components/admin/Morph.svelte'
  import { appear, reveal } from '@/components/review/motion'
  import Key from '@/components/review/Key.svelte'
  import { Textarea } from '@/components/admin/ui/textarea'
  import StatusBadge from '@/components/review/StatusBadge.svelte'
  import { router } from '@inertiajs/svelte'
  import { formatDateTime, formatMinutes, timeAgo } from '@/lib/format'
  import { takeOverReviewSubmission } from '@/routes'
  import {
    RAISED,
    RAISED_KEY,
    itemDecided,
    journalDecided,
    journalNeedsReason,
    type Answer,
    type ReviewDraft,
    type ReviewPage,
    type Verdict,
  } from '@/lib/review.svelte'
  import { money } from '@/lib/submission'
  import PersonLink from '@/components/review/PersonLink.svelte'

  let {
    page,
    draft = $bindable(),
    countedMinutes,
    fundedCents,
    submitting,
    pending,
    errors,
    onDecide,
    feedbackRef = $bindable(),
    internalRef = $bindable(),
  }: {
    page: ReviewPage
    draft: ReviewDraft
    countedMinutes: number
    fundedCents: number
    submitting: boolean
    pending: Verdict | null
    errors: Record<string, string>
    onDecide: (verdict: Verdict) => void
    feedbackRef?: HTMLTextAreaElement | null
    internalRef?: HTMLTextAreaElement | null
  } = $props()

  const mod = typeof navigator !== 'undefined' && /Mac|iPhone|iPad/.test(navigator.platform) ? '⌘' : 'Ctrl+'
  const s = $derived(page.submission)
  const decided = $derived(s.status !== 'pending')
  const questions = $derived(Object.entries(page.options.rubric))
  const answered = $derived(questions.every(([key]) => draft.rubric[key]))
  const journalsLeft = $derived(page.journals.filter((j) => !journalDecided(j, draft.journals[j.id])).length)
  const journalReasonsMissing = $derived(page.journals.some((j) => journalNeedsReason(draft.journals[j.id])))
  const itemsLeft = $derived(s.bom_items.filter((i) => !itemDecided(i, draft.bom[i.id])).length)
  const itemReasonsMissing = $derived(
    s.bom_items.some((i) => {
      const call = draft.bom[i.id]
      return !i.owned && (call?.verdict === 'cut' || call?.verdict === 'adjusted') && !call.reason
    }),
  )

  const common = $derived(
    !answered
      ? 'Answer every question'
      : journalsLeft
        ? `Decide the ${journalsLeft} journal${journalsLeft === 1 ? '' : 's'} left`
        : journalReasonsMissing
          ? 'Give a reason for every journal you deflate'
          : !draft.internal.trim()
            ? 'Write the internal reason'
            : null,
  )
  const approveBlocker = $derived(
    common ??
      (itemsLeft
        ? `Decide the ${itemsLeft} part${itemsLeft === 1 ? '' : 's'} left`
        : itemReasonsMissing
          ? 'Give a reason for every part you cut or lower'
          : null),
  )
  const returnBlocker = $derived(
    common ?? (!draft.feedback.trim() ? 'Write feedback so they know what to change' : null),
  )

  export const blockers = () => ({ approve: approveBlocker, return: returnBlocker })
</script>

{#snippet label(text: string, hint: string, key?: string, forId?: string)}
  <label for={forId} class="flex items-center gap-1.5 text-xs text-muted-foreground">
    {text} <span class="text-muted-foreground/60">({hint})</span>
    {#if key}<Key>{key}</Key>{/if}
  </label>
{/snippet}

{#snippet stat(title: string, value: string, of: string, left: number, noun: string)}
  <div class="space-y-1.5">
    <p class="text-xs text-muted-foreground">{title}</p>
    <div class="flex items-center gap-2 text-sm">
      <span class="font-mono whitespace-nowrap text-muted-foreground"><Morph text={of} /></span>
      <span class="text-muted-foreground">→</span>
      <span
        class={[
          'font-mono whitespace-nowrap',
          value !== of ? 'font-semibold text-foreground' : 'text-muted-foreground',
        ]}><Morph text={value} /></span
      >
      {#if !decided && left}
        <span
          transition:appear
          class="ml-auto rounded-full bg-amber-100 px-1.5 py-0.5 text-[10px] font-medium text-amber-700 dark:bg-amber-950 dark:text-amber-400"
          ><Morph text={left} /> {left === 1 ? noun.replace(/s$/, '') : noun} left</span
        >
      {/if}
    </div>
  </div>
{/snippet}

<div class="space-y-4 p-4">
  {#if decided}
    <div class="space-y-2">
      <h3 class="text-xs font-semibold tracking-wide text-muted-foreground uppercase">Review Complete</h3>
      <StatusBadge status={s.status} class="text-xs" />
      {#if s.reviewer}<p class="text-xs text-muted-foreground">
          by <PersonLink person={s.reviewer} />, {formatDateTime(s.decided_at)}
        </p>{/if}
    </div>
  {:else}
    <h3 class="text-xs font-semibold tracking-wide text-muted-foreground uppercase">Submit Review</h3>
    {#if s.flagged_at}
      <div
        class="rounded-md border border-red-200 bg-red-50 px-2.5 py-2 text-sm dark:border-red-900 dark:bg-red-950/40"
      >
        <p class="text-xs font-medium text-red-700 dark:text-red-400">Flagged for fraud</p>
        <p class="mt-0.5 whitespace-pre-wrap">{s.flag_reason}</p>
      </div>
    {:else if !page.can.decide}
      {@const holder =
        s.claimed_by && s.claim_expires_at && new Date(s.claim_expires_at) > new Date() ? s.claimed_by : null}
      <div class="rounded-md border border-border bg-muted/40 p-3 text-sm">
        {#if holder}
          <div class="flex items-center gap-2.5">
            <img
              src={holder.avatar}
              alt=""
              width="28"
              height="28"
              class="size-7 shrink-0 rounded-full bg-muted object-cover"
            />
            <div class="min-w-0">
              <p class="font-medium"><PersonLink person={holder} /> has this open</p>
              <p class="text-xs text-muted-foreground">
                Their hold ends {timeAgo(s.claim_expires_at!)} unless they keep working.
              </p>
            </div>
          </div>
          <p class="mt-2 text-xs text-muted-foreground">
            You can read along. If they’ve stepped away, take it over and their page stops.
          </p>
          {#if page.can.take_over}
            <Button
              size="sm"
              class="mt-2.5 w-full {RAISED.plain}"
              onclick={() =>
                router.post(
                  takeOverReviewSubmission(s.id, { query: page.skip ? { skip: page.skip } : {} }).url,
                )}
            >
              Take it over
            </Button>
          {/if}
        {:else}
          <p class="text-muted-foreground">You can read this, but not review it.</p>
        {/if}
      </div>
    {/if}
  {/if}

  <div class="space-y-2">
    {@render label(
      'Internal Reason',
      'not shown to user',
      decided ? undefined : `${mod}J`,
      'internal-reason',
    )}
    {#if decided}
      <p class="text-sm whitespace-pre-wrap">{draft.internal}</p>
    {:else}
      <Textarea
        id="internal-reason"
        bind:ref={internalRef}
        bind:value={draft.internal}
        readonly={!page.can.decide}
        placeholder="Justify your decision..."
        class="h-20 resize-y text-sm"
      />
    {/if}
    {#if errors.internal_reason}<p class="text-xs text-red-600">{errors.internal_reason}</p>{/if}
  </div>

  <div class="space-y-2">
    {@render label('Feedback', 'shown to user', decided ? undefined : `${mod}F`, 'feedback')}
    {#if decided}
      <p class="text-sm whitespace-pre-wrap">{draft.feedback || 'None'}</p>
    {:else}
      <Textarea
        id="feedback"
        bind:ref={feedbackRef}
        bind:value={draft.feedback}
        readonly={!page.can.decide}
        placeholder="What they did well, and what to change..."
        class="h-32 resize-y text-sm"
      />
    {/if}
    {#if errors.feedback}<p class="text-xs text-red-600">{errors.feedback}</p>{/if}
  </div>

  <Separator />

  <div class="space-y-3">
    {@render stat(
      'Time That Counts',
      formatMinutes(countedMinutes),
      formatMinutes(page.project.logged_minutes),
      journalsLeft,
      'journals',
    )}
    {@render stat('Funding', money(fundedCents), money(s.requested_cents), itemsLeft, 'parts')}
  </div>

  <div class="space-y-2.5">
    <p class="text-xs text-muted-foreground">
      Rubric <span class="text-muted-foreground/60">(not shown to user)</span>
    </p>
    {#each questions as [key, question] (key)}
      <div class="flex items-center justify-between gap-3">
        <span class="text-[13px] leading-snug">{question}</span>
        <Segmented
          label={question}
          size="xs"
          value={draft.rubric[key]}
          disabled={decided || !page.can.decide}
          onChange={(answer) => (draft.rubric[key] = answer as Answer)}
          options={[
            { value: 'yes', label: 'Yes', tint: 'green' },
            { value: 'partly', label: 'Partly', tint: 'amber' },
            { value: 'no', label: 'No', tint: 'red' },
          ]}
        />
      </div>
    {/each}
  </div>

  {#if !decided && page.can.decide}
    {@const shown = Object.entries(errors).filter(([k]) => !['feedback', 'internal_reason'].includes(k))}
    {#if shown.length}
      <ul
        transition:reveal
        class="space-y-1 rounded-md border border-red-200 bg-red-50 px-2.5 py-2 text-xs text-red-700 dark:border-red-900 dark:bg-red-950/40 dark:text-red-300"
      >
        {#each shown as [field, message] (field)}<li>{message}</li>{/each}
      </ul>
    {/if}

    <div class="space-y-2 pt-2">
      <div class="grid grid-cols-2 gap-2">
        <Button
          class={RAISED.success}
          disabled={submitting || !!approveBlocker}
          title={approveBlocker ?? undefined}
          onclick={() => onDecide('approved')}
        >
          {#if submitting && pending === 'approved'}<Loader
              class="animate-spin"
              data-icon="inline-start"
            />{:else}<Check data-icon="inline-start" />{/if}
          Approve
          <Key class="ml-1 {RAISED_KEY.success}">{mod}P</Key>
        </Button>
        <Button
          class={RAISED.warning}
          disabled={submitting || !!returnBlocker}
          title={returnBlocker ?? undefined}
          onclick={() => onDecide('returned')}
        >
          {#if submitting && pending === 'returned'}<Loader
              class="animate-spin"
              data-icon="inline-start"
            />{:else}<CornerDownLeft data-icon="inline-start" />{/if}
          Return
          <Key class="ml-1 {RAISED_KEY.warning}">{mod}E</Key>
        </Button>
      </div>
      <p class="text-center text-xs text-muted-foreground">
        {approveBlocker ?? `Approving sends ${money(fundedCents)}.`}
      </p>

      {#if page.can.reject}
        <AlertDialog.Root>
          <AlertDialog.Trigger>
            {#snippet child({ props })}
              <Button
                {...props}
                variant="ghost"
                size="sm"
                class="w-full justify-between text-muted-foreground"
                disabled={submitting || !!returnBlocker}
              >
                Reject for good
              </Button>
            {/snippet}
          </AlertDialog.Trigger>
          <AlertDialog.Content>
            <AlertDialog.Header>
              <AlertDialog.Title>Reject {page.project.title} for good?</AlertDialog.Title>
              <AlertDialog.Description>
                They can’t submit it again. Use this for fraud or plagiarism only; anything fixable should be
                returned.
              </AlertDialog.Description>
            </AlertDialog.Header>
            <AlertDialog.Footer>
              <AlertDialog.Cancel>Cancel</AlertDialog.Cancel>
              <AlertDialog.Action variant="destructive" onclick={() => onDecide('rejected')}
                >Reject</AlertDialog.Action
              >
            </AlertDialog.Footer>
          </AlertDialog.Content>
        </AlertDialog.Root>
      {/if}
    </div>
  {/if}
</div>
