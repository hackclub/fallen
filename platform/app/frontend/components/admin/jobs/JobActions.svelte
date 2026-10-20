<script lang="ts">
  import { router } from '@inertiajs/svelte'
  import Play from '@lucide/svelte/icons/play'
  import RotateCcw from '@lucide/svelte/icons/rotate-ccw'
  import Trash2 from '@lucide/svelte/icons/trash-2'
  import * as AlertDialog from '@/components/admin/ui/alert-dialog'
  import { Button } from '@/components/admin/ui/button'
  import { JOB_RELOAD } from '@/lib/jobs'
  import { adminJobs, retryAdminJob, runAdminJob } from '@/routes'
  import type { AdminJob } from '@/types'

  // What can be done to a job, as icons in its row or as `labels` buttons on its page. Discarding asks first.
  let { job, labels = false }: { job: AdminJob; labels?: boolean } = $props()

  let busy = $state(false)
  let confirming = $state(false)

  const canRetry = $derived(job.status === 'failed')
  const canRun = $derived(job.status === 'scheduled')
  const canDiscard = $derived(['failed', 'queued', 'scheduled', 'blocked'].includes(job.status))

  // In a row, only the table and counts reload; on the job's page, the whole page does.
  const options = $derived({
    preserveScroll: true,
    preserveState: true,
    only: labels ? undefined : JOB_RELOAD,
    onStart: () => (busy = true),
    onFinish: () => (busy = false),
  })

  function discard() {
    router.delete(adminJobs.destroy(job.id, labels ? { query: { return_to: job.status } } : undefined), {
      ...options,
      onFinish: () => {
        busy = false
        confirming = false
      },
    })
  }
</script>

<div class="flex items-center justify-end gap-1">
  {#if canRetry}
    <Button
      variant={labels ? 'default' : 'ghost'}
      size={labels ? 'sm' : 'icon-sm'}
      title="Retry"
      disabled={busy}
      onclick={() => router.post(retryAdminJob(job.id), {}, options)}
    >
      <RotateCcw data-icon={labels ? 'inline-start' : undefined} />
      {#if labels}Retry{/if}
    </Button>
  {/if}
  {#if canRun}
    <Button
      variant={labels ? 'default' : 'ghost'}
      size={labels ? 'sm' : 'icon-sm'}
      title="Run now"
      disabled={busy}
      onclick={() => router.post(runAdminJob(job.id), {}, options)}
    >
      <Play data-icon={labels ? 'inline-start' : undefined} />
      {#if labels}Run now{/if}
    </Button>
  {/if}
  {#if canDiscard}
    <AlertDialog.Root bind:open={confirming}>
      <AlertDialog.Trigger>
        {#snippet child({ props })}
          <Button
            {...props}
            variant={labels ? 'outline' : 'ghost'}
            size={labels ? 'sm' : 'icon-sm'}
            title="Discard"
            class={labels ? '' : 'text-muted-foreground hover:text-destructive'}
            disabled={busy}
          >
            <Trash2 data-icon={labels ? 'inline-start' : undefined} />
            {#if labels}Discard{/if}
          </Button>
        {/snippet}
      </AlertDialog.Trigger>
      <AlertDialog.Content>
        <AlertDialog.Header>
          <AlertDialog.Title>Discard {job.class_name}?</AlertDialog.Title>
          <AlertDialog.Description>
            It's deleted from the queue and won't run. This can't be undone.
          </AlertDialog.Description>
        </AlertDialog.Header>
        <AlertDialog.Footer>
          <AlertDialog.Cancel>Cancel</AlertDialog.Cancel>
          <AlertDialog.Action variant="destructive" onclick={discard} disabled={busy}
            >Discard</AlertDialog.Action
          >
        </AlertDialog.Footer>
      </AlertDialog.Content>
    </AlertDialog.Root>
  {/if}
</div>
