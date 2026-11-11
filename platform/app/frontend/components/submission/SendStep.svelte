<script lang="ts">
  import CheckDetail from '@/components/submission/CheckDetail.svelte'
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

  const warned = $derived(checks?.filter((c) => c.status === 'warn') ?? [])
  const warnings = $derived(warned.length)
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
        <dd>
          <details class="group">
            <summary
              class="flex cursor-pointer list-none items-center gap-1.5 text-amber-800 [&::-webkit-details-marker]:hidden"
            >
              {warnings}
              {warnings === 1 ? 'warning' : 'warnings'} the reviewer will see
              <svg
                viewBox="0 0 12 12"
                class="size-3 transition-transform group-open:rotate-180"
                fill="none"
                stroke="currentColor"
                stroke-width="2"
                aria-hidden="true"><path d="M2.5 4.5l3.5 3.5 3.5-3.5" stroke-linecap="round" /></svg
              >
            </summary>
            <ul class="mt-1.5 space-y-1.5">
              {#each warned as check (check.key)}
                <li class="rounded-lg bg-amber-50 px-2.5 py-1.5 text-xs text-amber-900">
                  <span class="block font-semibold">{check.label}</span>
                  {#if check.detail}<span class="block"><CheckDetail {check} /></span>{/if}
                </li>
              {/each}
            </ul>
          </details>
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
