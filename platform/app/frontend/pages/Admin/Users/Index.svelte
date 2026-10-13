<script lang="ts" module>
  export { default as layout } from '@/layouts/AdminLayout.svelte'
</script>

<script lang="ts">
  import { Deferred } from '@inertiajs/svelte'
  import DataTable from '@/components/admin/DataTable.svelte'
  import DataTableSkeleton from '@/components/admin/DataTableSkeleton.svelte'
  import ListToolbar from '@/components/admin/ListToolbar.svelte'
  import { Badge } from '@/components/admin/ui/badge'
  import { Skeleton } from '@/components/admin/ui/skeleton'
  import { userColumns } from '@/lib/adminColumns'
  import { adminUsers } from '@/routes'
  import type { AdminUser, Pagy } from '@/types'

  let {
    users,
    pagy,
    total_count,
    query,
    include_deleted,
  }: { users?: AdminUser[]; pagy?: Pagy; total_count?: number; query: string; include_deleted: boolean } =
    $props()
</script>

<svelte:head><title>Users · Fallen Admin</title></svelte:head>

<div class="mb-4 flex items-center gap-2">
  <h1 class="text-2xl font-semibold tracking-tight">Users</h1>
  <Badge variant="secondary" class="text-sm">
    {#if total_count == null}<Skeleton class="h-4 w-8" />{:else}{total_count}{/if}
  </Badge>
</div>

<ListToolbar
  url={adminUsers.index().url}
  {query}
  includeDeleted={include_deleted}
  reload={['users']}
  placeholder="Search name, email, Slack ID"
  deletedLabel="Show deleted users"
/>

<Deferred data={['users', 'pagy']}>
  {#snippet fallback()}
    <DataTableSkeleton headers={['User', 'Slack ID', 'Roles', 'Last seen', 'Joined']} avatar />
  {/snippet}
  <DataTable columns={userColumns} data={users ?? []} {pagy} noun="users" />
</Deferred>
