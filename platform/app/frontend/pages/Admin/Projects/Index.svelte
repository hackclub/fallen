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
  import { projectColumns } from '@/lib/adminColumns'
  import { adminProjects } from '@/routes'
  import type { AdminProject, Pagy } from '@/types'

  let {
    projects,
    pagy,
    total_count,
    query,
    include_deleted,
  }: {
    projects?: AdminProject[]
    pagy?: Pagy
    total_count?: number
    query: string
    include_deleted: boolean
  } = $props()

  const columns = projectColumns()
</script>

<svelte:head><title>Projects · Fallen Admin</title></svelte:head>

<div class="mb-4 flex items-center gap-2">
  <h1 class="text-2xl font-semibold tracking-tight">Projects</h1>
  <Badge variant="secondary" class="text-sm">
    {#if total_count == null}<Skeleton class="h-4 w-8" />{:else}{total_count}{/if}
  </Badge>
</div>

<ListToolbar
  url={adminProjects.index().url}
  {query}
  includeDeleted={include_deleted}
  reload={['projects']}
  placeholder="Search title, owner name or email"
  deletedLabel="Show deleted projects"
/>

<Deferred data={['projects', 'pagy']}>
  {#snippet fallback()}
    <DataTableSkeleton headers={['Project', 'Owner', 'Journals', 'Hours', 'Slack', 'Updated']} />
  {/snippet}
  <DataTable {columns} data={projects ?? []} {pagy} noun="projects" />
</Deferred>
