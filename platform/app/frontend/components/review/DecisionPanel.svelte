<script lang="ts">
  import Check from '@lucide/svelte/icons/check'
  import CornerDownLeft from '@lucide/svelte/icons/corner-down-left'
  import Loader from '@lucide/svelte/icons/loader'
  import * as AlertDialog from '@/components/admin/ui/alert-dialog'
  import { Button } from '@/components/admin/ui/button'
  import { Checkbox } from '@/components/admin/ui/checkbox'
  import { Input } from '@/components/admin/ui/input'
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
    AI_FEEDBACK,
    AI_INTERNAL,
    aiTemplate,
    journalDecided,
    journalNeedsReason,
    markAi,
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
  const ai = $derived(draft.ai)
  const journalsLeft = $derived(
    ai ? 0 : page.journals.filter((j) => !journalDecided(j, draft.journals[j.id])).length,
  )
  const journalReasonsMissing = $derived(
    !ai && page.journals.some((j) => journalNeedsReason(draft.journals[j.id])),
  )

  // What's typed, kept apart from draft.cut so a 0 on the way to 0.5 isn't wiped out.
  let cutHours = $state(draft.cut == null ? '' : String(+(draft.cut / 60).toFixed(2)))
  const cutBlocker = $derived(
    draft.cut != null && (draft.cut < 1 || draft.cut > countedMinutes)
      ? `The internal cut can be at most the ${formatMinutes(countedMinutes)} that count`
      : null,
  )

  const AI_ONLY = 'AI-generated journals can only be rejected for good'
  const reasonBlocker = $derived(!draft.internal.trim() ? 'Write the internal reason' : null)
  const feedbackBlocker = $derived(
    !draft.feedback.trim() ? 'Write feedback so they know what to change' : null,
  )
  // Returning needs only the rubric and the reasons: it settles no time and no funding.
  const basics = $derived(!answered ? 'Answer every question' : reasonBlocker)
  const common = $derived(
    basics ??
      (journalsLeft
        ? `Finish the ${journalsLeft} deflated journal${journalsLeft === 1 ? '' : 's'}`
        : journalReasonsMissing
          ? 'Give a reason for every journal you deflate'
          : null) ??
      cutBlocker,
  )
  const approveBlocker = $derived(ai ? AI_ONLY : common)
  const returnBlocker = $derived(ai ? AI_ONLY : (basics ?? feedbackBlocker))
  // Marked AI-generated, it's rejected with just the reasons: no rubric, journals, parts or cut.
  const rejectBlocker = $derived(ai ? (reasonBlocker ?? feedbackBlocker) : (common ?? feedbackBlocker))
  // Any design reviewer can reject for AI-generated journals; anything else only admins.
  const canReject = $derived(page.can.reject || (ai && page.can.decide))

  export const blockers = () => ({ approve: approveBlocker, return: returnBlocker, reject: rejectBlocker })
</script>

