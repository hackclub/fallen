<script lang="ts">
  import { router } from '@inertiajs/svelte'
  import type { Snippet } from 'svelte'
  import Flag from '@lucide/svelte/icons/flag'
  import GitBranch from '@lucide/svelte/icons/git-branch'
  import MessageSquareText from '@lucide/svelte/icons/message-square-text'
  import Moon from '@lucide/svelte/icons/moon'
  import Sun from '@lucide/svelte/icons/sun'
  import * as AlertDialog from '@/components/admin/ui/alert-dialog'
  import { Badge } from '@/components/admin/ui/badge'
  import { Button } from '@/components/admin/ui/button'
  import Key from '@/components/review/Key.svelte'
  import { Textarea } from '@/components/admin/ui/textarea'
  import { adminDark, toggleAdminDark } from '@/lib/adminDark.svelte'
  import type { ReviewPage } from '@/lib/review.svelte'
  import PersonLink from '@/components/review/PersonLink.svelte'
  import {
    flagReviewSubmission,
    project,
    releaseReviewSubmission,
    reviewSubmissions,
    unflagReviewSubmission,
  } from '@/routes'

  let {
    page,
    notesCount,
    onToggleNotes,
    center,
  }: { page: ReviewPage; notesCount: number; onToggleNotes: () => void; center: Snippet } = $props()

  let flagReason = $state('')
  let flagging = $state(false)

  const skipQuery = $derived(page.skip ? { skip: page.skip } : {})

  export function skip() {
    router.post(releaseReviewSubmission(page.submission.id, { query: skipQuery }).url)
  }

  function flag() {
    flagging = true
    router.post(
      flagReviewSubmission(page.submission.id, { query: skipQuery }).url,
      { reason: flagReason.trim() },
      { onFinish: () => (flagging = false) },
    )
  }
</script>

<div
  class="relative z-40 flex shrink-0 flex-wrap items-center gap-2 border-b border-border bg-muted/40 px-4 py-3"
>
  <Button variant="outline" href={reviewSubmissions.reviewRoot().url}>
    End session <Key class="ml-1">E</Key>
  </Button>
  {#if page.submission.status === 'pending'}
    <Button variant="ghost" onclick={skip}>Skip <Key class="ml-1">S</Key></Button>
  {/if}

  <span class="mx-1 hidden h-6 w-px bg-border sm:block"></span>

  <a
    href={project(page.project.id).url}
    target="_blank"
    rel="noopener"
    class="max-w-64 truncate font-semibold hover:underline">{page.project.title}</a
  >
  <span class="hidden truncate text-sm text-muted-foreground md:inline">
    by {#each page.project.team as person, i (person.id)}{i ? ', ' : ''}<PersonLink {person} />{/each}
  </span>

  <div class="absolute top-1/2 left-1/2 -translate-x-1/2 -translate-y-1/2">
    {@render center()}
  </div>

  <div class="ml-auto flex flex-wrap items-center gap-2">
    <Button variant="outline" href={page.submission.repo_url} target="_blank" rel="noopener noreferrer">
      <GitBranch data-icon="inline-start" /> Repo <Key class="ml-1">G</Key>
    </Button>
    <Button variant="outline" onclick={onToggleNotes}>
      <MessageSquareText data-icon="inline-start" /> Notes{notesCount > 0 ? ` (${notesCount})` : ''}
      <Key class="ml-1">N</Key>
    </Button>
    <Button variant="ghost" size="icon" aria-label="Toggle dark mode" onclick={toggleAdminDark}>
      {#if adminDark.on}<Sun />{:else}<Moon />{/if}
    </Button>

    {#if page.submission.flagged_at}
      <Badge variant="destructive">Flagged</Badge>
      {#if page.can.unflag}
        <Button variant="outline" onclick={() => router.post(unflagReviewSubmission(page.submission.id).url)}
          >Clear flag</Button
        >
      {/if}
    {:else if page.can.flag}
      <AlertDialog.Root>
        <AlertDialog.Trigger>
          {#snippet child({ props })}
            <Button {...props} variant="destructive" size="icon" aria-label="Flag for fraud"><Flag /></Button>
          {/snippet}
        </AlertDialog.Trigger>
        <AlertDialog.Content>
          <AlertDialog.Header>
            <AlertDialog.Title>Flag for fraud</AlertDialog.Title>
            <AlertDialog.Description>
              It leaves the queue until an admin looks at it. The team isn’t told: to them it still looks like
              it’s waiting for review.
            </AlertDialog.Description>
          </AlertDialog.Header>
          <Textarea bind:value={flagReason} placeholder="What did you see?" class="min-h-20" />
          <AlertDialog.Footer>
            <AlertDialog.Cancel>Cancel</AlertDialog.Cancel>
            <AlertDialog.Action variant="destructive" disabled={!flagReason.trim() || flagging} onclick={flag}
              >Flag it</AlertDialog.Action
            >
          </AlertDialog.Footer>
        </AlertDialog.Content>
      </AlertDialog.Root>
    {/if}
  </div>
</div>
