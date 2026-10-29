<script lang="ts">
  import { router } from '@inertiajs/svelte'
  import CalendarCheck from '@lucide/svelte/icons/calendar-check'
  import Megaphone from '@lucide/svelte/icons/megaphone'
  import SlidersHorizontal from '@lucide/svelte/icons/sliders-horizontal'
  import Sparkles from '@lucide/svelte/icons/sparkles'
  import Snowflake from '@lucide/svelte/icons/snowflake'
  import Undo2 from '@lucide/svelte/icons/undo-2'
  import StreakPreviewPanel from '@/components/admin/streaks/StreakPreviewPanel.svelte'
  import * as AlertDialog from '@/components/admin/ui/alert-dialog'
  import { Badge } from '@/components/admin/ui/badge'
  import { Button } from '@/components/admin/ui/button'
  import { formatDateTime, timeAgo } from '@/lib/format'
  import { describeAdjustment, effectChips, type StreakPreview } from '@/lib/streaks'
  import { adminStreakAdjustment, adminStreaks } from '@/routes'
  import type { AdminStreakAdjustment } from '@/types'

  // Every change to the person's streak and the incidents that touched it, newest first, each undoable while it
  // stands. Undoing asks for the same preview a change does, so the admin sees what it takes back.
  let { adjustments, canUndo }: { adjustments: AdminStreakAdjustment[]; canUndo: boolean } = $props()

  let preview = $state<StreakPreview>()
  let undoing = $state<AdminStreakAdjustment | null>(null)
  let loading = $state(false)
  let saving = $state(false)

  const ICONS = { excuse: CalendarCheck, freezes: Snowflake, set: SlidersHorizontal, xp: Sparkles }

  function askUndo(adjustment: AdminStreakAdjustment) {
    undoing = adjustment
    preview = undefined
    if (adjustment.incident) return
    loading = true
    router.reload({
      only: ['streak_preview'],
      data: { preview: { undo: adjustment.id } },
      onSuccess: (page) => (preview = page.props.streak_preview as StreakPreview),
      onFinish: () => (loading = false),
    })
  }

  function undo() {
    if (!undoing) return
    router.delete(adminStreakAdjustment(undoing.id), {
      preserveScroll: true,
      onStart: () => (saving = true),
      onFinish: () => {
        saving = false
        undoing = null
      },
    })
  }
</script>

{#if adjustments.length === 0}
  <p class="text-sm text-muted-foreground">
    No changes yet. Anything you do here is listed with who did it and why.
  </p>
{:else}
  <ol class="space-y-3">
    {#each adjustments as adjustment (adjustment.id)}
      {@const Icon = adjustment.incident ? Megaphone : ICONS[adjustment.kind]}
      {@const undone = Boolean(adjustment.discarded_at)}
      <li class={['flex gap-3', undone && 'opacity-60']}>
        <span
          class={[
            'mt-0.5 flex size-7 shrink-0 items-center justify-center rounded-full',
            adjustment.incident
              ? 'bg-amber-100 text-amber-700 dark:bg-amber-950 dark:text-amber-300'
              : 'bg-muted',
          ]}
        >
          <Icon class="size-3.5" />
        </span>
        <div class="min-w-0 flex-1">
          <div class="flex flex-wrap items-center gap-x-2 gap-y-1">
            <span class={['text-sm font-medium', undone && 'line-through']}
              >{describeAdjustment(adjustment)}</span
            >
            {#if adjustment.incident}
              <a href={adminStreaks.index({ query: { tab: 'incidents' } }).url}>
                <Badge variant="outline" class="text-[10px]">Everyone</Badge>
              </a>
            {/if}
            {#if undone}<Badge variant="secondary" class="text-[10px]"
                >Undone by {adjustment.undone_by ?? 'someone'}</Badge
              >{/if}
            {#if adjustment.notify}<Badge variant="secondary" class="text-[10px]">DMed</Badge>{/if}
          </div>
          <p class="text-sm text-muted-foreground">“{adjustment.reason}”</p>
          {#if adjustment.message}
            <p class="mt-1 border-l-2 pl-2 text-xs whitespace-pre-line text-muted-foreground">
              Told them: {adjustment.message}
            </p>
          {/if}
          <div class="mt-1 flex flex-wrap items-center gap-1.5 text-xs text-muted-foreground">
            {#each effectChips(adjustment.effect) as chip (chip)}
              <span class="rounded bg-muted px-1.5 py-0.5 tabular-nums">{chip}</span>
            {/each}
            <span>
              {adjustment.admin?.name ?? 'Someone'},
              <span title={formatDateTime(adjustment.created_at)}>{timeAgo(adjustment.created_at)}</span>
            </span>
          </div>
        </div>
        {#if canUndo && !undone}
          <Button
            variant="ghost"
            size="sm"
            class="shrink-0"
            title={adjustment.undo_error ?? 'Undo'}
            disabled={Boolean(adjustment.undo_error)}
            onclick={() => askUndo(adjustment)}
          >
            <Undo2 data-icon="inline-start" /> Undo
          </Button>
        {/if}
      </li>
    {/each}
  </ol>
{/if}

<AlertDialog.Root open={undoing !== null} onOpenChange={(open) => !open && (undoing = null)}>
  <AlertDialog.Content>
    {#if undoing}
      <AlertDialog.Header>
        <AlertDialog.Title>Undo “{describeAdjustment(undoing)}”?</AlertDialog.Title>
        <AlertDialog.Description>
          {#if undoing.incident}
            The days stop being excused for everyone, and everyone they touched is judged again in the
            background.
          {:else if undoing.kind === 'excuse'}
            The days stop counting, and the weeks holding them are judged again.
          {:else if undoing.kind === 'xp'}
            The XP comes off again. The line stays in their ledger, marked undone.
          {:else}
            Their freezes{undoing.kind === 'set' ? ' and multiplier' : ''} go back to what they were.
          {/if}
        </AlertDialog.Description>
      </AlertDialog.Header>
      {#if !undoing.incident}<StreakPreviewPanel {preview} {loading} />{/if}
      <AlertDialog.Footer>
        <AlertDialog.Cancel>Keep it</AlertDialog.Cancel>
        <AlertDialog.Action
          variant="destructive"
          onclick={undo}
          disabled={saving || (!undoing.incident && (loading || Boolean(preview?.errors.length)))}
          >Undo</AlertDialog.Action
        >
      </AlertDialog.Footer>
    {/if}
  </AlertDialog.Content>
</AlertDialog.Root>
