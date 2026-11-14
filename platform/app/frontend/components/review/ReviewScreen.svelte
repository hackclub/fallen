<script lang="ts">
  import { router } from '@inertiajs/svelte'
  import { onMount } from 'svelte'
  import Folder from '@lucide/svelte/icons/folder'
  import FolderOpen from '@lucide/svelte/icons/folder-open'
  import ReviewTabBar, { type ReviewTab } from '@/components/review/ReviewTabBar.svelte'
  import LayoutGrid from '@lucide/svelte/icons/layout-grid'
  import NotebookPen from '@lucide/svelte/icons/notebook-pen'
  import Package from '@lucide/svelte/icons/package'
  import * as Dialog from '@/components/admin/ui/dialog'
  import Key from '@/components/review/Key.svelte'
  import BomPanel from '@/components/review/BomPanel.svelte'
  import DecisionPanel from '@/components/review/DecisionPanel.svelte'
  import JournalsPanel from '@/components/review/JournalsPanel.svelte'
  import NotesWindow from '@/components/review/NotesWindow.svelte'
  import OverviewPanel from '@/components/review/OverviewPanel.svelte'
  import RepoPanel from '@/components/review/RepoPanel.svelte'
  import ReviewTopBar from '@/components/review/ReviewTopBar.svelte'
  import { swap } from '@/components/review/motion'
  import Lightbox from '@/components/review/Lightbox.svelte'
  import {
    clearReviewDraft,
    initialDraft,
    itemFunded,
    countedMinutes as countedFor,
    itemDecided,
    itemVerdict,
    journalDecided,
    saveReviewDraft,
    serverDraft,
    type ReviewPage,
    type Verdict,
  } from '@/lib/review.svelte'
  import { toast } from '@/lib/toasts'
  import {
    draftReviewSubmission,
    heartbeatReviewSubmission,
    reviewSubmission,
    reviewSubmissions,
  } from '@/routes'
  import { shared } from '@/lib/shared.svelte'
  import { csrfToken } from '@/lib/csrf'

  // One design submission's review, after Fallout's review pages: tabs on the left for the evidence (overview,
  // journals, parts list, repo), the decision on the right. The review in progress is kept in this browser until
  // it's sent, and the claim on it is renewed while the page is open. Made fresh for each submission (Show.svelte).
  let props: ReviewPage = $props()

  type Tab = 'overview' | 'journals' | 'bom' | 'repo'
  const TABS: (ReviewTab & { id: Tab })[] = [
    { id: 'overview', title: 'Overview', icon: LayoutGrid, tint: 'green' },
    { id: 'journals', title: 'Journals', icon: NotebookPen, tint: 'blue' },
    { id: 'bom', title: 'Parts', icon: Package, tint: 'amber' },
    { id: 'repo', title: 'Repo', icon: Folder, activeIcon: FolderOpen, tint: 'violet' },
  ]

  // svelte-ignore state_referenced_locally
  let draft = $state(initialDraft(props))
  // svelte-ignore state_referenced_locally
  const submissionId = props.submission.id
  let tab = $state<Tab>('overview')
  let notesOpen = $state(false)
  let helpOpen = $state(false)
  let focusedJournal = $state(0)
  let submitting = $state(false)
  let pending = $state<Verdict | null>(null)
  let errors = $state<Record<string, string>>({})
  let lost = $state(false)
  let feedbackRef: HTMLTextAreaElement | null = $state(null)
  let internalRef: HTMLTextAreaElement | null = $state(null)
  let journalsPanel: JournalsPanel | undefined = $state()
  let bomPanel: BomPanel | undefined = $state()
  let focusedPart = $state(0)
  let topBar: ReviewTopBar | undefined = $state()
  let decision: DecisionPanel | undefined = $state()
  let repoPanel: RepoPanel | undefined = $state()
  let repoOpened = $state(false)
  $effect(() => {
    if (tab === 'repo') repoOpened = true
  })

  const decided = $derived(props.submission?.status !== 'pending')
  const readonly = $derived(decided || !props.can.decide)

  // Saved under the id it opened with: leaving the page swaps the props for the next page's before this goes. Kept
  // in this browser at once and on the server a moment later (and as the page is left), but only by whoever holds
  // the submission, and not for what it opened with.
  // svelte-ignore state_referenced_locally
  const saving = !decided && props.claimed
  const server = serverDraft(draftReviewSubmission(submissionId).url)
  let opened = false
  $effect(() => {
    const snapshot = $state.snapshot(draft)
    if (decided) return
    saveReviewDraft(submissionId, snapshot)
    if (opened && saving) server.schedule(snapshot)
    opened = true
  })

  onMount(() => {
    const by = props.draft?.by
    if (!decided && by && by.id !== shared().auth.user?.id)
      toast.info(`Carrying on from ${by.name}’s unfinished review`)
    if (!saving) return
    const leaving = () => server.flush()
    const hidden = () => document.visibilityState === 'hidden' && server.flush()
    window.addEventListener('pagehide', leaving)
    document.addEventListener('visibilitychange', hidden)
    return () => {
      server.flush()
      window.removeEventListener('pagehide', leaving)
      document.removeEventListener('visibilitychange', hidden)
    }
  })

  const countedMinutes = $derived(
    (props.journals ?? []).reduce(
      (sum, j) => sum + (countedFor(j, draft.journals[j.id]) ?? j.duration_minutes ?? 0),
      0,
    ),
  )
  const fundedCents = $derived(
    (props.submission?.bom_items ?? []).reduce(
      (sum, item) => sum + (itemFunded(item, draft.bom[item.id]) ?? 0),
      0,
    ),
  )
  const journalsLeft = $derived(
    (props.journals ?? []).filter((j) => !journalDecided(j, draft.journals[j.id])).length,
  )
  const itemsLeft = $derived(
    (props.submission?.bom_items ?? []).filter((i) => !itemDecided(i, draft.bom[i.id])).length,
  )

  // Keeps the claim while the page is open. Losing it (left open past the claim, someone else took it) stops the
  // decision from going in, so the reviewer finds out now rather than on send.
  onMount(() => {
    if (!props.claimed || decided) return
    const beat = async () => {
      try {
        const response = await fetch(heartbeatReviewSubmission(props.submission.id).url, {
          method: 'POST',
          headers: { 'X-CSRF-Token': csrfToken(), Accept: 'application/json' },
          credentials: 'same-origin',
        })
        const data = await response.json()
        if (!data.held && !lost) {
          lost = true
          toast.error('Someone else has this submission now. Your review wasn’t sent.', { duration: 10000 })
        }
      } catch {
        // Offline for a moment: the next beat tries again.
      }
    }
    const timer = setInterval(beat, 120_000)
    return () => clearInterval(timer)
  })

  function decide(verdict: Verdict) {
    const blockers = decision?.blockers()
    const blocker = verdict === 'approved' ? blockers?.approve : blockers?.return
    if (blocker) return toast.error(blocker)
    submitting = true
    pending = verdict
    errors = {}
    router.patch(
      reviewSubmission(props.submission.id, { query: props.skip ? { skip: props.skip } : {} }).url,
      {
        review: {
          verdict,
          feedback: draft.feedback,
          internal_reason: draft.internal,
          rubric: draft.rubric,
          journals: Object.fromEntries(
            Object.entries(draft.journals).map(([id, call]) => [
              id,
              {
                approved_minutes: countedFor(
                  props.journals.find((j) => j.id === id)!,
                  call,
                ),
                reason: call.reason,
                note: call.note,
              },
            ]),
          ),
          bom: Object.fromEntries(
            props.submission.bom_items.map((item) => {
              const call = draft.bom[item.id]
              return [
                item.id,
                { verdict: itemVerdict(item, call), reason: call?.reason, approved_cents: call?.cents },
              ]
            }),
          ),
        },
      },
      {
        onSuccess: (page) => {
          if (Object.keys(page.props.errors ?? {}).length) return
          server.stop()
          clearReviewDraft(submissionId)
        },
        onError: (e) => (errors = e as Record<string, string>),
        onFinish: () => {
          submitting = false
          pending = null
        },
      },
    )
  }

  function typing(target: EventTarget | null) {
    return (
      target instanceof HTMLElement &&
      (target.isContentEditable || ['INPUT', 'TEXTAREA', 'SELECT'].includes(target.tagName))
    )
  }

  function onKeydown(event: KeyboardEvent) {
    // The repo tree's search box is inside a shadow root, so the event's target is its host.
    const target = event.composedPath()[0] ?? event.target
    const mod = event.metaKey || event.ctrlKey
    if (mod && !event.shiftKey && !event.altKey) {
      const key = event.key.toLowerCase()
      if (key === 'p' && !readonly) return (event.preventDefault(), decide('approved'))
      if (key === 'e' && !readonly) return (event.preventDefault(), decide('returned'))
      if (key === 'j') return (event.preventDefault(), internalRef?.focus())
      if (key === 'f') return (event.preventDefault(), feedbackRef?.focus())
      return
    }
    if (event.key === 'Escape') {
      if (typing(target)) (target as HTMLElement).blur()
      else notesOpen = false
      return
    }
    if (typing(target) || event.altKey || mod) return
    const key = event.key
    if (key >= '1' && key <= '4') return (tab = TABS[Number(key) - 1].id)
    if (key === 'n') return (notesOpen = !notesOpen)
    if (key === '?') return (helpOpen = !helpOpen)
    if (key === 'e') return router.visit(reviewSubmissions.reviewRoot().url)
    if (key === 's' && props.submission.status === 'pending') return topBar?.skip()
    if (key === 'g') return void window.open(props.submission.repo_url, '_blank', 'noopener')
    if (tab === 'repo' && key === 'p') return repoPanel?.togglePinned()
    if (tab === 'journals') {
      if (key === 'j') return (event.preventDefault(), journalsPanel?.move(1))
      if (key === 'k') return (event.preventDefault(), journalsPanel?.move(-1))
      if (key === 'a') return journalsPanel?.act('full')
      if (key === 'r') return (event.preventDefault(), journalsPanel?.act('part'))
      if (key === 'x') return journalsPanel?.act('none')
    }
    if (tab === 'bom') {
      if (key === 'j') return (event.preventDefault(), bomPanel?.move(1))
      if (key === 'k') return (event.preventDefault(), bomPanel?.move(-1))
      if (key === 'a') return bomPanel?.act('approved')
      if (key === 'l') return (event.preventDefault(), bomPanel?.act('adjusted'))
      if (key === 'x') return bomPanel?.act('cut')
    }
  }

  const SHORTCUTS = [
    ['1 to 4', 'Switch tabs'],
    ['J / K', 'Next or previous journal or part'],
    ['A / R / X', 'Journal counts all, is deflated, or counts none'],
    ['A / L / X', 'Part approved, lowered, or cut'],
    ['P', 'Pinned repo files only'],
    ['N', 'Notes'],
    ['G', 'Open the repo'],
    ['S', 'Skip to the next submission'],
    ['E', 'End the session'],
    ['Ctrl/⌘ J', 'Internal reason'],
    ['Ctrl/⌘ F', 'Feedback'],
    ['Ctrl/⌘ P', 'Approve'],
    ['Ctrl/⌘ E', 'Return'],
  ]
