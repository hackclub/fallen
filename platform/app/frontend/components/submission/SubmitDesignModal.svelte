<script lang="ts">
  import { router } from '@inertiajs/svelte'
  import Modal from '@/components/Modal.svelte'
  import ModalButton from '@/components/ModalButton.svelte'
  import ReadyStep, { PROMISES } from '@/components/submission/ReadyStep.svelte'
  import RepoStep from '@/components/submission/RepoStep.svelte'
  import ScreenshotsStep from '@/components/submission/ScreenshotsStep.svelte'
  import BomStep from '@/components/submission/BomStep.svelte'
  import ChecksStep from '@/components/submission/ChecksStep.svelte'
  import SendStep from '@/components/submission/SendStep.svelte'
  import { projectSubmissions } from '@/routes'
  import { clearDraft, itemPayload, itemProblem, loadDraft, saveDraft, type Check } from '@/lib/submission'
  import type { Project, RepoSnapshot } from '@/types'

  // Sending a project's design for review, one step at a time: what it has, its repository, screenshots, its bill
  // of materials, the checks, then a note and send. Everything typed is kept in the browser until it's sent, so
  // closing the popup halfway loses nothing. The server runs the checks again on send (Submission.submit).
  let {
    project,
    directUploadUrl,
    resubmission,
    onClose,
  }: { project: Project; directUploadUrl: string; resubmission: boolean; onClose: () => void } = $props()

  const STEPS = [
    { key: 'ready', title: 'Ready to submit?' },
    { key: 'repo', title: 'Your repository' },
    { key: 'screenshots', title: 'Show it off' },
    { key: 'bom', title: 'Bill of materials' },
    { key: 'checks', title: 'Checking everything' },
    { key: 'send', title: 'Send it in' },
  ] as const
  type StepKey = (typeof STEPS)[number]['key']

  // svelte-ignore state_referenced_locally
  let draft = $state(loadDraft(project.id, project.repo_url ?? ''))
  let step = $state(0)
  let checks = $state<Check[] | null>(null)
  let uploading = $state(false)
  let sending = $state(false)
  let errors = $state<Record<string, string>>({})

  $effect(() => saveDraft(project.id, $state.snapshot(draft)))

  // The parts list starts from the repo's bom.csv (BomStep fills an empty list by itself). When a check finds a
  // different repository, or the list came from a bom.csv that has since changed, offer to start the list over so it
  // fills from the new one. Rows may have been typed or fixed here, so it asks first, the way loading a CSV does. A
  // list made by hand stays on a re-check of the same repository.
  function repoChecked(snapshot: RepoSnapshot) {
    const before = draft.bomRepo
    const csv = snapshot.bom_csv ?? ''
    draft.bomRepo = { url: snapshot.url, csv }
    if (!before || draft.items.length === 0) return

    const otherRepo = snapshot.url !== before.url
    const repoBomChanged = draft.bomCsv !== '' && draft.bomCsv === before.csv && csv !== before.csv
    if (!otherRepo && !repoBomChanged) return

    const why = otherRepo ? 'This is a different repository' : 'Your repo’s bom.csv has changed'
    if (confirm(`${why}. Start your ${draft.items.length}-row parts list over from it?`)) {
      draft.items = []
      draft.bomCsv = ''
    }
  }

  const current = $derived(STEPS[step])
  const blocker = $derived.by((): string | null => {
    switch (current.key) {
      case 'ready':
        return draft.ready.filter(Boolean).length < PROMISES.length ? 'Tick every box when it’s true' : null
      case 'repo':
        if (draft.snapshot?.status !== 'done') return 'Check your repository first'
        return null
      case 'screenshots':
        if (uploading) return 'Waiting for the upload'
        return draft.screenshots.length === 0 ? 'Add at least one screenshot' : null
      case 'bom': {
        if (draft.items.length === 0) return 'Add the parts you need'
        const bad = draft.items.findIndex((item) => itemProblem(item))
        return bad >= 0 ? `Row ${bad + 1}: ${itemProblem(draft.items[bad])}` : null
      }
      case 'checks':
        if (!checks) return 'Running the checks'
        return checks.some((check) => check.status === 'fail') ? 'Fix what failed to continue' : null
      case 'send':
        return resubmission && !draft.note.trim() ? 'Say what you changed since the last review' : null
    }
  })

  function go(to: StepKey) {
    step = STEPS.findIndex((s) => s.key === to)
  }

  function back() {
    if (step === 0) onClose()
    else step -= 1
  }

  function next() {
    if (blocker) return
    if (current.key === 'send') send()
    else step += 1
  }

  function send() {
    sending = true
    errors = {}
    router.post(
      projectSubmissions(project.id).url,
      {
        submission: {
          snapshot_id: draft.snapshot?.id,
          made_with: draft.madeWith,
          note: draft.note,
          bom_csv: draft.bomCsv,
          screenshots: draft.screenshots.map((s) => s.id),
          items: draft.items.map(itemPayload),
        },
      },
      {
        preserveScroll: true,
        onSuccess: () => {
          clearDraft(project.id)
          onClose()
        },
        onError: (e) => (errors = e as Record<string, string>),
        onFinish: () => (sending = false),
      },
    )
  }

  function escape(event: KeyboardEvent) {
    if (event.key !== 'Escape' || event.defaultPrevented) return
    if (step > 0) step -= 1
    else onClose()
  }
