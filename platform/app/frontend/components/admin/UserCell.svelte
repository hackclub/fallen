<script lang="ts">
  import { Link } from '@inertiajs/svelte'
  import { Badge } from '@/components/admin/ui/badge'
  import { trialLabel } from '@/lib/adminColumns'
  import { adminUser } from '@/routes'
  import type { AdminUser } from '@/types'

  let { user }: { user: AdminUser } = $props()
</script>

<Link href={adminUser(user.id)} prefetch cacheFor="30s" class="group flex items-center gap-2.5">
  <img src={user.avatar} alt="" class="size-7 shrink-0 rounded-full bg-muted object-cover" />
  <span class="min-w-0">
    <span class="flex items-center gap-1.5 font-medium group-hover:underline">
      {user.display_name}
      {#if user.is_trial}<Badge variant="secondary" class="text-[10px]">{trialLabel(user)}</Badge>{/if}
      {#if user.is_banned}<Badge variant="destructive" class="text-[10px]">Banned</Badge>{/if}
      {#if user.discarded_at}<Badge variant="destructive" class="text-[10px]">Deleted</Badge>{/if}
    </span>
    <span class="block truncate text-xs text-muted-foreground">{user.email}</span>
  </span>
</Link>