</script>

<svelte:window onkeydown={onKeydown} />
<svelte:head><title>{props.project.title} · Review</title></svelte:head>

{#snippet tabBar()}
  <ReviewTabBar tabs={TABS} value={tab} onChange={(id) => (tab = id as Tab)} />
{/snippet}

<div class="flex h-screen flex-col overflow-hidden">
  <ReviewTopBar
    bind:this={topBar}
    page={props}
    notesCount={props.notes.length}
    onToggleNotes={() => (notesOpen = !notesOpen)}
    center={tabBar}
  />

  {#if notesOpen}
    <NotesWindow
      submissionId={props.submission.id}
      notes={props.notes}
      canWrite={props.can.note}
      onClose={() => (notesOpen = false)}
    />
  {/if}

  {#if lost}
    <div class="bg-red-600 px-4 py-1.5 text-center text-sm text-white">
      You no longer hold this submission. Reload to see who does before deciding.
    </div>
  {/if}

  <div class="flex min-h-0 flex-1">
    <main class="min-w-0 flex-1 overflow-y-auto">
      {#key tab}
        <div in:swap>
          {#if tab === 'overview'}
            <OverviewPanel page={props} {countedMinutes} {fundedCents} />
          {:else if tab === 'journals'}
            <JournalsPanel
              bind:this={journalsPanel}
              page={props}
              bind:draft
              {readonly}
              bind:focused={focusedJournal}
            />
          {:else if tab === 'bom'}
            <BomPanel bind:this={bomPanel} page={props} bind:draft {readonly} bind:focused={focusedPart} />
          {/if}
        </div>
      {/key}
      <!-- Kept once opened, so the file and its viewer are still there after looking at another tab. -->
      {#if repoOpened}
        <div class={['h-full', tab !== 'repo' && 'hidden']}>
          <RepoPanel bind:this={repoPanel} repo={props.repo} submissionId={props.submission.id} />
        </div>
      {/if}
    </main>
    <div class="w-px shrink-0 bg-border"></div>
    <aside class="w-80 shrink-0 overflow-y-auto">
      <DecisionPanel
        bind:this={decision}
        page={props}
        bind:draft
        {countedMinutes}
        {fundedCents}
        {submitting}
        {pending}
        {errors}
        onDecide={decide}
        bind:feedbackRef
        bind:internalRef
      />
    </aside>
  </div>
</div>

<Lightbox />

<Dialog.Root bind:open={helpOpen}>
  <Dialog.Content class="max-w-sm">
    <Dialog.Header><Dialog.Title>Shortcuts</Dialog.Title></Dialog.Header>
    <dl class="grid grid-cols-[auto_1fr] gap-x-4 gap-y-1.5 text-sm">
      {#each SHORTCUTS as [keys, what] (keys)}
        <dt><Key>{keys}</Key></dt>
        <dd class="text-muted-foreground">{what}</dd>
      {/each}
    </dl>
  </Dialog.Content>
</Dialog.Root>
