<script lang="ts">
  import { Link } from '@inertiajs/svelte'
  import { Badge } from '@/components/admin/ui/badge'
  import { adminTransfer } from '@/routes'
  import type { AdminProjectTransfer } from '@/types'

  let { transfer }: { transfer: AdminProjectTransfer } = $props()

  const host = $derived(
    URL.canParse(transfer.source_url) ? new URL(transfer.source_url).host : transfer.source_url,
  )
</script>

<Link href={adminTransfer(transfer.id)} prefetch cacheFor="30s" class="group block min-w-0">
  <span class="flex items-center gap-1.5 font-medium group-hover:underline">
    {transfer.project_name ?? 'Untitled'}
    {#if !transfer.source}<Badge variant="outline" class="text-[10px]">check by hand</Badge>{/if}
  </span>
  <span class="block truncate text-xs text-muted-foreground">{host}</span>
</Link>
