<script lang="ts">
  import { router } from '@inertiajs/svelte'
  import X from '@lucide/svelte/icons/x'
  import { Button } from '@/components/admin/ui/button'
  import { Textarea } from '@/components/admin/ui/textarea'
  import PersonLink from '@/components/review/PersonLink.svelte'
  import { rise } from '@/components/review/motion'
  import { timeAgo } from '@/lib/format'
  import { reviewSubmissionNotes } from '@/routes'
  import type { ReviewerNote } from '@/types'

  // Reviewers' notes on the project, kept across its submissions. The team never sees them.
  let {
    submissionId,
    notes,
    canWrite,
    onClose,
  }: { submissionId: string; notes: ReviewerNote[]; canWrite: boolean; onClose: () => void } = $props()

  let body = $state('')
  let saving = $state(false)

  function add(event: SubmitEvent) {
    event.preventDefault()
    if (!body.trim()) return
    saving = true
    router.post(
      reviewSubmissionNotes(submissionId).url,
      { body: body.trim() },
      {
        preserveScroll: true,
        preserveState: true,
        only: ['notes'],
        onSuccess: () => (body = ''),
        onFinish: () => (saving = false),
      },
    )
  }
</script>

<div
  transition:rise
  class="absolute top-14 right-4 z-50 flex max-h-[70vh] w-96 flex-col overflow-hidden rounded-lg border border-border bg-background shadow-xl"
>
  <div class="flex items-center justify-between border-b border-border px-3 py-2">
    <h2 class="text-sm font-semibold">Reviewer notes</h2>
    <Button variant="ghost" size="icon-sm" aria-label="Close notes" onclick={onClose}><X /></Button>
  </div>
  <div class="flex-1 space-y-3 overflow-y-auto p-3">
    {#each notes as note (note.id)}
      <div class="text-sm">
        <div class="mb-0.5 flex items-center justify-between text-xs text-muted-foreground">
          <PersonLink person={note.author} avatar />
          <span>{timeAgo(note.created_at)}</span>
        </div>
        <p class="whitespace-pre-wrap">{note.body}</p>
      </div>
    {:else}
      <p class="text-sm text-muted-foreground">No notes on this project yet.</p>
    {/each}
  </div>
  {#if canWrite}
    <form class="space-y-2 border-t border-border p-3" onsubmit={add}>
      <Textarea
        bind:value={body}
        maxlength={2000}
        placeholder="Something the next reviewer should know"
        class="min-h-16 text-sm"
      />
      <Button type="submit" size="sm" disabled={saving || !body.trim()}>Add note</Button>
    </form>
  {/if}
</div>