{#snippet useTemplate(field: 'internal' | 'feedback', template: string)}
  {#if ai && !decided && page.can.decide && !draft[field].includes(template.trim())}
    <button
      type="button"
      class="ml-auto text-xs text-red-700 underline-offset-2 hover:underline dark:text-red-400"
      onclick={() => (draft[field] = aiTemplate(draft[field], template))}>Use AI template</button
    >
  {/if}
{/snippet}

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

  {#if !decided || ai}
    <div
      class={[
        'space-y-2.5 rounded-lg border-2 px-3 py-2.5 transition-colors',
        ai ? 'border-red-300 bg-red-50 dark:border-red-800 dark:bg-red-950/30' : 'border-border',
      ]}
    >
      <label class="flex cursor-pointer items-center gap-2.5">
        <Checkbox
          checked={ai}
          disabled={decided || !page.can.decide}
          onCheckedChange={(value) => markAi(draft, value === true)}
        />
        <span class="min-w-0">
          <span class="block text-sm font-medium">AI-generated journals</span>
          <span class="block text-xs text-muted-foreground"
            >{decided
              ? 'Rejected for AI-generated journals.'
              : 'Overrides everything else: it can only be rejected for good, and every journal counts no time.'}</span
          >
        </span>
      </label>
    </div>
  {/if}

  <div class="space-y-2">
    <div class="flex items-center gap-2">
      {@render label(
        'Internal Reason',
        'not shown to user',
        decided ? undefined : `${mod}J`,
        'internal-reason',
      )}
      {@render useTemplate('internal', AI_INTERNAL)}
    </div>
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
    <div class="flex items-center gap-2">
      {@render label('Feedback', 'shown to user', decided ? undefined : `${mod}F`, 'feedback')}
      {@render useTemplate('feedback', AI_FEEDBACK)}
    </div>
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
    {@render stat('Funding', money(fundedCents), money(s.requested_cents), 0, 'parts')}

    {#if !ai && (!decided || draft.cut)}
      <div class="space-y-1.5">
        <p class="text-xs text-muted-foreground">
          Internal Cut <span class="text-muted-foreground/60">(not shown to user)</span>
        </p>
        <div class="flex items-center gap-2 text-xs text-muted-foreground">
          {#if decided}
            <span class="font-mono text-sm">−{formatMinutes(draft.cut ?? 0)}</span>
          {:else}
            <label for="internal-cut">Take off</label>
            <Input
              id="internal-cut"
              type="number"
              min="0"
              step="0.25"
              bind:value={cutHours}
              oninput={() => {
                const hours = parseFloat(String(cutHours))
                draft.cut = Number.isNaN(hours) || hours <= 0 ? null : Math.round(hours * 60)
              }}
              readonly={!page.can.decide}
              class="h-7 w-20 font-mono text-sm"
            />
            <span>hours</span>
          {/if}
          <span class="ml-auto font-mono whitespace-nowrap">
            → <span class={draft.cut ? 'font-semibold text-foreground' : ''}
              ><Morph text={formatMinutes(Math.max(countedMinutes - (draft.cut ?? 0), 0))} /></span
            > for YSWS
          </span>
        </div>
        {#if !decided}
          <p class="text-xs text-muted-foreground">
            Only lowers the hours reported to YSWS. Their journals, XP and funding stay as above.
          </p>
        {/if}
        {#if errors.cut}<p class="text-xs text-red-600">{errors.cut}</p>{/if}
      </div>
    {/if}
  </div>

  <div class="space-y-2.5">
    <p class="text-xs text-muted-foreground">
      Rubric <span class="text-muted-foreground/60"
        >({ai && !decided ? 'not needed' : 'not shown to user'})</span
      >
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
    {@const shown = Object.entries(errors).filter(
      ([k]) => !['feedback', 'internal_reason', 'cut'].includes(k),
    )}
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
        {ai
          ? 'Marked as AI-generated journals: reject it for good below.'
          : (approveBlocker ?? `Approving sends ${money(fundedCents)}.`)}
      </p>
      {#if !ai && draft.cut}
        <p class="text-center text-xs text-muted-foreground">
          Returning keeps your journal and part calls for the next review, but not the internal cut.
        </p>
      {/if}

      {#if canReject}
        <AlertDialog.Root>
          <AlertDialog.Trigger>
            {#snippet child({ props })}
              <Button
                {...props}
                variant={ai ? 'destructive' : 'ghost'}
                size="sm"
                class={['w-full', !ai && 'justify-between text-muted-foreground']}
                disabled={submitting || !!rejectBlocker}
                title={rejectBlocker ?? undefined}
              >
                Reject for good
              </Button>
            {/snippet}
          </AlertDialog.Trigger>
          <AlertDialog.Content>
            <AlertDialog.Header>
              <AlertDialog.Title>Reject {page.project.title} for good?</AlertDialog.Title>
              <AlertDialog.Description>
                {#if ai}
                  They can’t submit it again, and every journal it covers counts no time or XP. They get your
                  feedback as a DM.
                {:else}
                  They can’t submit it again. Use this for fraud or plagiarism only; anything fixable should
                  be returned.
                {/if}
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
