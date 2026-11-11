<script lang="ts">
  import { onMount } from 'svelte'
  import CheckDetail from '@/components/submission/CheckDetail.svelte'
  import { runChecks, type Check, type SubmissionDraft } from '@/lib/submission'

  type Fixable = 'ready' | 'repo' | 'screenshots' | 'bom'

  // The same checks the server runs when it's sent (SubmissionChecks). Failures block, warnings don't, but the
  // reviewer sees both.
  let {
    projectId,
    draft,
    checks = $bindable(),
    onFix,
  }: {
    projectId: string
    draft: SubmissionDraft
    checks: Check[] | null
    onFix: (step: Fixable) => void
  } = $props()

  let running = $state(false)
  let error = $state<string | null>(null)

  // Where each check is fixed in the popup. Journals are fixed on the project page.
  const FIX: Record<string, Fixable> = {
    repo: 'repo',
    readme: 'repo',
    readme_images: 'repo',
    pcb_source: 'repo',
    gerbers: 'repo',
    step: 'repo',
    cad_source: 'repo',
    firmware: 'repo',
    repo_bom: 'repo',
    screenshot: 'screenshots',
    bom: 'bom',
    bom_lines: 'bom',
    bom_ready_made: 'bom',
    bom_matches_repo: 'bom',
  }
  const ORDER = { fail: 0, warn: 1, pass: 2 }

  async function run() {
    running = true
    error = null
    try {
      checks = await runChecks(projectId, draft)
    } catch (e) {
      error = e instanceof Error ? e.message : 'Couldn’t run the checks'
    } finally {
      running = false
    }
  }

  onMount(() => {
    checks = null
    void run()
  })

  const sorted = $derived([...(checks ?? [])].sort((a, b) => ORDER[a.status] - ORDER[b.status]))
  const failed = $derived(sorted.filter((c) => c.status === 'fail').length)
  const warned = $derived(sorted.filter((c) => c.status === 'warn').length)
  let showPassed = $state(false)
</script>

{#if running && !checks}
  <div class="flex flex-col items-center gap-3 py-10 text-sm text-ink-soft">
    <span class="size-6 animate-spin rounded-full border-[3px] border-ink/15 border-t-[#1cb0f6]"></span>
    Looking over your repo, journals and parts...
  </div>
{:else if error}
  <div class="rounded-xl bg-red-50 px-4 py-3 text-center text-sm text-red-800">
    {error}
    <button type="button" class="ml-2 font-semibold underline" onclick={run}>Try again</button>
  </div>
{:else if checks}
  <p
    class={[
      'text-center font-[Jua] text-xl',
      failed ? 'text-red-700' : warned ? 'text-amber-700' : 'text-[#2b6a00]',
    ]}
  >
    {#if failed}
      {failed} {failed === 1 ? 'thing needs' : 'things need'} fixing
    {:else if warned}
      Good to go, with {warned} {warned === 1 ? 'thing' : 'things'} to look at
    {:else}
      Everything looks great!
    {/if}
  </p>

  <ul class="mt-4 space-y-2">
    {#each sorted as check (check.key)}
      {#if check.status !== 'pass' || showPassed}
        <li
          class={[
            'flex items-start gap-3 rounded-xl border-2 px-3.5 py-2.5 text-sm',
            check.status === 'fail' && 'border-red-200 bg-red-50',
            check.status === 'warn' && 'border-amber-200 bg-amber-50',
            check.status === 'pass' && 'border-paper-rim bg-[#fffdf8]',
          ]}
        >
          <span
            aria-label={check.status === 'pass' ? 'Passed' : check.status === 'warn' ? 'Warning' : 'Failed'}
            class={[
              'mt-0.5 grid size-5 shrink-0 place-items-center rounded-full text-[11px] font-bold text-white',
              check.status === 'fail' && 'bg-red-500',
              check.status === 'warn' && 'bg-amber-500',
              check.status === 'pass' && 'bg-[#58cc02]',
            ]}>{check.status === 'pass' ? '✓' : '!'}</span
          >
          <span class="min-w-0 flex-1">
            <span class="block font-semibold text-ink">{check.label}</span>
            {#if check.detail}<span class="block text-ink-soft"><CheckDetail {check} /></span>{/if}
          </span>
          {#if check.status !== 'pass' && FIX[check.key]}
            <button
              type="button"
              class="shrink-0 rounded-full bg-white px-3 py-1 text-xs font-semibold text-ink shadow-sm hover:bg-ink hover:text-white"
              onclick={() => onFix(FIX[check.key])}
            >
              Fix
            </button>
          {/if}
        </li>
      {/if}
    {/each}
  </ul>

  <div class="mt-3 flex justify-between text-xs">
    <button
      type="button"
      class="font-semibold text-ink-soft hover:text-ink"
      onclick={() => (showPassed = !showPassed)}
    >
      {showPassed ? 'Hide' : 'Show'} the {sorted.length - failed - warned} that passed
    </button>
    <button
      type="button"
      class="font-semibold text-ink-soft hover:text-ink disabled:opacity-50"
      disabled={running}
      onclick={run}
    >
      {running ? 'Checking...' : 'Check again'}
    </button>
  </div>
{/if}