</script>

<svelte:window onkeydown={escape} />

<Modal
  titleId="submit-design-title"
  title={current.title}
  eyebrow="{step + 1}/{STEPS.length}"
  {onClose}
  class={current.key === 'bom' ? 'max-w-4xl' : 'max-w-2xl'}
>
  <div class="flex max-h-[calc(90vh-130px)] flex-col font-outfit">
    <!-- Only the step scrolls; the Back/Next buttons below stay in view however short the window is. -->
    <div class="min-h-0 flex-1 overflow-x-hidden overflow-y-auto px-5 pt-2 md:px-9">
      <ol class="mb-5 flex items-center justify-center gap-1.5" aria-label="Steps">
        {#each STEPS as s, i (s.key)}
          <li>
            <button
              type="button"
              aria-label="{i + 1}. {s.title}"
              aria-current={i === step ? 'step' : undefined}
              disabled={i > step}
              onclick={() => (step = i)}
              class={[
                'block h-2 rounded-full transition-all duration-300',
                i === step
                  ? 'w-8 bg-[#1cb0f6]'
                  : i < step
                    ? 'w-2 cursor-pointer bg-ink/50 hover:bg-ink'
                    : 'w-2 bg-ink/15',
              ]}
            ></button>
          </li>
        {/each}
      </ol>

      {#if current.key === 'ready'}
        <ReadyStep bind:ready={draft.ready} {resubmission} />
      {:else if current.key === 'repo'}
        <RepoStep
          projectId={project.id}
          bind:url={draft.repoUrl}
          bind:snapshot={draft.snapshot}
          bind:checkedUrl={draft.checkedUrl}
          onChecked={repoChecked}
        />
      {:else if current.key === 'screenshots'}
        <ScreenshotsStep bind:screenshots={draft.screenshots} bind:uploading {directUploadUrl} />
      {:else if current.key === 'bom'}
        <BomStep bind:items={draft.items} bind:bomCsv={draft.bomCsv} snapshot={draft.snapshot} />
      {:else if current.key === 'checks'}
        <ChecksStep projectId={project.id} {draft} bind:checks onFix={go} />
      {:else}
        <SendStep bind:note={draft.note} {draft} {checks} {resubmission} {errors} />
      {/if}
    </div>

    <div class="shrink-0 px-5 pt-5 pb-6 md:px-9 md:pb-8">
      <div class="flex flex-col-reverse items-center justify-center gap-3 sm:flex-row">
        <ModalButton kind="cancel" onclick={back}>{step === 0 ? 'Not yet' : 'Back'}</ModalButton>
        <ModalButton kind="confirm" onclick={next} disabled={!!blocker || sending}>
          {#if current.key === 'send'}
            {sending ? 'Sending...' : 'Submit for review'}
          {:else}
            Next
          {/if}
        </ModalButton>
      </div>
      {#if blocker}
        <p class="mt-2 text-center text-sm text-ink-soft" aria-live="polite">{blocker}</p>
      {/if}
    </div>
  </div>
</Modal>
