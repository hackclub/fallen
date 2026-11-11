<script lang="ts">
  import { money, requestedCents, type Check, type SubmissionDraft } from '@/lib/submission'

  let {
    note = $bindable(),
    draft,
    checks,
    resubmission,
    errors,
  }: {
    note: string
    draft: SubmissionDraft
    checks: Check[] | null
    resubmission: boolean
    errors: Record<string, string>
  } = $props()

  const warnings = $derived(checks?.filter((c) => c.status === 'warn').length ?? 0)
  const serverErrors = $derived(Object.values(errors).filter(Boolean))
</script>

<div class="grid gap-4 sm:grid-cols-[minmax(0,1fr)_minmax(0,1.1fr)]">
  {#if draft.screenshots[0]}
    <img
      src={draft.screenshots[0].url}
      alt=""
      class="aspect-[4/3] w-full rounded-xl border-2 border-paper-rim object-cover"
    />
  {/if}
  <dl class="space-y-2.5 text-sm">
    <div>
      <dt class="text-xs text-ink-soft">Repository</dt>
      <dd class="truncate font-semibold text-ink">{draft.snapshot?.url.replace(/^https:\/\//, '')}</dd>
      <dd class="font-mono text-xs text-ink-soft">
        {draft.snapshot?.branch} @ {draft.snapshot?.commit_sha?.slice(0, 7)}
      </dd>
    </div>
    <div>
      <dt class="text-xs text-ink-soft">Funding asked for</dt>
      <dd class="font-[Jua] text-2xl leading-tight text-ink">{money(requestedCents(draft.items))}</dd>
      <dd class="text-xs text-ink-soft">
        {draft.items.length}
        {draft.items.length === 1 ? 'row' : 'rows'} in the bill of materials
      </dd>
    </div>
    <div>
      <dt class="text-xs text-ink-soft">Screenshots</dt>
      <dd class="text-ink">{draft.screenshots.length}</dd>
    </div>
    {#if warnings > 0}
      <div>
        <dt class="text-xs text-ink-soft">Checks</dt>
        <dd class="text-amber-800">
          {warnings}
          {warnings === 1 ? 'warning' : 'warnings'} the reviewer will see
        </dd>
      </div>
    {/if}
  </dl>
</div>

<div class="mt-5">
  <label for="submission-note" class="mb-1 block text-sm text-ink">
    {resubmission ? 'What did you change since the last review?' : 'Anything the reviewer should know?'}
  </label>
  <textarea
    id="submission-note"
    rows="3"
    maxlength="2000"
    bind:value={note}
    placeholder={resubmission ? 'Added the gerbers and cut the spare ESP32s from the BOM.' : 'Optional'}
    class="paper-input"></textarea>
</div>

<p class="mt-4 text-center text-xs text-ink-soft">
  You can unsubmit your project later if you need to change anything.
</p>

{#if serverErrors.length > 0}
  <ul class="mt-3 space-y-1 rounded-xl bg-red-50 px-4 py-3 text-sm text-red-800">
    {#each serverErrors as message, i (i)}<li>{message}</li>{/each}
  </ul>
{/if}
