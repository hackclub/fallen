<script lang="ts">
  import { router } from '@inertiajs/svelte'
  import LoaderCircle from '@lucide/svelte/icons/loader-circle'
  import MessageCircle from '@lucide/svelte/icons/message-circle'
  import X from '@lucide/svelte/icons/x'
  import { Button } from '@/components/admin/ui/button'
  import { formatDateTime } from '@/lib/format'
  import { adminTransfers } from '@/routes'
  import type { AdminProjectTransfer } from '@/types'

  // Marks that someone on staff already contacted the person about a transfer (ProjectTransfer#reach_out); it sends
  // nothing. The server records who from the session. The x on the mark takes it back off.
  let { transfer, size = 'sm' }: { transfer: AdminProjectTransfer; size?: 'sm' | 'default' } = $props()

  let sending = $state(false)
  const options = { preserveScroll: true, onFinish: () => (sending = false) }

  function reachOut() {
    sending = true
    router.post(adminTransfers.reachOut(transfer.id), {}, options)
  }

  function undo() {
    sending = true
    router.delete(adminTransfers.undoReachOut(transfer.id), options)
  }
</script>

{#if transfer.reached_out_by}
  <span
    class={[
      'inline-flex items-center gap-1.5 rounded-md bg-yellow-300 font-medium whitespace-nowrap text-yellow-950',
      size === 'sm' ? 'py-1 pr-1 pl-2 text-xs' : 'h-9 pr-1.5 pl-3 text-sm',
    ]}
    title={transfer.reached_out_at ? formatDateTime(transfer.reached_out_at) : undefined}
  >
    <MessageCircle class="size-3.5" /> Reached out by {transfer.reached_out_by.name}
    <button
      type="button"
      class="grid size-5 place-items-center rounded hover:bg-yellow-400 disabled:opacity-50"
      onclick={undo}
      disabled={sending}
      aria-label="Unmark reached out"
      title="Undo"
    >
      {#if sending}<LoaderCircle class="size-3.5 animate-spin" />{:else}<X class="size-3.5" />{/if}
    </button>
  </span>
{:else}
  <Button type="button" variant="outline" {size} onclick={reachOut} disabled={sending}>
    {#if sending}
      <LoaderCircle data-icon="inline-start" class="animate-spin" /> Marking…
    {:else}
      <MessageCircle data-icon="inline-start" /> Mark reached out
    {/if}
  </Button>
{/if}
